defmodule CureOMatic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CureOMatic.Supervisor]
    pin = Application.get_env(:cure_o_matic, :pin)
    sensor = Application.get_env(:cure_o_matic, :sensor)
    # Define workers and child supervisors to be supervised
    children = [
      worker(CureOMatic, [{pin, sensor}, [name: CureOMatic]])
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
    [
      # Children for all targets except host
      # Starts a worker by calling: CureOMatic.Worker.start_link(arg)
      # {CureOMatic.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:cure_o_matic, :target)
  end
end
