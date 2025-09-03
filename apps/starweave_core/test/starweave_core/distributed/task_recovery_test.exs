defmodule StarweaveCore.Distributed.TaskRecoveryTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias StarweaveCore.Distributed.TaskRecovery
  
  setup do
    # Start a unique TaskRecovery for each test to avoid conflicts
    name = :"test_recovery_#{System.unique_integer([:positive])}"
    
    # Start a Task.Supervisor for the test
    task_supervisor = :"task_sup_#{System.unique_integer([:positive])}"
    {:ok, task_sup_pid} = Task.Supervisor.start_link(name: task_supervisor)
    
    # Start the TaskRecovery process with the task_supervisor
    {:ok, recovery_pid} = TaskRecovery.start_link(
      name: name,
      task_supervisor: task_supervisor
    )
    
    # Verify the process is alive and registered
    Process.sleep(10) # Give it a moment to start
    
    on_exit(fn ->
      if Process.alive?(recovery_pid) do
        try do
          GenServer.stop(recovery_pid, :normal)
        catch
          :exit, _ -> :ok
        end
      end
      
      if Process.alive?(task_sup_pid) do
        try do
          Supervisor.stop(task_sup_pid, :normal)
        catch
          :exit, _ -> :ok
        end
      end
    end)
    
    %{
      recovery_name: name, 
      recovery_pid: recovery_pid,
      task_supervisor: task_supervisor,
      task_supervisor_pid: task_sup_pid
    }
  end
  
  test "handles successful task completion without retries", %{recovery_name: name} do
    test_pid = self()
    
    # Create a task that will complete successfully on first try
    task_fun = fn ->
      send(test_pid, :task_completed)
      :ok
    end
    
    # Start the task directly
    {:ok, task_pid} = Task.start_link(task_fun)
    
    # Monitor the task with recovery
    :ok = GenServer.call(name, {:monitor_task, task_pid, task_fun, [
      max_attempts: 1,  # Only allow one attempt
      initial_backoff: 10,
      max_backoff: 100
    ]})
    
    # Verify the task runs and completes
    assert_receive :task_completed, 1000
    
    # No additional messages should be received
    refute_receive :task_completed, 200
    
    # No error logs expected
    log = capture_log([level: :error], fn ->
      # Force log flush
      :sys.get_state(name)
      Process.sleep(100)
    end)
    
    # Check that no error logs were generated
    assert log == ""
  end
  
  test "stops retrying after max attempts", %{recovery_name: name, task_supervisor: task_supervisor} do
    test_pid = self()
    
    # This task will always fail
    task_fun = fn ->
      send(test_pid, :task_ran)
      exit(:failed)
    end
    
    # Capture logs for the entire test
    log = capture_log([level: :error], fn ->
      # Start the task through the supervisor
      {:ok, task_pid} = Task.Supervisor.start_child(task_supervisor, task_fun)
      
      # Monitor the task with recovery, but only allow 1 retry (2 total attempts)
      :ok = GenServer.call(name, {:monitor_task, task_pid, task_fun, [
        max_attempts: 2,
        initial_backoff: 10,
        max_backoff: 100
      ]})
      
      # Verify the task runs and fails (first attempt)
      assert_receive :task_ran, 1000
      
      # Wait for the retry (second attempt)
      assert_receive :task_ran, 1000
      
      # Give time for error logging and ensure task is dead
      Process.sleep(500)
      
      # Verify the task was not retried again (max attempts reached)
      refute_receive :task_ran, 500
      
      # Verify the task process is no longer alive
      refute Process.alive?(task_pid)
      
      # Force log flush
      :sys.get_state(name)
      Process.sleep(100)
    end)
    
    # Verify we see the max attempts message in the logs
    assert log =~ "Task failed after 2 attempts"
    assert log =~ "Max attempts reached"
  end
  
  test "handles task failure with max retry attempts", %{recovery_name: name, task_supervisor: task_supervisor} do
    test_pid = self()
    
    # This task will fail with an exit signal
    task_fun = fn -> 
      send(test_pid, :task_attempt)
      exit(:failed)
    end
    
    # Capture logs for the entire test
    log = capture_log([level: :error], fn ->
      # Start the task through the supervisor
      {:ok, task_pid} = Task.Supervisor.start_child(task_supervisor, task_fun)
      
      # Start monitoring with max_attempts: 2
      :ok = GenServer.call(name, {:monitor_task, task_pid, task_fun, [
        max_attempts: 2,
        initial_backoff: 10,
        max_backoff: 100
      ]})
      
      # Wait for the first attempt
      assert_receive :task_attempt, 1000
      
      # Wait for the second attempt
      assert_receive :task_attempt, 1000
      
      # Give time for error logging and ensure task is dead
      Process.sleep(500)
      
      # Verify no more attempts are made
      refute_receive :task_attempt, 500
      
      # Verify the task process is no longer alive
      refute Process.alive?(task_pid)
      
      # Force log flush
      :sys.get_state(name)
      Process.sleep(100)
    end)
    
    # Verify we see the max attempts message in the logs
    assert log =~ "Task failed after 2 attempts"
    assert log =~ "Max attempts reached"
  end
end
