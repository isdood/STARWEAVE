defmodule StarweaveCore.Distributed.PatternProcessor do
  @moduledoc """
  Handles distributed processing of patterns across the cluster.
  Manages task distribution, result aggregation, and state management.
  """
  use GenServer
  require Logger
  
  alias StarweaveCore.Distributed.TaskDistributor
  
  @doc """
  Starts the PatternProcessor process.
  
  ## Options
    * `:name` - The name to register the process under (default: `__MODULE__`)
    * `:task_timeout` - Maximum time to wait for task completion (default: 30_000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Processes a pattern across the cluster.
  
  ## Parameters
    * `pattern` - The pattern to process
    * `opts` - Options for processing
      * `:name` - The name of the PatternProcessor process
      * `:timeout` - Maximum time to wait for completion (default: :infinity)
      
  ## Returns
    * `{:ok, result}` if processing completes successfully
    * `{:error, reason}` if processing fails
  """
  @spec process_pattern(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def process_pattern(pattern, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, :infinity)
    GenServer.call(name, {:process_pattern, pattern}, timeout)
  end
  
  # Server Callbacks
  
  defmodule State do
    @moduledoc false
    defstruct [
      tasks: %{},
      results: %{},
      task_timeout: 30_000,
      name: nil
    ]
  end
  
  @impl true
  def init(opts) do
    state = %State{
      task_timeout: Keyword.get(opts, :task_timeout, 30_000),
      name: Keyword.get(opts, :name, __MODULE__)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:process_pattern, pattern}, _from, %State{} = state) do
    # Split the pattern into sub-patterns for distributed processing
    sub_patterns = split_pattern(pattern)
    
    # Process each sub-pattern in parallel
    task_refs = Enum.map(sub_patterns, fn sub_pattern ->
      {:ok, ref} = TaskDistributor.submit_task(
        sub_pattern,
        &process_sub_pattern/1,
        distributed: true,
        return_ref: true
      )
      ref
    end)
    
    # Store task references without monitoring for now
    # We'll monitor them when they're actually started by the TaskDistributor
    task_monitors = Map.new(task_refs, fn ref -> {ref, nil} end)
    
    # Store the task information
    new_state = %{state | 
      tasks: Map.put(state.tasks, :current_job, %{
        pattern: pattern,
        sub_patterns: sub_patterns,
        task_refs: task_refs,
        monitors: task_monitors,
        results: %{},
        completed: 0,
        total: length(sub_patterns)
      })
    }
    
    # Set a timeout for the entire operation
    {:reply, {:ok, :started}, new_state, state.task_timeout}
  end
  
  defp split_pattern(pattern) do
    # TODO: Implement pattern splitting logic based on your domain
    # For now, just return a list with the pattern as is
    [pattern]
  end
  
  defp process_sub_pattern(sub_pattern) do
    # TODO: Implement actual sub-pattern processing
    # This is a placeholder that just returns the sub-pattern
    sub_pattern
  end
  
  @impl true
  def handle_info(msg, state) do
    case msg do
      {:DOWN, ref, :process, _pid, reason} ->
        # Handle task completion/failure
        case find_task_by_monitor(state.tasks, ref) do
          {task_id, task} ->
            handle_task_completion(task_id, task, reason, state)
          nil ->
            Logger.warning("Received DOWN message for unknown task: #{inspect(ref)}")
            {:noreply, state}
        end
        
      :timeout ->
        # Handle timeout for pattern processing
        Logger.warning("Pattern processing timed out")
        
        # Notify the caller if we have a from
        case Map.get(state.tasks, :current_job) do
          %{from: from} when from != nil ->
            GenServer.reply(from, {:error, :timeout})
          _ ->
            :ok
        end
        
        # Clear all tasks
        {:noreply, %{state | tasks: %{}}}
    end
  end
  
  defp find_task_by_monitor(tasks, monitor_ref) do
    Enum.find_value(tasks, fn {task_id, task} ->
      if Map.get(task.monitors, monitor_ref) do
        {task_id, task}
      end
    end)
  end
  
  defp handle_task_completion(task_id, _task, reason, state) do
    Logger.info("Task completed: #{inspect(task_id)} - #{inspect(reason)}")
    
    # Get the current job
    job = Map.get(state.tasks, :current_job)
    if job do
      # Update the task status
      updated_job = %{job | 
        completed: job.completed + 1,
        results: Map.put(job.results, task_id, {:completed, reason})
      }
      
      # Check if all tasks are complete
      if updated_job.completed >= updated_job.total do
        # All tasks complete, aggregate results
        result = aggregate_results(updated_job)
        
        # Reply to the caller if we have a from
        if updated_job.from do
          GenServer.reply(updated_job.from, {:ok, result})
        end
        
        # Clean up
        new_tasks = Map.delete(state.tasks, :current_job)
        {:noreply, %{state | tasks: new_tasks}}
      else
        # Update the job with the new status
        new_tasks = Map.put(state.tasks, :current_job, updated_job)
        {:noreply, %{state | tasks: new_tasks}}
      end
    else
      # No matching job found
      {:noreply, state}
    end
  end
  
  defp aggregate_results(job) do
    # Simple aggregation that just collects all results
    # This can be customized based on your needs
    job.results
    |> Map.values()
    |> Enum.map(fn
      {:completed, result} -> result
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
