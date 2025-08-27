defmodule StarweaveCoreTest do
  use ExUnit.Case
  doctest StarweaveCore

  test "greets the world" do
    assert StarweaveCore.hello() == :world
  end
end
