defmodule StarweaveLlmTest do
  use ExUnit.Case
  doctest StarweaveLlm

  test "greets the world" do
    assert StarweaveLlm.hello() == :world
  end
end
