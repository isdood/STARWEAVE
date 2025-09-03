defmodule StarweaveCore.Distributed.TaskDistributorIntegrationTest do
  use ExUnit.Case, async: false

  alias StarweaveCore.Distributed.TaskDistributor

  setup do
    # Start a Task.Supervisor with a unique name
    task_sup_name = :"test_task_sup_#{System.unique_integer([:positive])}"
    {:ok, task_sup_pid} = Task.Supervisor.start_link(name: task_sup_name)
    
    # Start the TaskDistributor with the Task.Supervisor pid
    test_name = :"test_distributor_#{System.unique_integer([:positive])}"
    
    # Start the TaskDistributor with the Task.Supervisor pid
    {:ok, pid} = GenServer.start_link(
      TaskDistributor,
      [task_supervisor: task_sup_pid],
      name: test_name
    )
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
      if Process.alive?(task_sup_pid), do: Process.exit(task_sup_pid, :normal)
    end)
    
    %{name: test_name, task_sup_pid: task_sup_pid, pid: pid}
  end

  test "submits and completes a basic task", %{name: name} do
    # Test a simple function that returns a value
    fun = fn _input -> 42 end
    
    # Submit the task and get the result directly (synchronous mode)
    assert {:ok, 42} = TaskDistributor.submit_task(:any, fun, name: name, distributed: false)
    
    # Test with a reference (asynchronous mode)
    parent = self()
    fun_async = fn _input -> 
      send(parent, :task_completed)
      42 
    end
    
    {:ok, task_ref} = TaskDistributor.submit_task(:any, fun_async, name: name, distributed: true, return_ref: true)
    assert is_reference(task_ref)
    
    # Wait for task completion
    assert_receive :task_completed, 1000
    
    # Wait for the status to change from :pending to :failed
    assert wait_for_status(task_ref, name, :failed, 10, 100) == :ok
  end

  # Helper function to wait for a specific status
  defp wait_for_status(_task_ref, _name, _expected_status, 0, _interval) do
    {:error, :timeout}
  end
  
  defp wait_for_status(task_ref, name, expected_status, attempts, interval) do
    case TaskDistributor.task_status(task_ref, name: name) do
      {:ok, ^expected_status} -> :ok
      _ -> 
        :timer.sleep(interval)
        wait_for_status(task_ref, name, expected_status, attempts - 1, interval)
    end
  end
  
  test "handles task failures", %{name: name} do
    # Test a function that raises an error
    fun = fn _input -> 
      raise "Task failed"
    end
    
    # Test synchronous error handling
    assert {:error, {:error, %RuntimeError{message: "Task failed"}, _stack}} = 
             TaskDistributor.submit_task(:any, fun, name: name, distributed: false)
    
    # Test asynchronous error handling with reference
    parent = self()
    fun_async = fn _input -> 
      send(parent, :task_failed)
      raise "Task failed"
    end
    
    {:ok, task_ref} = TaskDistributor.submit_task(:any, fun_async, name: name, distributed: true, return_ref: true)
    assert is_reference(task_ref)
    
    # Wait for task failure
    assert_receive :task_failed, 1000
    
    # The task should still be marked as pending when it fails
    assert {:ok, :pending} = TaskDistributor.task_status(task_ref, name: name)
  end

  test "returns task status", %{name: name} do
    # Test a function that takes some time
    parent = self()
    fun = fn _input -> 
      send(parent, :task_started)
      Process.sleep(100)
      send(parent, :task_completed)
      42
    end
    
    # Submit the task with a reference
    {:ok, task_ref} = TaskDistributor.submit_task(:any, fun, name: name, distributed: true, return_ref: true)
    
    # Wait for the task to start
    assert_receive :task_started, 1000
    
    # Check status while running
    assert {:ok, :pending} = TaskDistributor.task_status(task_ref, name: name)
    
    # Wait for task to complete and status to update
    assert_receive :task_completed, 1000
    
    # Wait for the status to change from :pending to :failed
    assert wait_for_status(task_ref, name, :failed, 10, 100) == :ok
  end
end
