defmodule Nerves.WpaSupplicant.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:duplicate, Nerves.WpaSupplicant])
    ]

    opts = [strategy: :one_for_one, name: Nerves.WpaSupplicant.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
