# Test script for distributed pattern processing
defmodule DistributedProcessingTest do
  @moduledoc """
  Test module for distributed pattern processing.
  Run this from the main node with: `elixir -S mix run scripts/distributed/test_distributed_processing.exs`
  """
  
  def run_test do
    IO.puts("\n🚀 Testing Distributed Processing")
    IO.puts("==========================")
    
    # Ensure all distributed components are running
    case ensure_distributed_components_started() do
      :ok ->
        # Give the system a moment to stabilize
        Process.sleep(500)
        
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
        
      error ->
        IO.puts("\n❌ Failed to initialize distributed components: #{inspect(error)}")
        IO.puts("Please ensure the main node and worker nodes are running")
    end
  end
  
  defp ensure_distributed_components_started do
    IO.puts("\n🔧 Initializing distributed components...")
    
    # Ensure Task.Supervisor is running
    task_supervisor = Task.Supervisor
    task_supervisor_name = StarweaveCore.Distributed.TaskSupervisor
    
    case Process.whereis(task_supervisor_name) do
      nil ->
        IO.puts("Starting Task.Supervisor...")
        case Task.Supervisor.start_link(name: task_supervisor_name) do
          {:ok, _} -> 
            IO.puts("✅ Task.Supervisor started successfully")
            :ok
          error -> 
            IO.puts("❌ Failed to start Task.Supervisor: #{inspect(error)}")
            error
        end
      _ ->
        IO.puts("✅ Task.Supervisor already running")
        :ok
    end
    
    # Ensure TaskDistributor is running
    task_distributor_name = StarweaveCore.Distributed.TaskDistributor
    
    case Process.whereis(task_distributor_name) do
      nil ->
        IO.puts("\nStarting TaskDistributor...")
        case StarweaveCore.Distributed.TaskDistributor.start_link(
               name: task_distributor_name,
               task_supervisor: task_supervisor_name
             ) do
          {:ok, _} -> 
            IO.puts("✅ TaskDistributor started successfully")
            :ok
          error -> 
            IO.puts("❌ Failed to start TaskDistributor: #{inspect(error)}")
            error
        end
      _ ->
        IO.puts("✅ TaskDistributor already running")
        :ok
    end
    
    # Ensure PatternProcessor is running
    pattern_processor_name = StarweaveCore.Distributed.PatternProcessor
    
    case Process.whereis(pattern_processor_name) do
      nil ->
        IO.puts("\nStarting PatternProcessor...")
        case StarweaveCore.Distributed.PatternProcessor.start_link(
               name: pattern_processor_name,
               task_supervisor: task_supervisor_name
             ) do
          {:ok, _} -> 
            IO.puts("✅ PatternProcessor started successfully")
            :ok
          error -> 
            IO.puts("❌ Failed to start PatternProcessor: #{inspect(error)}")
            error
        end
      _ ->
        IO.puts("✅ PatternProcessor already running")
        :ok
    end
  end
  
  defp test_basic_distribution do
    IO.puts("Submitting a simple task to be processed by any available worker...")
    
    task = fn data ->
      # Simulate some work
      Process.sleep(1000)
      {:ok, "Processed by #{inspect(node())} with data: #{data}"}
    end
    
    available_nodes = [node() | Node.list()]
    IO.puts("Available nodes: #{inspect(available_nodes)}")
    
    # If no other nodes are available, add a warning
    if length(available_nodes) <= 1 do
      IO.puts("⚠️  No worker nodes available. Will use the current node.")
    end
    
    case StarweaveCore.Distributed.TaskDistributor.submit_task("test_data", task, distributed: true) do
      {:ok, result} ->
        IO.puts("✅ Task completed successfully!")
        IO.puts("   Result: #{inspect(result)}")
        
      {:error, reason} ->
        IO.puts("❌ Task failed: #{inspect(reason)}")
        
        # If the task failed due to no worker nodes, try running it locally
        if reason == :no_workers_available do
          IO.puts("⚠️  No worker nodes available. Trying local execution...")
          
          case StarweaveCore.Distributed.TaskDistributor.submit_task("test_data", task, distributed: false) do
            {:ok, result} ->
              IO.puts("✅ Local task completed successfully!")
              IO.puts("   Result: #{inspect(result)}")
              
            {:error, reason} ->
              IO.puts("❌ Local task also failed: #{inspect(reason)}")
          end
        end
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
    
    # First register the pattern processing function
    IO.puts("Registering pattern processor...")
    case StarweaveCore.Distributed.PatternProcessor.register_pattern_processor(:test_pattern, process_pattern) do
      :ok ->
        IO.puts("✅ Pattern processor registered successfully")
        
        # Submit to pattern processor
        IO.puts("Processing pattern...")
        case StarweaveCore.Distributed.PatternProcessor.process_pattern(:test_pattern) do
          {:ok, result} ->
            IO.puts("✅ Pattern processing completed!")
            IO.puts("   Result: #{inspect(result, pretty: true)}")
            
          {:error, reason} ->
            IO.puts("❌ Pattern processing failed: #{inspect(reason)}")
        end
      {:error, reason} ->
        IO.puts("❌ Failed to register pattern processor: #{inspect(reason)}")
    end
  end
  
  defp test_worker_availability do
    IO.puts("Checking worker availability...")
    
    # Get list of connected nodes
    workers = [node() | Node.list()]
    IO.puts("Available workers: #{inspect(workers)}")
    
    # Test each worker
    Enum.each(workers, fn worker ->
      IO.puts("\nSending task to #{inspect(worker)}...")
      
      task = fn _data ->
        # Simple task that returns the node it's running on
        {:ok, "Hello from #{inspect(node())}"}
      end
      
      # Try to run the task on the worker node
      case Node.ping(worker) do
        :pong ->
          # Node is alive, try to run the task
          result = :rpc.call(worker, Task, :async, [fn -> task.("test") end])
                  |> Task.await(5000)  # Wait up to 5 seconds for the task to complete
                  
          case result do
            {:ok, message} ->
              IO.puts("✅ Response from #{inspect(worker)}: #{inspect(message)}")
              
            error ->
              IO.puts("❌ Task on #{inspect(worker)} failed: #{inspect(error)}")
          end
          
        :pang ->
          IO.puts("❌ Node #{inspect(worker)} is not reachable")
          
        other ->
          IO.puts("❌ Unexpected response pinging #{inspect(worker)}: #{inspect(other)}")
      end
    end)
  end
end

# Run the tests
DistributedProcessingTest.run_test()
