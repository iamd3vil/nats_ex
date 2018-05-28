defmodule NatsEx.ProtocolTest do
  use ExUnit.Case, async: true
  alias NatsEx.Protocol
  require Logger

  test "making a pub message" do
    subject = "hello"
    payload = "hello"
    reply_to = "reply_to"
    bytes = :erlang.byte_size(payload)

    assert Protocol.make_pub_message(subject, reply_to, payload) ==
             "PUB #{subject} #{reply_to} #{bytes}\r\n#{payload}\r\n"
  end

  test "making a sub message" do
    subject = "hello"
    sid = 2
    queue_group = 1

    assert Protocol.make_sub_message(subject, queue_group, sid) ==
             "SUB #{subject} #{queue_group} #{sid}\r\n"
  end

  test "making a unsub message" do
    sid = 1
    num_of_msgs = 10
    assert Protocol.make_unsub_message(sid, num_of_msgs) == "UNSUB #{sid} #{num_of_msgs}\r\n"
  end

  test "parsing info message" do
    info_mesg = ~s(INFO {"server": "gnatsd", version: "0.8.0", auth_required: true})
    parsed_info_message = Protocol.parse_info_mesg(info_mesg)
    assert parsed_info_message == ~s({"server": "gnatsd", version: "0.8.0", auth_required: true})
  end

  test "parsing payload" do
    test_payload = ~s(hello\r\n)
    parsed_payload = Protocol.parse_payload(test_payload)
    assert parsed_payload == "hello"
  end

  test "parsing message without a reply to subject" do
    test_message = ~s(foo 23 10\r\n)
    parsed_message = Protocol.parse_message(test_message)
    assert parsed_message == {"foo", nil, "23", "10"}
  end

  test "parsing a message witha reply to subject" do
    test_message = ~s(foo bar 23 10\r\n)
    parsed_message = Protocol.parse_message(test_message)
    assert parsed_message == {"foo", "bar", "23", "10"}
  end
end
