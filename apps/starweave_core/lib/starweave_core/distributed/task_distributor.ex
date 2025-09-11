defmodule StarweaveCore.Distributed.TaskDistributor do
  @moduledoc """
  Handles distribution of pattern processing tasks across the cluster.
  Implements work distribution, result aggregation, and state management.

  ## Features
  - Load balancing across worker nodes
  - Task prioritization (low, normal, high)
  - Worker capacity tracking
  - Task result aggregation
  - Monitoring and metrics collection
  """
  use GenServer
  require Logger

  alias __MODULE__.State
  alias StarweaveCore.Distributed.NodeDiscovery

  # Task priority levels
  @priority_high 2
  @priority_normal 1
  @priority_low 0

  # Default task timeout (30 seconds)
  @default_task_timeout 30_000
  
  # Default worker capacity (max concurrent tasks per worker)
  @default_worker_capacity 10
  
  # Metrics update interval (5 seconds)
  @metrics_interval 5_000

  # Client API

  @doc """
  Registers a worker node with the TaskDistributor.
  
  ## Parameters
    * `worker_node` - The node name of the worker to register
    * `opts` - Options
      * `:name` - The name of the TaskDistributor process
  """
  @spec register_worker(node(), keyword()) :: :ok | {:error, term()}
  def register_worker(worker_node, opts \\ []) when is_atom(worker_node) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, {:register_worker, worker_node})
  end

  @doc """
  Starts the TaskDistributor process.
  
  ## Options
    * `:name` - The name to register the process under
    * `:task_supervisor` - The name of the Task.Supervisor to use (default: Task.Supervisor)
    * `:task_timeout` - Default timeout for tasks in milliseconds (default: 30000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Submits a new task for distributed processing.

  ## Parameters
    * `input` - The input to pass to the task function
    * `fun` - A 1-arity function that processes the input
    * `opts` - Options for task execution
      * `:name` - The name of the TaskDistributor process (default: `__MODULE__`)
      * `:timeout` - Maximum time to wait for task completion (ms, default: 30000)
      * `:priority` - Task priority (`:low`, `:normal`, or `:high`, default: `:normal`)
      * `:worker_node` - Specific node to run the task on (optional)
      * `:task_id` - Custom task ID (auto-generated if not provided)
      * `:distributed` - Whether to distribute the task (default: false)
      * `:return_ref` - If true, returns a task reference instead of the result (default: false)
  
  ## Returns
    * When `:return_ref` is false (default):
      * `{:ok, result}` if the task completed successfully
      * `{:error, reason}` if the task failed
    * When `:return_ref` is true:
      * `{:ok, task_ref}` a reference to the task that can be used to check status
  """
  @spec submit_task(term(), (term() -> term()), keyword()) :: 
          {:ok, term()} | {:error, term()} | {:ok, reference()}
  def submit_task(input, fun, opts \\ []) when is_function(fun, 1) do
    name = Keyword.get(opts, :name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, @default_task_timeout)
    priority = priority_to_int(Keyword.get(opts, :priority, :normal))
    worker_node = Keyword.get(opts, :worker_node)
    task_id = Keyword.get_lazy(opts, :task_id, &generate_task_id/0)
    
    task = %{
      id: task_id,
      input: input,
      fun: fun,
      priority: priority,
      submitted_at: System.monotonic_time(),
      status: :queued,
      worker_node: worker_node
    }
    
    GenServer.call(name, {:submit_task, task}, timeout)
  end
  
  defp priority_to_int(:low), do: @priority_low
  defp priority_to_int(:normal), do: @priority_normal
  defp priority_to_int(:high), do: @priority_high
  defp priority_to_int(level) when is_integer(level), do: level
  defp priority_to_int(_), do: @priority_normal
  
  defp generate_task_id do
    :crypto.strong_rand_bytes(8) 
    |> Base.encode16(case: :lower)
  end

  @doc """
  Gets the status of a task by its reference.
  """
  @spec task_status(reference() | integer(), keyword()) :: {:ok, :pending | {:completed, term()} | :failed} | {:error, :not_found}
  def task_status(task_ref, opts \\ []) when is_reference(task_ref) or is_integer(task_ref) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, {:task_status, task_ref})
  end

  # Server Callbacks

  defmodule State do
    @moduledoc """
    Internal state of the TaskDistributor.
    
    ## Fields
    - `:task_supervisor` - The Task.Supervisor module to use
    - `:workers` - Map of worker nodes to their state
    - `:tasks` - Map of task_id to task state
    - `:pending_tasks` - Priority queue of pending tasks
    - `:metrics` - Metrics about task processing
    - `:metrics_timer` - Reference to the metrics update timer
    """
    
    @type t :: %__MODULE__{
      task_supervisor: module(),
      workers: %{required(node()) => worker_state()},
      tasks: %{required(String.t()) => task_state()},
      pending_tasks: :gb_trees.tree(),
      metrics: metrics(),
      metrics_timer: reference() | nil
    }
    
    @type worker_state :: %{
      capacity: pos_integer(),
      current_load: non_neg_integer(),
      last_heartbeat: integer(),
      status: :available | :busy | :down
    }
    
    @type task_state :: %{
      id: String.t(),
      input: any(),
      fun: (any() -> any()),
      priority: integer(),
      status: :queued | :running | :completed | :failed,
      submitted_at: integer(),
      started_at: integer() | nil,
      completed_at: integer() | nil,
      result: {:ok, any()} | {:error, any()} | nil,
      worker_node: node() | nil,
      retries: non_neg_integer(),
      max_retries: non_neg_integer()
    }
    
    @type metrics :: %{
      tasks_completed: non_neg_integer(),
      tasks_failed: non_neg_integer(),
      tasks_running: non_neg_integer(),
      tasks_queued: non_neg_integer(),
      avg_task_time: float(),
      worker_count: non_neg_integer(),
      last_updated: integer()
    }
    
    defstruct [
      :task_supervisor,
      :metrics_timer,
      workers: %{},
      tasks: %{},
      pending_tasks: :gb_trees.empty(),
      metrics: %{
        tasks_completed: 0,
        tasks_failed: 0,
        tasks_running: 0,
        tasks_queued: 0,
        avg_task_time: 0.0,
        worker_count: 0,
        last_updated: 0
      }
    ]
  end

  @impl true
  def init(opts) do
    # Get the task supervisor, defaulting to Task.Supervisor
    task_supervisor = Keyword.get(opts, :task_supervisor, Task.Supervisor)
    task_timeout = Keyword.get(opts, :task_timeout, @default_task_timeout)
    
    # Start metrics collection
    metrics_timer = schedule_metrics_update()
    
    # Ensure Task.Supervisor is running
    case Process.whereis(task_supervisor) do
      nil ->
        case Task.Supervisor.start_link(name: task_supervisor) do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
          error -> 
            Logger.error("Failed to start Task.Supervisor: #{inspect(error)}")
            raise "Failed to start Task.Supervisor"
        end
      _ -> :ok
    end
    
    # Initialize node list and load
    nodes = [node() | Node.list()]
    node_load = Enum.into(nodes, %{}, &{&1, 0})
    
    # Initialize tasks and other state
    state = %State{
      task_supervisor: task_supervisor,
      metrics_timer: metrics_timer,
      workers: %{},
      tasks: %{},
      pending_tasks: :gb_trees.empty(),
      metrics: %{
        tasks_completed: 0,
        tasks_failed: 0,
        tasks_running: 0,
        tasks_queued: 0,
        avg_task_time: 0.0,
        worker_count: 0,
        last_updated: 0
      }
    }
    
    # Subscribe to node discovery events if available
    if Code.ensure_loaded?(NodeDiscovery) do
      if function_exported?(NodeDiscovery, :subscribe, 1) do
        NodeDiscovery.subscribe(self())
      else
        Logger.warning("NodeDiscovery.subscribe/1 not available, using local node only")
      end
    else
      Logger.warning("NodeDiscovery module not available, using local node only")
    end
    
    {:ok, state}
  end

  @impl true
  def handle_call({:submit_task, task}, _from, state) do
    %{id: task_id} = task
    
    # Add the task to our state
    task_state = %{
      id: task_id,
      input: task.input,
      fun: task.fun,
      priority: task.priority,
      status: :queued,
      submitted_at: task.submitted_at,
      started_at: nil,
      completed_at: nil,
      result: nil,
      worker_node: nil,
      retries: 0,
      max_retries: 3
    }
    
    # Update state with new task
    updated_tasks = Map.put(state.tasks, task_id, task_state)
    
    # Add to priority queue
    priority = {task.priority, -task.submitted_at, task_id}  # Negative for min-heap behavior
    updated_pending = :gb_trees.insert(priority, task_id, state.pending_tasks)
    
    # Update metrics
    updated_metrics = %{state.metrics | 
      tasks_queued: state.metrics.tasks_queued + 1
    }
    
    state = %{state | 
      tasks: updated_tasks,
      pending_tasks: updated_pending,
      metrics: updated_metrics
    }
    
    # Try to process the task immediately if we have capacity
    state = process_pending_tasks(state)
    
    {:reply, {:ok, task_id}, state}
  end
  
  # Process pending tasks if we have available workers
  defp process_pending_tasks(state) do
    case :gb_trees.is_empty(state.pending_tasks) do
      true -> 
        state  # No pending tasks
        
      false ->
        # Find an available worker with capacity
        case find_available_worker(state.workers) do
          {:ok, worker_node} ->
            # Get the highest priority task
            case :gb_trees.take_smallest(state.pending_tasks) do
              {{_priority, _ts, task_id} = key, task_id, updated_pending} ->
                # Get the task state
                task_state = Map.get(state.tasks, task_id)
            
            # Start the task on the worker
            case start_task_on_worker(task_state, worker_node, state) do
              {:ok, updated_task_state, worker_node} ->
                # Update task state
                updated_tasks = Map.put(state.tasks, task_id, %{
                  updated_task_state | 
                  status: :running,
                  started_at: System.monotonic_time(),
                  worker_node: worker_node
                })
                
                # Update worker load
                updated_workers = update_worker_load(state.workers, worker_node, 1)
                
                # Update metrics
                updated_metrics = %{state.metrics | 
                  tasks_queued: max(0, state.metrics.tasks_queued - 1),
                  tasks_running: state.metrics.tasks_running + 1
                }
                
                %{state | 
                  tasks: updated_tasks,
                  workers: updated_workers,
                  pending_tasks: updated_pending,
                  metrics: updated_metrics
                }
                
              {:error, reason} ->
                Logger.error("Failed to start task #{task_id} on worker #{inspect(worker_node)}: #{inspect(reason)}")
                state
            end
            
          :no_workers_available ->
            state  # No workers available, keep tasks queued
        end
    end
  end
  
  # Find an available worker with capacity
  defp find_available_worker(workers) do
    workers
    |> Enum.filter(fn {_node, %{status: status, current_load: load, capacity: capacity}} ->
      status == :available and load < capacity
    end)
    |> case do
      [] -> 
        :no_workers_available
        
      available_workers ->
        # Select the worker with the least load (simple load balancing)
        {worker_node, _} = Enum.min_by(available_workers, fn {_node, %{current_load: load}} -> load end)
        {:ok, worker_node}
    end
  end
  
  # Start a task on a worker node
  defp start_task_on_worker(task, worker_node, state) do
    %{task_supervisor: task_supervisor} = state
    
    try do
      # Start the task on the worker node
      task = Task.Supervisor.async_nolink(
        {task_supervisor, worker_node},
        fn ->
          # Execute the function with the input
          try do
            {:ok, task.fun.(task.input)}
          rescue
            e -> 
              {:error, Exception.format(:error, e, __STACKTRACE__)}
          end
        end
      )
      
      # Monitor the task
      Process.monitor(task.ref)
      
      # Update task state with monitor reference
      updated_task = %{
        task | 
        monitor_ref: Process.monitor(task.ref),
        task_ref: task.ref
      }
      
      {:ok, updated_task, worker_node}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}
    end
  end

  @impl true
  def handle_call({:register_worker, worker_node}, _from, %State{workers: workers} = state) do
    if Map.has_key?(workers, worker_node) do
      {:reply, {:error, :already_registered}, state}
    else
      Logger.info("Registering worker node: #{inspect(worker_node)}")
      
      worker_state = %{
        capacity: @default_worker_capacity,
        current_load: 0,
        last_heartbeat: System.system_time(:second),
        status: :available
      }
      
      updated_workers = Map.put(workers, worker_node, worker_state)
      updated_metrics = update_worker_count(updated_workers, state.metrics)
      
      state = %{state | 
        workers: updated_workers,
        metrics: updated_metrics
      }
      
      # Process any pending tasks now that we have a new worker
      state = process_pending_tasks(state)
      
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:task_status, task_ref}, _from, %State{tasks: tasks} = state) do
    case Map.get(tasks, task_ref) do
      nil -> 
        {:reply, {:error, :not_found}, state}
      %{status: :completed} -> 
        {:reply, {:ok, :completed}, state}
      %{status: :pending} -> 
        {:reply, {:ok, :pending}, state}
      %{status: :failed} -> 
        {:reply, {:ok, :failed}, state}
      %{status: {:completed, _result}} -> 
        {:reply, {:ok, :completed}, state}
      %{status: :done} -> 
        {:reply, {:ok, :completed}, state}
      _ -> 
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  @impl true
  def handle_info(msg, state) do
    case msg do
      # Handle task completion
      {ref, result} when is_reference(ref) ->
        handle_task_result(ref, result, state)
        
      # Handle DOWN message from task monitor
      {:DOWN, ref, :process, _pid, reason} ->
        handle_task_down(ref, reason, state)
        
      # Periodic metrics update
      :update_metrics ->
        handle_metrics_update(state)
        
      # Handle worker heartbeat
      {:worker_heartbeat, worker_node} ->
        handle_worker_heartbeat(worker_node, state)
        
      # Unhandled messages
      other ->
        Logger.warning("Received unhandled message: #{inspect(other)}")
        {:noreply, state}
    end
  end
  
  # Handle successful task completion
  defp handle_task_result(ref, result, state) do
    case find_task_by_ref(ref, state.tasks) do
      {task_id, task} ->
        # Update task state
        completed_at = System.monotonic_time()
        execution_time = completed_at - task.started_at
        
        updated_tasks = Map.put(state.tasks, task_id, %{
          task | 
          status: :completed,
          completed_at: completed_at,
          result: result
        })
        
        # Update worker load
        updated_workers = update_worker_load(state.workers, task.worker_node, -1)
        
        # Update metrics
        updated_metrics = update_task_metrics(
          state.metrics, 
          :completed, 
          execution_time
        )
        
        # Process next task if any
        state = %{state | 
          tasks: updated_tasks,
          workers: updated_workers,
          metrics: updated_metrics
        }
        
        state = process_pending_tasks(state)
        {:noreply, state}
        
      nil ->
        Logger.warning("Received result for unknown task ref: #{inspect(ref)}")
        {:noreply, state}
    end
  end
  
  # Handle task failure
  defp handle_task_down(ref, reason, state) do
    case find_task_by_ref(ref, state.tasks) do
      {task_id, task} ->
        Logger.error("Task #{task_id} failed: #{inspect(reason)}")
        
        if task.retries < task.max_retries do
          # Retry the task
          Logger.info("Retrying task #{task_id} (attempt #{task.retries + 1}/#{task.max_retries})")
          
          # Update task state
          updated_task = %{
            task | 
            status: :queued,
            retries: task.retries + 1,
            monitor_ref: nil,
            task_ref: nil
          }
          
          # Add back to pending queue with higher priority
          priority = {task.priority + 1, -System.monotonic_time(), task_id}
          updated_pending = :gb_trees.insert(priority, task_id, state.pending_tasks)
          
          # Update task in state
          updated_tasks = Map.put(state.tasks, task_id, updated_task)
          
          # Update worker load
          updated_workers = update_worker_load(state.workers, task.worker_node, -1)
          
          # Update metrics
          updated_metrics = %{state.metrics | 
            tasks_running: max(0, state.metrics.tasks_running - 1),
            tasks_queued: state.metrics.tasks_queued + 1
          }
          
          state = %{state | 
            tasks: updated_tasks,
            workers: updated_workers,
            pending_tasks: updated_pending,
            metrics: updated_metrics
          }
          
          # Try to process the next task
          state = process_pending_tasks(state)
          {:noreply, state}
          
        else
          # Max retries reached, mark as failed
          completed_at = System.monotonic_time()
          execution_time = if task.started_at, do: completed_at - task.started_at, else: 0
          
          updated_tasks = Map.put(state.tasks, task_id, %{
            task | 
            status: :failed,
            completed_at: completed_at,
            result: {:error, reason}
          })
          
          # Update worker load
          updated_workers = update_worker_load(state.workers, task.worker_node, -1)
          
          # Update metrics
          updated_metrics = update_task_metrics(
            state.metrics, 
            :failed, 
            execution_time
          )
          
          state = %{state | 
            tasks: updated_tasks,
            workers: updated_workers,
            metrics: updated_metrics
          }
          
          # Process next task if any
          state = process_pending_tasks(state)
          {:noreply, state}
        end
        
      nil ->
        # Not a task we're tracking
        {:noreply, state}
    end
  end
  
  # Handle worker heartbeat
  defp handle_worker_heartbeat(worker_node, state) do
    if Map.has_key?(state.workers, worker_node) do
      # Update last heartbeat time
      updated_workers = Map.update!(state.workers, worker_node, fn worker ->
        %{worker | last_heartbeat: System.system_time(:second)}
      end)
      
      {:noreply, %{state | workers: updated_workers}}
    else
      # Worker not registered, ignore
      {:noreply, state}
    end
  end
  
  # Handle metrics update
  defp handle_metrics_update(state) do
    # Schedule next update
    timer_ref = schedule_metrics_update()
    
    # Calculate worker availability
    available_workers = 
      state.workers
      |> Map.values()
      |> Enum.count(fn %{status: status} -> status == :available end)
    
    # Update metrics
    updated_metrics = %{state.metrics | 
      worker_count: map_size(state.workers),
      available_workers: available_workers,
      last_updated: System.system_time(:second)
    }
    
    # Log metrics periodically
    Logger.debug("""
    System Metrics:
      Workers: #{updated_metrics.worker_count} total, #{updated_metrics.available_workers} available
      Tasks: #{updated_metrics.tasks_running} running, #{updated_metrics.tasks_queued} queued
      Completed: #{updated_metrics.tasks_completed} (avg: #{:erlang.float_to_binary(updated_metrics.avg_task_time / 1_000_000, [decimals: 2])}s)
      Failed: #{updated_metrics.tasks_failed}
    """)
    
    {:noreply, %{state | metrics: updated_metrics, metrics_timer: timer_ref}}
  end
  
  # Schedule the next metrics update
  defp schedule_metrics_update do
    Process.send_after(self(), :update_metrics, @metrics_interval)
  end
  
  # Find a task by its monitor reference
  defp find_task_by_ref(ref, tasks) do
    Enum.find_value(tasks, fn {task_id, task} -> 
      if Map.get(task, :monitor_ref) == ref, do: {task_id, task} 
    end)
  end
  
  # Update worker load
  defp update_worker_load(workers, worker_node, delta) do
    Map.update!(workers, worker_node, fn worker ->
      new_load = max(0, worker.current_load + delta)
      status = if new_load >= worker.capacity, do: :busy, else: :available
      %{worker | 
        current_load: new_load,
        status: status
      }
    end)
  end
  
  # Update task metrics
  defp update_task_metrics(metrics, :completed, execution_time) do
    # Update average task time using exponential moving average
    alpha = 0.1
    new_avg = if metrics.tasks_completed > 0 do
      (1 - alpha) * metrics.avg_task_time + alpha * execution_time
    else
      execution_time
    end
    
    %{metrics |
      tasks_completed: metrics.tasks_completed + 1,
      tasks_running: max(0, metrics.tasks_running - 1),
      avg_task_time: new_avg
    }
  end
  
  defp update_task_metrics(metrics, :failed, _execution_time) do
    %{metrics |
      tasks_failed: metrics.tasks_failed + 1,
      tasks_running: max(0, metrics.tasks_running - 1)
    }
  end
  
  # Update worker count in metrics
  defp update_worker_count(workers, metrics) do
    %{metrics | worker_count: map_size(workers)}
  end
  
  # Helper to find a task by its monitor reference
  defp find_task_by_monitor_ref(tasks, monitor_ref) do
    Enum.find(tasks, fn {_task_ref, task} -> Map.get(task, :monitor_ref) == monitor_ref end)
  end
  
  # Node selection will be implemented in a future iteration
  # when we add proper load balancing across nodes
end
