defmodule NatsEx do
  @moduledoc """
  NatsEx application
  """
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Initialize syn
    # :syn.init()

    # Initialize sid counter ets table
    NatsEx.SidCounter.init(0)

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: NatsEx.Worker.start_link(arg1, arg2, arg3)
      # worker(NatsEx.Worker, [arg1, arg2, arg3]),
      supervisor(NatsEx.ConnectionSup, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NatsEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
