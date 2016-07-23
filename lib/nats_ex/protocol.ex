defmodule NatsEx.Protocol do
  @moduledoc """
  Functions to build messages according to Nats protocol
  """

  @doc """
  Makes a publish message
  """
  def make_pub_message(subject, nil, payload) do
    num_of_bytes = :erlang.byte_size(payload)
    "PUB #{subject} #{num_of_bytes}\r\n#{payload}\r\n"
  end

  def make_pub_message(subject, reply_to, payload) do
    num_of_bytes = :erlang.byte_size(payload)
    "PUB #{subject} #{reply_to} #{num_of_bytes}\r\n#{payload}\r\n"
  end

  @doc """
  Makes a subscription message
  """
  def make_sub_message(subject, nil, sid) do
    "SUB #{subject} #{sid}\s\n"
  end

  def make_sub_message(subject, queue_group, sid) do
    "SUB #{subject} #{queue_group} #{sid}\r\n"
  end

  @doc """
  Makes an unsub message
  """
  def make_unsub_message(sid, nil) do
    "UNSUB #{sid}\r\n"
  end

  def make_unsub_message(sid, num_of_msgs) do
    "UNSUB #{sid} #{num_of_msgs}\r\n"
  end
end
