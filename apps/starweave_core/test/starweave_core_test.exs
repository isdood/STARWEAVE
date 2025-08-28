defmodule StarweaveCoreTest do
  use ExUnit.Case, async: true

  alias StarweaveCore
  alias StarweaveCore.{PatternStore, Pattern}

  setup do
    PatternStore.clear()
    :ok
  end

  test "add/get pattern" do
    assert :ok == StarweaveCore.add_pattern("p1", "hello world", metadata: %{a: 1}, energy: 0.5)
    %Pattern{id: "p1", data: "hello world", metadata: %{a: 1}} = StarweaveCore.get_pattern("p1")
  end

  test "match contains" do
    StarweaveCore.add_pattern("p1", "hello world")
    StarweaveCore.add_pattern("p2", "foo bar")
    results = StarweaveCore.match("world", strategy: :contains)
    assert Enum.map(results, & &1.id) == ["p1"]
  end

  test "match exact and jaccard" do
    StarweaveCore.add_pattern("p1", "The quick brown fox")
    StarweaveCore.add_pattern("p2", "The quick fox")

    exact = StarweaveCore.match("The quick brown fox", strategy: :exact)
    assert Enum.map(exact, & &1.id) == ["p1"]

    jacc = StarweaveCore.match("quick fox", strategy: :jaccard)
    assert Enum.any?(jacc, &(&1.id in ["p1", "p2"]))
  end
end
