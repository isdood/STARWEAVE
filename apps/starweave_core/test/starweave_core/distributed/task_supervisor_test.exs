defmodule StarweaveCore.Distributed.TaskSupervisorTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias StarweaveCore.Distributed.TaskSupervisor
  
  setup do
    # Create unique names for this test
    test_name = :"test_supervisor_#{System.unique_integer([:positive])}"
    task_supervisor_name = :"task_supervisor_#{System.unique_integer([:positive])}"
    
    # Start a Task.Supervisor first
    {:ok, task_sup_pid} = Task.Supervisor.start_link(name: task_supervisor_name)
    
    # Start the TaskRecovery process first
    recovery_name = :"task_recovery_#{System.unique_integer([:positive])}"
    {:ok, _recovery_pid} = StarweaveCore.Distributed.TaskRecovery.start_link(
      name: recovery_name,
      task_supervisor: task_supervisor_name
    )
    
    # Start the TaskSupervisor with the task_supervisor option
    {:ok, pid} = TaskSupervisor.start_link(
      name: test_name,
      task_supervisor: task_supervisor_name,
      recovery_name: recovery_name
    )
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      if Process.alive?(task_sup_pid), do: Process.exit(task_sup_pid, :normal)
    end)
    
    %{
      name: test_name, 
      pid: pid, 
      task_supervisor: task_supervisor_name,
      task_supervisor_pid: task_sup_pid
    }
  end
  
  test "starts a supervised task" do
    test_pid = self()
    
    # Create a simple task that sends a message when done
    task_fun = fn -> 
      send(test_pid, :task_completed)
      :ok 
    end
    
    # Start the task under supervision
    {:ok, pid} = TaskSupervisor.start_task(task_fun)
    
    # Verify the task was started and completed
    assert is_pid(pid)
    assert_receive :task_completed, 100
    
    # Clean up
    TaskSupervisor.stop_task(pid)
  end
  
  test "handles task failures with max retry attempts" do
    test_pid = self()
    
    # Create a task that will always fail
    task_fun = fn ->
      send(test_pid, :task_failed)
      exit(:failed)
    end
    
    # Capture logs for the entire test
    log = capture_log([level: :error], fn ->
      # Start the task with retry options
      {:ok, pid} = TaskSupervisor.start_task(
        task_fun,
        max_attempts: 2,
        initial_backoff: 10,
        max_backoff: 100
      )
      
      # Verify the task failed and was retried
      assert_receive :task_failed, 1000
      assert_receive :task_failed, 1000
      
      # Give time for error logging and ensure task is dead
      Process.sleep(500)
      
      # Verify the task process is no longer alive
      refute Process.alive?(pid)
      
      # Force log flush
      :sys.get_state(StarweaveCore.Distributed.TaskRecovery)
      Process.sleep(100)
    end)
    
    # Verify the task was retried the expected number of times
    assert log =~ "Task failed after 2 attempts"
    assert log =~ "Max attempts reached"
  end
end
