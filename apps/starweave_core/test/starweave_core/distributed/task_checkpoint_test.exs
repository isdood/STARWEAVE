defmodule StarweaveCore.Distributed.TaskCheckpointTest do
  use ExUnit.Case, async: false
  
  alias StarweaveCore.Distributed.TaskCheckpoint
  
  setup do
    # Start the TaskCheckpoint with a unique name for each test
    test_name = :"test_checkpoint_#{System.unique_integer([:positive])}"
    {:ok, pid} = TaskCheckpoint.start_link(name: test_name)
    
    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :normal)
    end)
    
    %{name: test_name, pid: pid}
  end
  
  test "saves and retrieves checkpoints", %{name: name} do
    task_ref = make_ref()
    state = %{progress: 50, data: "test data"}
    
    # Save a checkpoint
    :ok = TaskCheckpoint.checkpoint(name, task_ref, state)
    
    # Retrieve the checkpoint
    assert {:ok, ^state} = TaskCheckpoint.get_checkpoint(name, task_ref)
  end
  
  test "returns :not_found for non-existent checkpoints", %{name: name} do
    assert :not_found = TaskCheckpoint.get_checkpoint(name, make_ref())
  end
  
  test "handles multiple checkpoints for different tasks", %{name: name} do
    task1_ref = make_ref()
    task2_ref = make_ref()
    
    state1 = %{progress: 25, data: "task 1 data"}
    state2 = %{progress: 75, data: "task 2 data"}
    
    # Save checkpoints for both tasks
    :ok = TaskCheckpoint.checkpoint(name, task1_ref, state1)
    :ok = TaskCheckpoint.checkpoint(name, task2_ref, state2)
    
    # Verify both checkpoints are stored independently
    assert {:ok, ^state1} = TaskCheckpoint.get_checkpoint(name, task1_ref)
    assert {:ok, ^state2} = TaskCheckpoint.get_checkpoint(name, task2_ref)
  end
end
