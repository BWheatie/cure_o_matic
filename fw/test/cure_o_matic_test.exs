defmodule CureOMaticTest do
  use ExUnit.Case
  doctest CureOMatic

  test "greets the world" do
    assert CureOMatic.hello() == :world
  end
end
