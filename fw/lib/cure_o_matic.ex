defmodule CureOMatic do
  use NervesDht

  def listen(resp) do
    IO.inspect(resp)
    case resp do
      {:ok, p, s, h, t} ->
        {:ok, {p, s, h, t}}

      {:error, error} ->
        {:error, error}
    end
  end
end
