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
  
  defp ensure_worker_connection do
    # Try to connect to the known worker node
    worker_node = :"worker@001-LITE"
    
    # Skip if already connected
    if worker_node in Node.list() do
      IO.puts("✅ Already connected to worker node: #{worker_node}")
      :ok
    else
      IO.puts("🔌 Attempting to connect to worker node: #{worker_node}")
      case Node.connect(worker_node) do
        true -> 
          IO.puts("✅ Successfully connected to worker node: #{worker_node}")
          :ok
        false ->
          IO.puts("❌ Failed to connect to worker node: #{worker_node}")
          :error
      end
    end
  end

  defp test_basic_distribution do
    IO.puts("Submitting a simple task to be processed by any available worker...")
    
    # First ensure we're connected to worker nodes
    case ensure_worker_connection() do
      :ok ->
        # Get all connected nodes, excluding the current node
        worker_nodes = Node.list()
        available_nodes = [node() | worker_nodes]
        
        IO.puts("\n📡 Available nodes: #{inspect(available_nodes)}")
        
        task = fn data ->
          # Simulate some work
          Process.sleep(1000)
          {:ok, "Processed by #{inspect(node())} with data: #{data}"}
        end
        
        # Try distributed execution first if we have workers
        if worker_nodes != [] do
          IO.puts("\n🚀 Testing distributed task execution...")
          
          case StarweaveCore.Distributed.TaskDistributor.submit_task("test_data", task, distributed: true) do
            {:ok, result} ->
              IO.puts("✅ Distributed task completed successfully!")
              IO.puts("   Result: #{inspect(result)}")
              
            {:error, reason} ->
              IO.puts("❌ Distributed task failed: #{inspect(reason)}")
              IO.puts("\n🔄 Falling back to local execution...")
              run_local_task(task)
          end
        else
          IO.puts("\n⚠️  No worker nodes available for distributed execution.")
          run_local_task(task)
        end
        
      :error ->
        IO.puts("\n⚠️  Could not connect to any worker nodes. Using local execution only.")
        run_local_task(fn data ->
          # Simulate some work
          Process.sleep(1000)
          {:ok, "Processed locally by #{inspect(node())} with data: #{data}"}
        end)
    end
  end
  
  defp run_local_task(task) do
    IO.puts("\n🏠 Testing local task execution...")
    case StarweaveCore.Distributed.TaskDistributor.submit_task("test_data", task, distributed: false) do
      {:ok, result} ->
        IO.puts("✅ Local task completed successfully!")
        IO.puts("   Result: #{inspect(result)}")
        
      {:error, reason} ->
        IO.puts("❌ Local task failed: #{inspect(reason)}")
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
    
    # Get list of connected nodes (including the current node)
    workers = Node.list()
    IO.puts("Available workers: #{inspect(workers)}")
    
    # Test each worker node
    Enum.each(workers, fn worker ->
      IO.puts("\nTesting worker: #{inspect(worker)}")
      
      # Define a simple function as a string that we'll evaluate on the remote node
      # Note: We use node() inside the string so it's evaluated on the remote node
      task_code = """
      # This will be evaluated on the remote node
      Process.sleep(500)
      # Return the node name where this task is running
      "Task executed on " <> inspect(node())
      """
      
      # Try to run the task on the worker node using :rpc.call with string evaluation
      IO.puts("  ↳ Sending task to #{inspect(worker)}...")
      
      # Use :rpc.call to evaluate the code directly on the remote node
      case :rpc.call(worker, Code, :eval_string, [task_code], 5000) do
        {:badrpc, reason} ->
          IO.puts("  ❌ RPC call to #{inspect(worker)} failed: #{inspect(reason)}")
          
        {result, _bindings} ->
          # The result is a tuple with the evaluation result and bindings
          IO.puts("  ✅ Task result from #{inspect(worker)}: #{inspect(result)}")
          
        result ->
          # Handle any other result format
          IO.puts("  ✅ Task result from #{inspect(worker)}: #{inspect(result)}")
      end
    end)
    
    # Test local execution
    IO.puts("\nTesting local execution on #{inspect(node())}...")
    local_result = 
      try do
        # Same task as above but executed locally
        Process.sleep(500)
        "Task executed locally on #{inspect(node())}"
      rescue
        e -> {:error, Exception.message(e)}
      end
    
    IO.puts("  ✅ Local task result: #{inspect(local_result)}")
  end
end

# Run the tests if this file is executed directly
if Mix.env() != :test do
  DistributedProcessingTest.run_test()
end
