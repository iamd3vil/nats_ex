defmodule NatsEx.SidCounter do
  @moduledoc false
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def inc() do
    GenServer.call(__MODULE__, :inc)
  end

  def init(:ok) do
    {:ok, 0}
  end

  def handle_call(:inc, _from, count) do
    {:reply, count + 1, count + 1}
  end
end
