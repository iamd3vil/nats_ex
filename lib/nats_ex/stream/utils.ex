defmodule NatsEx.Stream.Utils do
  @moduledoc false

  def generate_random_id() do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.trim_trailing("=")
  end
end
