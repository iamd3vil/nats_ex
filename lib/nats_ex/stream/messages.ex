defmodule NatsEx.Stream.Messages do
  use Protobuf, from: Path.expand("../../../priv/protos/streaming.proto", __DIR__)
end
