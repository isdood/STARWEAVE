# Test script for enhanced distributed task processing
defmodule EnhancedDistributionTest do
  @moduledoc """
  Test module for enhanced distributed task processing.
  Run this from the main node with: `elixir -S mix run scripts/distributed/test_enhanced_distribution.exs`
  """
  
  alias StarweaveCore.Distributed.TaskDistributor
  
  def run_test do
    # Start or get the TaskDistributor
    {:ok, _pid} = case Process.whereis(TaskDistributor) do
      nil -> TaskDistributor.start_link(name: TaskDistributor)
      _pid -> {:ok, Process.whereis(TaskDistributor)}
    end
    
    # Register the current node as a worker
    case TaskDistributor.register_worker(node(), name: TaskDistributor) do
      :ok -> :ok
      {:error, :already_registered} -> :ok  # Already registered, continue
      error -> error
    end
    
    # Test basic task submission
    test_basic_distribution()
    
    # Test task prioritization
    test_task_prioritization()
    
    # Test fault tolerance
    test_fault_tolerance()
    
    # Test monitoring and metrics
    test_monitoring()
    
    :ok
  end
  
  defp test_basic_distribution do
    IO.puts("\n=== Testing Basic Task Distribution ===")
    
    # Submit a simple task
    {:ok, task_id} = TaskDistributor.submit_task("Hello", &String.upcase/1)
    IO.puts("Submitted task #{task_id}")
    
    # Wait for task to complete
    :timer.sleep(500)
    
    # Check task status
    {:ok, status} = TaskDistributor.task_status(task_id)
    IO.puts("Task status: #{inspect(status)}")
    
    # Get task details
    {:ok, task} = TaskDistributor.get_task(task_id)
    IO.puts("Task details: #{inspect(task, pretty: true)}")
  end
  
  defp test_task_prioritization do
    IO.puts("\n=== Testing Task Prioritization ===")
    
    # Submit tasks with different priorities
    tasks = [
      {:low, "low-priority"},
      {:normal, "normal-priority"},
      {:high, "high-priority"}
    ]
    
    # Submit tasks with a delay to ensure they're queued
    task_ids = Enum.map(tasks, fn {priority, name} ->
      {:ok, task_id} = TaskDistributor.submit_task(
        name,
        fn msg -> 
          Process.sleep(100)  # Simulate work
          "Processed: #{msg}" 
        end,
        priority: priority
      )
      IO.puts("Submitted #{priority} priority task: #{task_id}")
      task_id
    end)
    
    # Check task statuses
    :timer.sleep(1000)
    
    Enum.each(task_ids, fn task_id ->
      {:ok, task} = TaskDistributor.get_task(task_id)
      IO.puts("Task #{task_id} (priority: #{task.priority}): #{task.status}")
    end)
  end
  
  defp test_fault_tolerance do
    IO.puts("\n=== Testing Fault Tolerance ===")
    
    # Submit a task that will fail
    {:ok, task_id} = TaskDistributor.submit_task(
      :will_fail,
      fn _ -> 
        Process.sleep(100)
        raise "Simulated task failure"
      end,
      max_retries: 2
    )
    
    IO.puts("Submitted failing task with retries: #{task_id}")
    
    # Monitor task status
    :timer.sleep(1000)
    
    {:ok, task} = TaskDistributor.get_task(task_id)
    IO.puts("Task status after failure: #{task.status}")
    IO.puts("Retry attempts: #{task.retries}/#{task.max_retries}")
  end
  
  defp test_monitoring do
    IO.puts("\n=== Testing Monitoring ===")
    
    # Get current metrics
    metrics = TaskDistributor.get_metrics()
    IO.puts("\nCurrent Metrics:")
    IO.puts("  Workers: #{metrics.worker_count}")
    IO.puts("  Tasks completed: #{metrics.tasks_completed}")
    IO.puts("  Tasks failed: #{metrics.tasks_failed}")
    IO.puts("  Tasks running: #{metrics.tasks_running}")
    IO.puts("  Tasks queued: #{metrics.tasks_queued}")
    IO.puts("  Avg. task time: #{:erlang.float_to_binary(metrics.avg_task_time / 1_000_000, [decimals: 2])}ms")
    
    # List workers
    workers = TaskDistributor.list_workers()
    IO.puts("\nWorkers:")
    Enum.each(workers, fn worker ->
      IO.puts("  #{worker.node}: #{worker.status} (load: #{worker.current_load}/#{worker.capacity})")
    end)
  end
end

# Run the tests if this file is executed directly
if Mix.env() != :test do
  EnhancedDistributionTest.run_test()
end
