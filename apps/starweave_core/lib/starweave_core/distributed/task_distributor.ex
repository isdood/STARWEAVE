defmodule StarweaveCore.Distributed.TaskDistributor do
  @moduledoc """
  Handles distribution of pattern processing tasks across the cluster.
  Implements work distribution, result aggregation, and state management.
  """
  use GenServer
  require Logger

  alias __MODULE__.State
  alias StarweaveCore.Distributed.NodeDiscovery

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
      * `:name` - The name of the TaskDistributor process
      * `:timeout` - Maximum time to wait for task completion (default: :infinity)
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
    timeout = Keyword.get(opts, :timeout, :infinity)
    distributed = Keyword.get(opts, :distributed, false)
    return_ref = Keyword.get(opts, :return_ref, false)
    
    if distributed do
      case GenServer.call(name, {:submit_task, input, fun, opts}, timeout) do
        {:ok, ref} when return_ref -> 
          {:ok, ref}
        {:ok, ref} -> 
          # Wait for the task to complete and get the result
          receive do
            {^ref, result} -> result
          after
            timeout -> 
              {:error, :timeout}
          end
        {:error, _} = error -> 
          error
      end
    else
      # Simple synchronous execution (like SimpleDistributor)
      try do
        result = fun.(input)
        if return_ref do
          # For consistency, generate a ref even in non-distributed mode
          {:ok, make_ref()}
        else
          {:ok, result}
        end
      catch
        kind, reason ->
          stacktrace = __STACKTRACE__
          {:error, {kind, reason, stacktrace}}
      end
    end
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
    @moduledoc false
    defstruct [
      tasks: %{},
      nodes: [],
      node_load: %{},
      task_callers: %{},
      task_monitors: %{},
      task_timeout: 30_000,
      name: nil,
      task_supervisor: nil
    ]
  end

  @impl true
  def init(opts) do
    # Get the task supervisor, defaulting to Task.Supervisor
    task_supervisor = Keyword.get(opts, :task_supervisor, Task.Supervisor)
    
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
      nodes: nodes,
      node_load: node_load,
      tasks: %{},
      task_callers: %{},
      task_monitors: %{},
      task_timeout: Keyword.get(opts, :task_timeout, 30_000),
      name: Keyword.get(opts, :name, __MODULE__),
      task_supervisor: task_supervisor
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
  def handle_call({:submit_task, input, fun, _opts}, {from_pid, _ref} = _from, %State{task_supervisor: task_supervisor, tasks: tasks, task_monitors: task_monitors} = state) do
    task_id = System.unique_integer([:positive, :monotonic])
    task_ref = make_ref()
    
    # Start the task under the supervisor
    task = Task.Supervisor.async_nolink(task_supervisor, fn ->
      try do
        # Execute the task function
        result = fun.(input)
        # Send the result back to the caller
        send(from_pid, {task_ref, {:ok, result}})
        result
      catch
        kind, reason ->
          stacktrace = __STACKTRACE__
          error = {kind, reason, stacktrace}
          send(from_pid, {task_ref, {:error, error}})
          :erlang.raise(kind, reason, stacktrace)
      end
    end)
    
    # Store task information
    task_info = %{
      id: task_id,
      ref: task.ref,
      pid: task.pid,
      start_time: System.monotonic_time(),
      caller: from_pid,
      task_ref: task_ref
    }
    
    # Update the state with the new task
    new_tasks = Map.put(tasks, task_id, task_info)
    new_monitors = Map.put(task_monitors, task.ref, task_id)
    
    # Return the task reference to the caller
    {:reply, {:ok, task_ref}, %{state | tasks: new_tasks, task_monitors: new_monitors}}
  end

  @impl true
  def handle_call({:register_worker, worker_node}, _from, %State{nodes: nodes} = state) do
    if worker_node in nodes do
      {:reply, :ok, state}
    else
      new_nodes = [worker_node | nodes]
      Logger.info("Registered worker node: #{inspect(worker_node)}")
      {:reply, :ok, %{state | nodes: new_nodes}}
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
  def handle_info(msg, %State{tasks: tasks} = state) do
    cond do
      # Handle task completion via direct message
      is_tuple(msg) and tuple_size(msg) == 2 and is_reference(elem(msg, 1)) ->
        {task_monitor_ref, result} = msg
        
        # Find the task by monitor ref
        case Enum.find(tasks, fn {_ref, task} -> Map.get(task, :task_monitor_ref) == task_monitor_ref end) do
          {task_ref, task} ->
            # Get the result and update the task status
            {status, reply} = case result do
              {:completed, _res} -> 
                {:completed, {:ok, :completed}}
              {:error, {_kind, _reason, _stack} = error} -> 
                {:failed, {:error, error}}
              _ -> 
                {:completed, {:ok, :completed}}
            end
            
            # Update the task status
            updated_task = %{task | status: status}
            new_tasks = Map.put(tasks, task_ref, updated_task)
            
            # Reply to the caller if we have a from and not using return_ref
            if task.from do
              if task.return_ref do
                GenServer.reply(task.from, {:ok, :completed})
              else
                GenServer.reply(task.from, reply)
              end
            end
            
            # Update the state with the new task status
            new_state = %{state | tasks: new_tasks}
            {:noreply, new_state}
            
          nil ->
            {:noreply, state}
        end
        
      # Handle task completion via DOWN message (from task monitoring)
      is_tuple(msg) and tuple_size(msg) == 5 and elem(msg, 0) == :DOWN ->
        {:DOWN, ref, :process, _pid, reason} = msg
        case find_task_by_monitor_ref(tasks, ref) do
          {task_ref, %{from: from, return_ref: false}} ->
            # Task failed or exited
            new_tasks = Map.put(tasks, task_ref, %{status: :failed})
            GenServer.reply(from, {:error, reason})
            {:noreply, %{state | tasks: new_tasks}}
            
          {task_ref, %{from: _from, return_ref: true}} ->
            # Task failed or exited, but we already replied with the task ref
            new_tasks = Map.put(tasks, task_ref, %{status: :failed})
            {:noreply, %{state | tasks: new_tasks}}
            
          nil ->
            {:noreply, state}
        end
        
      # Handle process exit messages
      is_tuple(msg) and tuple_size(msg) == 3 and elem(msg, 0) == :EXIT ->
        exit_reason = elem(msg, 2)
        # Log non-normal exits
        if exit_reason != :normal do
          Logger.error("Task distributor received exit: #{inspect(exit_reason)}")
        end
        {:noreply, state}
        
      # Handle node discovery events
      is_tuple(msg) and tuple_size(msg) == 3 and elem(msg, 0) == :nodeup ->
        {:nodeup, node, _info} = msg
        Logger.info("Node joined cluster: #{inspect(node)}")
        %{nodes: nodes, node_load: node_load} = state
        new_nodes = [node | Enum.reject(nodes, &(&1 == node))]
        new_load = Map.put_new(node_load, node, 0)
        {:noreply, %{state | nodes: new_nodes, node_load: new_load}}
        
      is_tuple(msg) and tuple_size(msg) == 3 and elem(msg, 0) == :nodedown ->
        {:nodedown, node, _info} = msg
        Logger.warning("Node left cluster: #{inspect(node)}")
        %{nodes: nodes, node_load: node_load} = state
        new_nodes = List.delete(nodes, node)
        new_load = Map.delete(node_load, node)
        {:noreply, %{state | nodes: new_nodes, node_load: new_load}}
        
      # Handle other messages
      true ->
        {:noreply, state}
    end
  end

  # Private functions
  
  # Helper to find a task by its monitor reference
  defp find_task_by_monitor_ref(tasks, monitor_ref) do
    Enum.find(tasks, fn {_task_ref, task} -> Map.get(task, :monitor_ref) == monitor_ref end)
  end
  
  # Node selection will be implemented in a future iteration
  # when we add proper load balancing across nodes
end
