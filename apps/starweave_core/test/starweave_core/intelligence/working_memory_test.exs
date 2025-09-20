defmodule StarweaveCore.Intelligence.WorkingMemoryTest do
  use ExUnit.Case, async: false
  alias StarweaveCore.Intelligence.WorkingMemory

  setup do
    # Clear any existing state before each test
    if Process.whereis(WorkingMemory) do
      :ok = WorkingMemory.clear_context(:test_context)
      :ok = WorkingMemory.clear_context(:test_ctx)
      :ok = WorkingMemory.clear_context(:other_ctx)
      :ok = WorkingMemory.clear_context(:search_ctx)
      :ok = WorkingMemory.clear_context(:persistence_test)
    else
      # Start the WorkingMemory GenServer if not already started
      {:ok, _pid} = WorkingMemory.start_link()
    end
    
    :ok
  end

  describe "basic memory operations" do
    test "stores and retrieves a value" do
      :ok = WorkingMemory.store(:test_context, :test_key, "test_value")
      assert {:ok, "test_value"} = WorkingMemory.retrieve(:test_context, :test_key)
    end

    test "returns :not_found for non-existent key" do
      assert :not_found = WorkingMemory.retrieve(:non_existent_context, :non_existent_key)
    end

    test "forgets a stored value" do
      :ok = WorkingMemory.store(:test_context, :to_forget, "forget_me")
      :ok = WorkingMemory.forget(:test_context, :to_forget)
      assert :not_found = WorkingMemory.retrieve(:test_context, :to_forget)
    end
  end

  describe "context operations" do
    test "retrieves all memories for a context" do
      :ok = WorkingMemory.store(:test_ctx, :key1, "value1", importance: 0.8)
      :ok = WorkingMemory.store(:test_ctx, :key2, "value2", importance: 0.5)
      :ok = WorkingMemory.store(:other_ctx, :key3, "value3")

      memories = WorkingMemory.get_context(:test_ctx)
      assert length(memories) == 2
      assert {_, _, %{importance: 0.8}} = Enum.find(memories, &match?({:key1, "value1", _}, &1))
    end

    test "clears all memories in a context" do
      :ok = WorkingMemory.store(:test_ctx, :key1, "value1")
      :ok = WorkingMemory.store(:test_ctx, :key2, "value2")
      :ok = WorkingMemory.clear_context(:test_ctx)

      assert [] = WorkingMemory.get_context(:test_ctx)
      assert :not_found = WorkingMemory.retrieve(:test_ctx, :key1)
    end
  end

  describe "search functionality" do
    test "finds memories by search query" do
      # Store test data with importance scores
      :ok = WorkingMemory.store(:search_ctx, :user_pref, "user prefers dark theme", importance: 0.8)
      :ok = WorkingMemory.store(:search_ctx, :last_action, "user clicked settings", importance: 0.5)
      :ok = WorkingMemory.store(:other_ctx, :unrelated, "some other data", importance: 0.3)

      # Search for memories containing "dark" (exact substring match)
      results = WorkingMemory.search("dark", threshold: 0.1, limit: 10)
      
      # Should find the user_pref memory since it contains "dark"
      assert Enum.any?(results, fn {k, _, _} -> k == :user_pref end)
      
      # Should not include unrelated data
      refute Enum.any?(results, fn {k, _, _} -> k == :unrelated end)
      
      # Search for a term that shouldn't match anything
      empty_results = WorkingMemory.search("nonexistent_term", threshold: 0.1, limit: 10)
      assert Enum.empty?(empty_results)
    end
  end

  describe "persistence with ETS" do
    test "maintains state across process restarts" do
      # Store a value with a long TTL
      :ok = WorkingMemory.store(:persistence_test, :important_data, "survive_restart", ttl: :infinity)
      
      # Verify it's there
      assert {:ok, "survive_restart"} = WorkingMemory.retrieve(:persistence_test, :important_data)
      
      # Restart the GenServer
      Process.whereis(WorkingMemory) |> Process.exit(:normal)
      :timer.sleep(100) # Give it time to restart
      
      # The value should still be there if using ETS
      assert {:ok, "survive_restart"} = WorkingMemory.retrieve(:persistence_test, :important_data)
    end
  end
end
