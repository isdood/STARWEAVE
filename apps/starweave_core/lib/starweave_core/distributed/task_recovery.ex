defmodule StarweaveCore.Distributed.TaskRecovery do
  @moduledoc """
  Handles recovery of failed tasks with exponential backoff.
  """
  
  use GenServer
  require Logger
  
  @doc """
  Starts a new TaskRecovery process.
  
  ## Options
    * `:name` - The name to register the process under (required)
    * `:task_supervisor` - The name of the Task.Supervisor to use (default: Task.Supervisor)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Returns a specification to start this module under a supervisor.
  """
  @spec child_spec(keyword()) :: map()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
  
  # Client API

  @doc """
  Starts monitoring a task for failures and handles recovery.
  """
  @spec monitor_task(pid() | atom(), (() -> any()), keyword()) :: :ok
  def monitor_task(pid, task_fun, opts \\ []) when is_function(task_fun, 0) do
    GenServer.call(__MODULE__, {:monitor_task, pid, task_fun, opts})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    task_supervisor = Keyword.get(opts, :task_supervisor, Task.Supervisor)
    
    # Initialize and return state as a tuple with :ok
    {:ok, %{
      task_supervisor: task_supervisor,
      monitored_tasks: %{},
      max_attempts: Keyword.get(opts, :max_attempts, 3),
      initial_backoff: Keyword.get(opts, :initial_backoff, 1_000),
      max_backoff: Keyword.get(opts, :max_backoff, 30_000)
    }}
  end

  @impl true
  def handle_call({:monitor_task, pid, task_fun, opts}, _from, state) do
    ref = if is_pid(pid), do: Process.monitor(pid), else: nil
    
    task_info = %{
      pid: pid,
      task_fun: task_fun,
      attempt: 1,
      max_attempts: Keyword.get(opts, :max_attempts, state.max_attempts),
      backoff: Keyword.get(opts, :initial_backoff, state.initial_backoff),
      max_backoff: Keyword.get(opts, :max_backoff, state.max_backoff),
      opts: opts
    }
    
    new_tasks = Map.put(state.monitored_tasks, ref, task_info)
    {:reply, :ok, %{state | monitored_tasks: new_tasks}}
  end
  
  # Handle task start requests from Task.Supervisor
  @impl true
  def handle_call({:start_task, task_spec, _from_pid, _extra}, _from, state) do
    case task_spec do
      [mfa: {mod, fun, args}] ->
        # Start the task using the provided MFA
        case Task.start_link(fn -> apply(mod, fun, args) end) do
          {:ok, pid} -> 
            # Monitor the new task
            ref = Process.monitor(pid)
            task_info = %{
              pid: pid,
              task_fun: fn -> apply(mod, fun, args) end,
              attempt: 1,
              max_attempts: state.max_attempts,
              backoff: state.initial_backoff,
              max_backoff: state.max_backoff,
              opts: []
            }
            new_tasks = Map.put(state.monitored_tasks, ref, task_info)
            {:reply, {:ok, pid}, %{state | monitored_tasks: new_tasks}}
            
          error ->
            {:reply, error, state}
        end
        
      _ ->
        # For other task specs, just pass them through
        {:reply, {:error, :unsupported_task_spec}, state}
    end
  end

  @impl true
  def handle_cast({:monitor, ref, task_info}, state) do
    new_tasks = Map.put(state.monitored_tasks, ref, task_info)
    {:noreply, %{state | monitored_tasks: new_tasks}}
  end

  # Helper functions
  
  defp find_task_by_pid(tasks, pid) do
    Enum.find_value(tasks, fn {ref, %{pid: task_pid} = task_info} ->
      if task_pid == pid, do: {ref, task_info}
    end)
  end
  
  defp handle_task_failure(
    ref,
    %{attempt: attempt, max_attempts: max_attempts} = task_info,
    reason,
    %{monitored_tasks: tasks} = state
  ) when attempt >= max_attempts do
    Logger.error("Task failed after #{max_attempts} attempts. Reason: #{inspect(reason)}")
    Logger.error("Max attempts reached for task: #{inspect(task_info)}")
    {:noreply, %{state | monitored_tasks: Map.delete(tasks, ref)}}
  end
  
  defp handle_task_failure(ref, task_info, reason, %{monitored_tasks: tasks} = state) do
    Logger.debug("Task failed, scheduling retry (attempt #{task_info.attempt + 1}): #{inspect(reason)}")
    
    # Schedule task for retry with exponential backoff
    backoff = min(task_info.backoff * 2, task_info.max_backoff)
    Process.send_after(self(), {:retry_task, ref, task_info}, backoff)
    
    updated_task = %{
      task_info | 
      attempt: task_info.attempt + 1,
      backoff: backoff
    }
    
    {:noreply, %{state | monitored_tasks: Map.put(tasks, ref, updated_task)}}
  end
  
  @impl true
  def handle_info({:EXIT, pid, reason}, %{monitored_tasks: tasks} = state) do
    # Handle EXIT signal from a monitored process
    case find_task_by_pid(tasks, pid) do
      {ref, task_info} ->
        handle_task_failure(ref, task_info, reason, state)
      nil ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{monitored_tasks: tasks} = state) do
    case Map.get(tasks, ref) do
      nil ->
        {:noreply, state}
      task_info ->
        handle_task_failure(ref, task_info, reason, state)
    end
  end

  @impl true
  def handle_info({:retry_task, ref, _task_info}, %{monitored_tasks: tasks} = state) do
    case Map.get(tasks, ref) do
      nil ->
        {:noreply, state}
        
      %{task_fun: task_fun, attempt: attempt} ->
        Logger.info("Retrying task (attempt #{attempt})")
        
        # Start a new task with the same function
        case Task.start_link(task_fun) do
          {:ok, new_pid} ->
            # Update monitoring for the new PID
            Process.demonitor(ref)
            new_ref = Process.monitor(new_pid)
            
            # Update task info with new PID and reference
            updated_task = %{Map.get(tasks, ref) | pid: new_pid}
            
            # Replace the old reference with the new one
            new_tasks = tasks
              |> Map.delete(ref)
              |> Map.put(new_ref, updated_task)
            
            {:noreply, %{state | monitored_tasks: new_tasks}}
            
          {:error, reason} ->
            Logger.error("Failed to restart task: #{inspect(reason)}")
            {:noreply, %{state | monitored_tasks: Map.delete(tasks, ref)}}
        end
    end
  end

  @impl true
  def terminate(_reason, _state) do
    # Clean up any remaining monitored tasks
    :ok
  end
end
