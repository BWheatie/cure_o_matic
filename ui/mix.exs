defmodule CureOMaticScenic.MixProject do
  use Mix.Project

  def project do
    [
      app: :cure_o_matic_scenic,
      version: "0.1.0",
      elixir: "~> 1.7",
      build_embedded: true,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {CureOMaticScenic, []},
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:scenic, "~> 0.10"},
      {:scenic_driver_glfw, "~> 0.10", targets: :host},
      {:scenic_layout_o_matic, "0.5.0"},
      {:scenic_driver_nerves_rpi, "0.10.1", targets: :rpi3}
    ]
  end
end
