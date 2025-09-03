defmodule StarweaveCore.Distributed.SimpleTaskTest do
  use ExUnit.Case

  test "runs a simple task" do
    # Start a Task.Supervisor
    {:ok, task_sup} = Task.Supervisor.start_link()
    
    # Start a simple task
    task = Task.Supervisor.async_nolink(task_sup, fn ->
      :timer.sleep(100)
      {:ok, 42}
    end)
    
    # Wait for the task to complete
    result = Task.await(task, 500)
    assert result == {:ok, 42}
  end
end
