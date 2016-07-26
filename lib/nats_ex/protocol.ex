defmodule NatsEx.Protocol do
  @moduledoc """
  Functions to build messages according to Nats protocol
  """

  @doc """
  Parses the info string from info message
  """
  @spec parse_info_mesg(String.t) :: String.t
  def parse_info_mesg(<<"INFO ", rest::bitstring>>) do
    rest
  end

  @doc """
  Parses payload from payload message
  """
  @spec parse_payload(String.t) :: String.t
  def parse_payload(payload) do
    payload
    |> String.trim_trailing
  end

  @doc """
  Extracts message parameters like subject, reply_to
  subject, sid, number of bytes of payload
  """
  @spec parse_message(String.t) :: {String.t, String.t | nil,
                                    String.t, String.t}
  def parse_message(msg) do
    msg
    |> String.trim_trailing
    |> String.split
    |> _parse_message
  end

  defp _parse_message([subject, sid, bytes]) do
    {subject, nil, sid, bytes} # Add nil if rep_to subject is absent
  end

  defp _parse_message([subject, rep_to, sid, bytes]) do
    {subject, rep_to, sid, bytes}
  end


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
