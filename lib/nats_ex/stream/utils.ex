defmodule NatsEx.Stream.Utils do
  @moduledoc false

  @spec generate_random_id :: String.t()
  def generate_random_id() do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.trim_trailing("=")
  end
end
