defmodule NatsEx.StreamingConnTest do
  use ExUnit.Case
  require Logger
  alias NatsEx.Stream.Connection

  setup do
    {:ok, conn} = Connection.connection()
    {:ok, [conn: conn]}
  end

  test "subscription", %{conn: conn} do
    assert :ok = Connection.subscribe(conn, "test-sub")
  end
end
