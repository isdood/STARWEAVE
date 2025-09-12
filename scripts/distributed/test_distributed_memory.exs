# Test script for distributed working memory
defmodule DistributedMemoryTest do
  @moduledoc """
  Test module for distributed working memory functionality.
  Run this from the main node with: `elixir -S mix run scripts/distributed/test_distributed_memory.exs`
  """
  
  def run_test do
    IO.puts("\n🚀 Testing Distributed Working Memory")
    IO.puts("============================")
    
    # Ensure the application is started
    Application.ensure_all_started(:starweave_core)
    
    # Get the list of connected nodes
    nodes = [node() | Node.list()]
    IO.puts("Connected nodes: #{inspect(nodes)}")
    
    # Test basic storage and retrieval
    test_basic_operations()
    
    # Test context operations
    test_context_operations()
    
    # Test distributed search
    test_distributed_search()
    
    IO.puts("\n✅ All tests completed!")
  end
  
  defp test_basic_operations do
    IO.puts("\n🔍 Test 1: Basic Operations")
    IO.puts("----------------------")
    
    # Store a value
    :ok = StarweaveCore.Intelligence.DistributedWorkingMemory.store(:test, :key1, "value1")
    IO.puts("Stored value: {:test, :key1} = \"value1\"")
    
    # Retrieve the value
    {:ok, value} = StarweaveCore.Intelligence.DistributedMemory.retrieve(:test, :key1)
    IO.puts("Retrieved value: #{inspect(value)}")
    
    # Update the value
    :ok = StarweaveCore.Intelligence.DistributedWorkingMemory.store(:test, :key1, "updated_value1")
    {:ok, updated_value} = StarweaveCore.Intelligence.DistributedWorkingMemory.retrieve(:test, :key1)
    IO.puts("Updated value: #{inspect(updated_value)}")
    
    # Test non-existent key
    assert :not_found == StarweaveCore.Intelligence.DistributedWorkingMemory.retrieve(:test, :non_existent)
    IO.puts("Verified non-existent key returns :not_found")
  end
  
  defp test_context_operations do
    IO.puts("\n🔍 Test 2: Context Operations")
    IO.puts("--------------------------")
    
    # Store values in different contexts
    :ok = StarweaveCore.Intelligence.DistributedWorkingMemory.store(:user, :alice, %{name: "Alice", role: "admin"})
    :ok = StarweaveCore.Intelligence.DistributedWorkingMemory.store(:user, :bob, %{name: "Bob", role: "user"})
    :ok = StarweaveCore.Intelligence.DistributedWorkingMemory.store(:system, :config, %{theme: "dark", notifications: true})
    
    # Get all users
    {:ok, users} = StarweaveCore.Intelligence.DistributedWorkingMemory.get_context(:user)
    IO.puts("Users in context 'user': #{inspect(users)}")
    
    # Get system config
    {:ok, [config | _]} = StarweaveCore.Intelligence.DistributedWorkingMemory.get_context(:system)
    IO.puts("System config: #{inspect(config)}")
  end
  
  defp test_distributed_search do
    IO.puts("\n🔍 Test 3: Distributed Search")
    IO.puts("------------------------")
    
    # Add some test data
    test_data = [
      {:doc1, "Distributed systems are fun"},
      {:doc2, "Elixir makes distributed programming easy"},
      {:doc3, "Working with distributed memory is powerful"},
      {:doc4, "Consistent hashing helps with load balancing"}
    ]
    
    # Store test data
    Enum.each(test_data, fn {id, text} ->
      :ok = StarweaveCore.Intelligence.DistributedWorkingMemory.store(:docs, id, text)
    end)
    
    # Search for documents
    {:ok, results} = StarweaveCore.Intelligence.DistributedWorkingMemory.search("distributed")
    IO.puts("Search results for 'distributed':")
    Enum.each(results, fn {_ctx, id, text, score} ->
      IO.puts("  - #{id}: #{text} (score: #{:erlang.float_to_binary(score, decimals: 2)})")
    end)
  end
  
  # Helper function for assertions
  defp assert(condition, message) do
    if condition do
      IO.puts("✅ #{message}")
    else
      IO.puts("❌ FAILED: #{message}")
    end
  end
end

# Run the tests if this file is executed directly
if Mix.env() != :test do
  DistributedMemoryTest.run_test()
end
