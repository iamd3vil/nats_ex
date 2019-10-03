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

  @spec subscribe(pid, String.t(), Keyword.t()) :: :ok | {:error, :timeout}
  def subscribe(conn, subject, opts) do
    sub_req =
      Messages.SubscriptionRequest.new(%{
        subject: subject,
        inbox: Utils.generate_random_id(),
        maxInFlight: Keyword.get(opts, :max_in_flight, 100),
        ackWaitInSecs: Keyword.get(opts, :ack_wait_in_secs, 5),
        startPosition: Messages.StartPosition.value(:First),
        durableName: Keyword.get(opts, :durable_name, ""),
        startSequence: Keyword.get(opts, :start_sequence, 0),
        startTimeDelta: Keyword.get(opts, :start_time_delta, 0)
      })

    GenServer.call(conn, {:sub, sub_req})
  end

  def publish(conn, subject, payload) do
    pub_msg =
      Messages.PubMsg.new(%{
        guid: Utils.generate_random_id(),
        subject: subject,
        data: payload
      })

    GenServer.call(conn, {:pub, pub_msg})
  end

  ##################
  # Server Callbacks
  ##################

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  @doc false
  def init(:ok) do
    {:ok, conn} = UConn.connection()

    # Subscribe to heart beats
    heartbeat_sub = Utils.generate_random_id()
    UConn.sub(conn, heartbeat_sub)

    # Subscribe for response
    resp_sub = Utils.generate_random_id()
    UConn.sub(conn, resp_sub)

    # Subscribe for pub ack responses
    pub_ack_sub = Utils.generate_random_id()
    UConn.sub(conn, pub_ack_sub)

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

    # Wait for connect response
    receive do
      {:nats_ex, :msg, ^resp_sub, _, payload} ->
        resp = Messages.ConnectResponse.decode(payload)

        {:ok,
         %{
           conn: conn,
           client_id: client_id,
           heartbeat_sub: heartbeat_sub,
           pub_prefix: resp.pubPrefix,
           sub_requests: resp.subRequests,
           unsub_requests: resp.unsubRequests,
           close_requests: resp.closeRequests,
           sub_close_requests: resp.subCloseRequests,
           pub_ack_sub: pub_ack_sub,
           subs: %{},
           pubs: %{},
           ack_inboxes: %{}
         }}
    end
  end

  def handle_info(
        {:nats_ex, :msg, heartbeat_sub, rep_to, ""},
        %{heartbeat_sub: heartbeat_sub} = state
      ) do
    :ok = UConn.pub(state.conn, rep_to, "", "")
    {:noreply, state}
  end

  # Handle sub response
  def handle_info(
        {:nats_ex, :msg, "sub_resp." <> _ = resp_sub, _rep_to, payload},
        state
      ) do
    # Decode sub response
    resp = Messages.SubscriptionResponse.decode(payload)

    # Reply to appropriate genserver call and also get the inbox
    # Lookup using resp_sub.
    {{caller, inbox}, new_state} = get_and_update_in(state, [:subs, resp_sub], fn _ -> :pop end)

    # Save ackInbox against inbox
    new_state = put_in(new_state, [:ack_inboxes, inbox], resp.ackInbox)

    GenServer.reply(caller, :ok)
    {:noreply, new_state}
  end

  # Handle pub acks
  def handle_info(
        {:nats_ex, :msg, pub_ack_sub, _rep_to, payload},
        %{pub_ack_sub: pub_ack_sub} = state
      ) do
    resp = Messages.PubAck.decode(payload)

    # Lookup caller from pubs in state
    {caller, new_state} = get_and_update_in(state, [:pubs, resp.guid], fn _ -> :pop end)

    GenServer.reply(caller, :ok)
    {:noreply, new_state}
  end

  def handle_call({:pub, pub_msg}, from, state) do
    # Set Client ID
    pub_msg =
      Messages.PubMsg.new(%{
        Map.from_struct(pub_msg)
        | clientID: state.client_id
      })

    # Store guid to caller in pubs
    new_state = put_in(state, [:pubs, pub_msg.guid], from)

    # Publish to NATS
    UConn.pub(
      state.conn,
      "#{state.pub_prefix}.#{pub_msg.subject}",
      Messages.PubMsg.encode(pub_msg),
      state.pub_ack_sub
    )

    {:noreply, new_state}
  end

  def handle_call(
        {:sub, sub_request},
        from,
        %{sub_requests: sub_requests} = state
      ) do
    # Set Client ID
    sub_request =
      Messages.SubscriptionRequest.new(%{
        Map.from_struct(sub_request)
        | clientID: state.client_id
      })

    resp_sub = "sub_resp.#{Utils.generate_random_id()}"
    UConn.sub(state.conn, resp_sub)

    :ok =
      UConn.pub(
        state.conn,
        sub_requests,
        Messages.SubscriptionRequest.encode(sub_request),
        resp_sub
      )

    # Store caller ref against resp subject for sub response
    # We can lookup this ref when we get the sub response from NATS
    new_state = put_in(state, [:subs, resp_sub], {from, sub_request.inbox})

    {:noreply, new_state}
  end
end
