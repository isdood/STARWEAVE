# Test script for distributed pattern processing
defmodule DistributedProcessingTest do
  @moduledoc """
  Test module for distributed pattern processing.
  Run this from the main node with: `elixir -S mix run scripts/distributed/test_distributed_processing.exs`
  """
  
  def run_test do
    IO.puts("\n🚀 Testing Distributed Processing")
    IO.puts("==========================")
    
    # Test 1: Basic task distribution
    IO.puts("\n🔍 Test 1: Basic Task Distribution")
    IO.puts("----------------------------")
    test_basic_distribution()
    
    # Test 2: Pattern processing
    IO.puts("\n🔍 Test 2: Pattern Processing")
    IO.puts("------------------------")
    test_pattern_processing()
    
    # Test 3: Worker availability
    IO.puts("\n🔍 Test 3: Worker Availability")
    IO.puts("--------------------------")
    test_worker_availability()
    
    IO.puts("\n✅ All tests completed!")
  end
  
  defp test_basic_distribution do
    IO.puts("Submitting a simple task to be processed by any available worker...")
    
    task = fn data ->
      Process.sleep(1000)  # Simulate work
      "Processed by #{inspect(node())} with data: #{data}"
    end
    
    case StarweaveCore.Distributed.TaskDistributor.submit_task("test_data", task, distributed: true) do
      {:ok, result} ->
        IO.puts("✅ Task completed successfully!")
        IO.puts("   Result: #{inspect(result)}")
        
      {:error, reason} ->
        IO.puts("❌ Task failed: #{inspect(reason)}")
    end
  end
  
  defp test_pattern_processing do
    IO.puts("Submitting a pattern processing task...")
    
    # Example pattern processing function
    process_pattern = fn pattern ->
      # Simulate pattern processing
      Process.sleep(1500)
      %{
        pattern: pattern,
        processed_by: node(),
        timestamp: DateTime.utc_now(),
        result: :processed
      }
    end
    
    # Submit to pattern processor
    case StarweaveCore.Distributed.PatternProcessor.process_pattern("test_pattern") do
      {:ok, result} ->
        IO.puts("✅ Pattern processing completed!")
        IO.puts("   Result: #{inspect(result, pretty: true)}")
        
      {:error, reason} ->
        IO.puts("❌ Pattern processing failed: #{inspect(reason)}")
    end
  end
  
  defp test_worker_availability do
    IO.puts("Checking worker availability...")
    
    # Get list of connected nodes
    workers = [node() | Node.list()]
    IO.puts("Available workers: #{inspect(workers)}")
    
    # Test sending a task to each worker
    workers
    |> Enum.each(fn worker ->
      task = fn _ ->
        {worker, node(), :pong}
      end
      
      IO.puts("\nSending task to #{inspect(worker)}...")
      
      case StarweaveCore.Distributed.TaskDistributor.submit_task(:ping, task, 
            distributed: true,
            target_node: worker
          ) do
        {:ok, result} ->
          IO.puts("✅ Response from #{inspect(elem(result, 1))}: #{inspect(result)}")
          
        {:error, reason} ->
          IO.puts("❌ Error from #{inspect(worker)}: #{inspect(reason)}")
      end
    end)
  end
end

# Run the tests
DistributedProcessingTest.run_test()
