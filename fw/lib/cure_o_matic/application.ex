defmodule CureOMatic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CureOMatic.Supervisor]

    children = [
    ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: CureOMatic.Worker.start_link(arg)
      # {CureOMatic.Worker, arg},
    ]
  end

  def children(_target) do
    pin = Application.get_env(:cure_o_matic, :pin)
    sensor = Application.get_env(:cure_o_matic, :sensor)
    [
      {CureOMatic.Sensor, {pin, sensor}}
      # Children for all targets except host
      # Starts a worker by calling: CureOMatic.Worker.start_link(arg)
      # {CureOMatic.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:cure_o_matic, :target)
  end
end
