defmodule NatsEx.ConnectionTest do
  use ExUnit.Case
  doctest NatsEx
  require Logger

  setup do
    {:ok, conn} = NatsEx.Connection.connection
    {:ok, [conn: conn]}
  end

  test "pubsub", %{conn: conn} do
    sub_and_pub(conn, "foo", "test")
  end

  test "unsubscription", %{conn: conn} do
    sub_and_pub(conn, "foo", "test")
    NatsEx.Connection.unsub(conn, "foo")
    assert :ok = NatsEx.Connection.pub(conn, "foo", "test")
    refute_receive({:nats_ex, :msg, "foo", nil, "test"}, 100)
  end

  test "unsubscription after certain number of messages", %{conn: conn} do
    sub_and_pub(conn, "foo", "test")
    NatsEx.Connection.unsub(conn, "foo", 5)
    assert_pub(conn, "foo", "test")
    assert_pub(conn, "foo", "test")
    assert_pub(conn, "foo", "test")
    assert_pub(conn, "foo", "test")
    assert :ok = NatsEx.Connection.pub(conn, "foo", "test")
    refute_receive({:nats_ex, :msg, "foo", nil, "test"}, 100)
  end

  # Subscribes and then publishes and then asserts that message
  # has been received
  defp sub_and_pub(conn, subject, message) do
    assert :ok = NatsEx.Connection.sub(conn, subject) # Subscribe
    assert :ok = NatsEx.Connection.pub(conn, subject, message) # Publish
    assert_receive({:nats_ex, :msg, ^subject, nil, ^message})
  end

  # Asserts that a message is received when published
  defp assert_pub(conn, subject, message) do
    assert :ok = NatsEx.Connection.pub(conn, subject, message)
    assert_receive({:nats_ex, :msg, ^subject, nil, ^message}, 1000)
  end
end
