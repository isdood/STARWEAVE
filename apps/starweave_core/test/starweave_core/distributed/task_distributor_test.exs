defmodule StarweaveCore.Distributed.TaskDistributorTest do
  use ExUnit.Case, async: true
  alias StarweaveCore.Distributed.TaskDistributor

  setup do
    # Start a Task.Supervisor for testing
    {:ok, task_sup} = Task.Supervisor.start_link()
    task_sup_name = :"test_task_supervisor_#{System.unique_integer([:positive])}"
    Process.register(task_sup, task_sup_name)
    
    # Start the TaskDistributor
    {:ok, pid} = TaskDistributor.start_link(task_supervisor: task_sup_name, name: :test_distributor)
    
    # Clean up after tests
    on_exit(fn ->
      if Process.alive?(pid) do
        try do
          GenServer.stop(pid, :normal, :infinity)
        catch
          :exit, _ -> :ok
        end
      end
      
      if Process.alive?(task_sup) do
        try do
          Process.exit(task_sup, :normal)
        catch
          :exit, _ -> :ok
        end
      end
    end)
    
    %{pid: pid, task_sup: task_sup, task_sup_name: task_sup_name}
  end

  test "submits and completes a basic task" do
    # Test a simple function that returns a value
    fun = fn _input -> 42 end
    
    # Submit the task and get the result directly
    assert {:ok, 42} = TaskDistributor.submit_task(:any, fun, name: :test_distributor, distributed: false)
  end

  test "handles task failures" do
    # Test a function that raises an error
    fun = fn _input -> 
      raise "Task failed"
    end
    
    # Submit the task and check for error
    assert {:error, {:error, %RuntimeError{message: "Task failed"}, _stack}} = 
             TaskDistributor.submit_task(:any, fun, name: :test_distributor, distributed: false)
  end
end
