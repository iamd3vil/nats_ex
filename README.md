# NatsEx

(*WORK IN PROGRESS*)

An idiomatic Elixir client for Nats.io messaging system

Currently PubSub functionality is implemented.

## Getting started

You can start a connection with Natsd like this.

```elixir
{:ok, conn} = NatsEx.Connection.connection
```

#### Subscription

For subscription to a certain topic, you can use `sub/2` or `sub/3` in `NatsEx.Connection` module. You can also give a queue group for the subscription.

```elixir
:ok = NatsEx.Connection.sub(conn, "foo.bar") # No queue group
:ok = NatsEx.Connection.sub(conn, "foo.bar", 22) # Queue group 22
```

When a new message comes to a certain topic, a new message is received by all the subscribers. The message format is `{:nats_ex, :msg, subject, reply_to_subject, payload}`

When the connection is down(closed by the server), all the subscribers receive a message `{:nats_ex, :conn_down}`

#### Publishing

For publishing to a certain topic, you can use `pub/3` or `pub/4` in `NatsEx.Connection` module. `reply_to` topic is optional.

```elixir
:ok = NatsEx.Connection.pub(conn, "foo.bar", "This is a payload", "REPLY_SUBJECT")
```

#### Unsubscription

You can unsubscribe to a certain topic by using `unsub/2` or `unsub/3` in `NatsEx.Connection` module. You can also specify the number of messages, after which the subscriber will be automatically subscribed.

```elixir
:ok = NatsEx.Connection.unsub(conn, "foo.bar", 10) # 10 is number of messages until unsubscription. This is optional
```

## Installation

It's not available on Hex yet, but if you want to try it out:

  1. Add `nats_ex` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:nats_ex, github: "iamd3vil/nats_ex"}]
    end
    ```

  2. Ensure `nats_ex` is started before your application:

    ```elixir
    def application do
      [applications: [:nats_ex]]
    end
    ```

