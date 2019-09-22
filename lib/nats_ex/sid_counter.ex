defmodule NatsEx.SidCounter do
  @moduledoc false

  @counter_name :sid_counter

  def init(count) do
    :ets.new(@counter_name, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.insert(@counter_name, {:counter, count})
  end

  def inc() do
    case :ets.lookup(@counter_name, :counter) do
      [{:counter, counter}] ->
        :ets.insert(@counter_name, {:counter, to_string(String.to_integer(counter) + 1)})
        counter
    end
  end
end
