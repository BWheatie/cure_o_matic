defmodule CureOMatic.Sensor do
  use NervesDht

  require Logger

  @impl true
  def init(args) do
    {:ok, args}
  end

  def listen(resp) do
    case resp do
      {:ok, p, s, h, t} ->
        {:ok, {p, s, h, t}}
        Logger.info("#{inspect({:ok, {p, s, h, t}})}")

      {:error, error} ->
        {:error, error}
    end
  end
end
