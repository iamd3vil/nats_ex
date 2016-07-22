defmodule NatsEx.ProtocolTest do
  use ExUnit.Case, async: true
  alias NatsEx.Protocol
  require Logger

  test "making a pub message" do
    subject = "hello"
    payload = "hello"
    reply_to = "reply_to"
    bytes = :erlang.byte_size(payload)
    assert Protocol.make_pub_message(subject, reply_to, payload)
                    == "PUB #{subject} #{reply_to} #{bytes}\r\n#{payload}\r\n"
  end

  test "making a sub message" do
    subject = "hello"
    sid = 2
    queue_group = 1
    assert Protocol.make_sub_message(subject, queue_group, sid)
                     == "SUB #{subject} #{queue_group} #{sid}\r\n"
  end

  test "making a unsub message" do
    sid = 1
    num_of_msgs = 10
    assert Protocol.make_unsub_message(sid, num_of_msgs)
                     == "UNSUB #{sid} #{num_of_msgs}\r\n"
  end
end
