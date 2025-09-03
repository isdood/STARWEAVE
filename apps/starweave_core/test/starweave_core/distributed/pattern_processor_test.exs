defmodule StarweaveCore.Distributed.PatternProcessorTest do
  use ExUnit.Case, async: false
  
  alias StarweaveCore.Distributed.PatternProcessor
  alias StarweaveCore.Distributed.TaskDistributor
  
  setup do
    # Start the Task.Supervisor with a unique name
    task_sup_name = :"test_task_sup_#{System.unique_integer([:positive])}"
    {:ok, task_sup} = Task.Supervisor.start_link(name: task_sup_name)
    
    # Start the PatternProcessor with a test name
    test_name = :"test_processor_#{System.unique_integer([:positive])}"
    
    # Mock the TaskDistributor module
    :meck.new(TaskDistributor, [:no_link, :unstick, :passthrough])
    
    # Start the PatternProcessor with the test name
    {:ok, pid} = PatternProcessor.start_link(name: test_name, task_timeout: 1000)
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
      if Process.alive?(task_sup), do: Process.exit(task_sup, :normal)
      :meck.unload(TaskDistributor)
    end)
    
    %{
      name: test_name, 
      pid: pid,
      task_sup: task_sup
    }
  end
  
  test "processes a pattern and returns started", %{name: name} do
    # Mock the TaskDistributor to return a test reference
    test_ref = make_ref()
    :meck.expect(TaskDistributor, :submit_task, fn _input, _fun, _opts -> 
      {:ok, test_ref}
    end)
    
    # Test a simple pattern processing
    assert {:ok, :started} = PatternProcessor.process_pattern("test-pattern", name: name)
  end
  
  test "handles task completion", %{name: name} do
    test_ref = make_ref()
    
    # Mock the TaskDistributor to return a test reference and simulate task completion
    :meck.expect(TaskDistributor, :submit_task, fn _input, _fun, _opts -> 
      # Simulate task completion after a short delay
      Task.start_link(fn ->
        :timer.sleep(50)
        send(Process.whereis(name), {:DOWN, test_ref, :process, self(), :normal})
      end)
      {:ok, test_ref}
    end)
    
    # Start pattern processing
    assert {:ok, :started} = PatternProcessor.process_pattern("test-pattern", name: name)
    
    # Give it time to process
    :timer.sleep(200)
  end
  
  test "handles task timeout", %{name: name} do
    test_ref = make_ref()
    
    # Mock the TaskDistributor to return a test reference but don't complete the task
    :meck.expect(TaskDistributor, :submit_task, fn _input, _fun, _opts -> 
      {:ok, test_ref}
    end)
    
    # Start pattern processing with a short timeout
    assert {:ok, :started} = PatternProcessor.process_pattern("test-pattern", name: name)
    
    # Wait for the timeout to occur
    :timer.sleep(1100)
  end
end
