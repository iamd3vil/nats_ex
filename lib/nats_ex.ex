defmodule NatsEx do
  @moduledoc """
  NatsEx application
  """
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @impl Application
  def start(_type, _args) do
    # Initialize syn
    # :syn.init()

    # Initialize sid counter ets table
    NatsEx.SidCounter.init(0)

    # Stores a counter with how many messages still there for the `sid` to unsubscribe.
    :unsub_ets = :ets.new(:unsub_ets, [:public, :named_table, :set])

    children = [
      NatsEx.ProcessGroup,
      NatsEx.ConnectionSup,
      {Registry, keys: :duplicate, name: :sids}
    ]

    opts = [strategy: :one_for_one, name: NatsEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
