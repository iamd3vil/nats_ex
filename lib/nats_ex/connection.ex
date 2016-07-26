defmodule NatsEx.Connection do
  @moduledoc """
  A GenServer implementing a connection to Natsd server.

  For example,
      iex> {:ok, conn} = NatsEx.Connection.connection
         {:ok, #PID<0.153.0>}
      iex> NatsEx.Connection.sub("foo")
         :ok
      iex> NatsEx.Connection.pub("foo", "hey")
         :ok
      iex> flush()
         {:nats_ex, :msg, "foo", nil, "hey"} # See `sub/2` for more details about message format
  """
  require Logger
  import NatsEx.Protocol
  use GenServer
  alias NatsEx.SidCounter

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  @doc """
  Opens a connection
  """
  @spec connection() :: {:ok, pid}
  def connection() do
    Supervisor.start_child(NatsEx.ConnectionSup, [])
  end

  @doc """
  For publishing.

  `reply_to` is optional. Returns `:ok`
  """
  @spec pub(pid, String.t, String.t, String.t | nil) :: :ok
  def pub(conn, subject, payload, reply_to \\ nil) do
    GenServer.call(conn, {:pub, subject, reply_to, payload})
  end

  @doc """
  For subscribing to any subject

  `queue_group` is optional
  """
  @spec sub(pid, String.t, integer) :: :ok
  def sub(conn, subject, queue_group \\ nil) do
    sid = SidCounter.inc()
    :ok = GenServer.call(conn, {:sub, self(), subject, sid, queue_group})
    :gproc.reg({:p, :l, {self(), conn, subject}}, sid)
    :ok
  end

  defp reg_unpub_gproc(sid, num_of_msgs) do
    :gproc.reg_shared({:p, :l, {:unsub, sid}}, num_of_msgs)
  end

  @doc """
  For unsubscribing from a certain subject.

  `num_of_msgs` is the max number of messages received, after which it automatically unsubscribes.
  It is optional
  """
  @spec unsub(pid, String.t, integer | nil) :: :ok
  def unsub(conn, subject, num_of_msgs \\ nil) do
    [{_, sid}] = :gproc.lookup_values({:p, :l, {self(), conn, subject}})
    if num_of_msgs == nil do
      :pg2.leave(sid, self())
      reg_unpub_gproc(sid, 0)
    else
      reg_unpub_gproc(sid, num_of_msgs) # Storing number of messages, after which it has to unsubscribe
    end
    GenServer.cast(conn, {:unsub, self(), sid, num_of_msgs})
  end

  # Server callbacks

  @doc false
  @spec init(:ok) :: {:ok, map}
  def init(:ok) do
    {host, port} = get_host_port()
    {:ok, {:hostent, _, _, _, _, [ip_addr]}} = :inet.gethostbyname(host |> String.to_charlist)
    {:ok, socket} = :gen_tcp.connect(ip_addr, port, [active: :false, mode: :binary, packet: :line])
    {:ok, info_mesg} = :gen_tcp.recv(socket, 0)

    # Decode info
    info = info_mesg
    |> parse_info_mesg
    |> String.trim_trailing
    |> Poison.decode!

    # Build connect message
    connect_mesg = info
    |> require_auth?
    |> build_connect_message

    :gen_tcp.send(socket, connect_mesg)
    :inet.setopts(socket, active: :once)
    {:ok, %{socket: socket, info: info}}
  end

  @spec require_auth?(map) :: boolean
  def require_auth?(info) do
    info
    |> Map.get("auth_required")
  end

  @spec get_host_port() :: {String.t, integer}
  defp get_host_port do
    host = Application.get_env(:nats_ex, :host) || "localhost"
    port = Application.get_env(:nats_ex, :port) || 4222
    {host, port}
  end

  @spec get_auth_credentials() :: {String.t | nil, String.t | nil}
  defp get_auth_credentials() do
    username = Application.get_env(:nats_ex, :username)
    password = Application.get_env(:nats_ex, :password)
    {username, password}
  end

  @spec build_connect_message(boolean) :: String.t
  defp build_connect_message(true) do
    get_auth_credentials
    |> case do
         {username, password} when username != nil and password != nil ->
           msg = %{
             verbose: false,
             pedantic: false,
             ssl_required: false,
             lang: "elixir",
             version: "0.1.0",
             user: username,
             pass: password
            }
            |> Poison.encode!
           "CONNECT #{msg}\r\n"
         _ ->
           raise("Authentication is required. You have to set username and password")
    end
  end

  defp build_connect_message(false) do
    ~s(CONNECT {"verbose": false, "pedantic": false, "ssl_required": false, "lang": "elixir"}\r\n)
  end

  @doc false
  # Handler for publish call
  def handle_call({:pub, subject, reply_to, payload}, _from, %{socket: socket} = state) do
    pub_message = make_pub_message(subject, reply_to, payload) # Makes a publish string
    :gen_tcp.send(socket, pub_message)
    {:reply, :ok, state}
  end

  @doc false
  def handle_call({:sub, from, subject, sid, queue_group}, _from, %{socket: socket} = state) do
    sub_message = make_sub_message(subject, sid, queue_group)
    :pg2.create(sid) # Creating since pg2 doesn't automatically create the process group
    :pg2.create({:conn, self()})
    :pg2.join(sid, from) # Join a process group named with `sid`
    :pg2.join({:conn, self()}, from) # For maintaining subscribed processes for this connections
    :gen_tcp.send(socket, sub_message)
    {:reply, :ok, state}
  end

  @doc false
  def handle_cast({:unsub, _from, sid, num_of_msgs}, %{socket: socket} = state) do
   unsub_mesg = make_unsub_message(sid, num_of_msgs)
   :gen_tcp.send(socket, unsub_mesg)
   {:noreply, state}
  end

  @doc false
  # Handle tcp messages
  def handle_info({:tcp, _, "MSG " <> msg}, %{socket: socket} = state) do
    {subject, rep_to, sid, bytes} = parse_message(msg)
    :inet.setopts(socket, packet: :raw)
    {:ok, payload} = :gen_tcp.recv(socket, String.to_integer(bytes) + 2) # Adding 2 for "/r/n"
    payload = parse_payload(payload)

    {:p, :l, {:unsub, String.to_integer(sid)}}
    |> :gproc.lookup_values
    |> send_subscriber_message(sid, subject, rep_to, payload)
    :inet.setopts(socket, packet: :line)
    :inet.setopts(socket, active: :once)
    {:noreply, state}
  end

  @doc false
  def handle_info({:tcp, _, "-ERR " <> error}, %{socket: socket} = state) do
    Logger.warn "Received Error from Nats Server: #{error}"
    :inet.setopts(socket, active: :once)
    {:noreply, state}
  end

  @doc false
  def handle_info({:tcp, socket, "PING\r\n"}, state) do
    :gen_tcp.send(socket, "PONG\r\n")
    :inet.setopts(socket, active: :once)
    {:noreply, state}
  end

  @doc false
  def handle_info({:tcp_closed, _}, state) do
    Logger.warn "Nats Connection closed by the server"
    :pg2.create({:conn, self()})
    {:conn, self()}
    |> :pg2.get_local_members
    |> Enum.each(fn member ->
      send(member, {:nats_ex, :conn_down})
    end)
    {:stop, :normal, state}
  end

  @doc """
  Sends messages to subscribers.

  Checks if the process is supposed to unsubscribe after the message received.
  """
  def send_subcriber_message([{_, 1}], _sid, _subject, _rep_to, _payload) do
    :ok
  end

  def send_subscriber_message([{_, num_of_msgs}], sid, subject, rep_to, payload) do
    # Decreasing the number of messages until the process has to unsub
    :gproc.set_value_shared({:p, :l, {:unsub, String.to_integer(sid)}}, num_of_msgs - 1)
    sid
    |> String.to_integer
    |> :pg2.get_local_members
    |> Enum.each(fn member ->
        send(member, {:nats_ex, :msg, subject, rep_to, payload})
    end)
  end

  # When this function is called, it means that the subscriber didn't
  # send a unsub request.
  def send_subscriber_message([], sid, subject, rep_to, payload) do
    sid
    |> String.to_integer
    |> :pg2.get_local_members
    |> Enum.each(fn member ->
        send(member, {:nats_ex, :msg, subject, rep_to, payload})
    end)
  end
end
