defmodule NatsEx.Stream.Connection do
  @moduledoc """
  A genserver implementing Nats connection for streaming
  """
  alias NatsEx.Connection, as: UConn
  alias NatsEx.Stream.{Utils, Messages}
  use GenServer
  require Logger

  #### Server callbacks
  @doc """
  Starts a streaming connection to NATS
  """
  def connection() do
    Supervisor.start_child(NatsEx.Stream.ConnectionSup, [])
  end

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  @doc false
  def init(:ok) do
    {:ok, conn} = UConn.connection()

    IO.inspect("Got connection.")

    # Subscribe to heart beats
    heartbeat_sub = Utils.generate_random_id()
    UConn.sub(conn, heartbeat_sub)

    # Subscribe for response
    resp_sub = Utils.generate_random_id()
    UConn.sub(conn, resp_sub)

    client_id = Utils.generate_random_id()

    # Send connection request
    cr =
      Messages.ConnectRequest.new(%{
        clientID: client_id,
        heartbeatInbox: heartbeat_sub,
        connID: Utils.generate_random_id()
      })

    # Publish connect response
    UConn.pub(
      conn,
      "_STAN.discover.mycluster",
      Messages.ConnectRequest.encode(cr),
      resp_sub
    )

    IO.inspect("Sent cr message: #{inspect(cr)}")

    # Wait for connect response
    receive do
      {:nats_ex, :msg, ^resp_sub, _, payload} ->
        resp = Messages.ConnectResponse.decode(payload)

        {:ok,
         %{
           conn: conn,
           client_id: client_id,
           heartbeat_sub: heartbeat_sub,
           resp_sub: resp_sub,
           pub_prefix: resp.pubPrefix,
           sub_requests: resp.subRequests,
           unsub_requests: resp.unsubRequests,
           close_requests: resp.closeRequests,
           sub_close_requests: resp.subCloseRequests,
           subs: %{}
         }}
    end
  end

  def handle_info(
        {:nats_ex, :msg, heartbeat_sub, rep_to, ""},
        %{heartbeat_sub: heartbeat_sub} = state
      ) do
    Logger.debug("Responding to heartbeat")
    :ok = UConn.pub(state.conn, rep_to, "", "")
    {:noreply, state}
  end

  def handle_call({:sub, sub_request}, from, %{sub_requests: sub_requests} = state) do
    # Set Client ID
    sub_request =
      Messages.SubscriptionRequest.new(%{
        Map.from_struct(sub_request)
        | client_id: state.client_id
      })

    :ok =
      UConn.pub(
        state.conn,
        sub_requests,
        Messages.SubscriptionRequest.encode(sub_request),
        state.resp_sub
      )

    new_state = put_in(state, [:subs, sub_request.subject], from)

    {:noreply, new_state}
  end
end
