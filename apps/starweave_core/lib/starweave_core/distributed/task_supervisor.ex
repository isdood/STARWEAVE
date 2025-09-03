defmodule StarweaveCore.Distributed.TaskSupervisor do
  @moduledoc """
  A supervisor that manages tasks with automatic recovery.
  """
  use Supervisor
  require Logger

  alias StarweaveCore.Distributed.TaskCheckpoint
  alias StarweaveCore.Distributed.TaskRecovery

  @doc """
  Returns a specification to start this module under a supervisor.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: :infinity
    }
  end

  @doc """
  Starts the TaskSupervisor process.
  
  ## Options
    * `:name` - The name to register the process under
    * `:task_supervisor` - The name of the Task.Supervisor to use (default: Task.Supervisor)
    * `:recovery_name` - The name to register the TaskRecovery process under (default: TaskRecovery)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  def init(opts) do
    # Get the task_supervisor from options or generate a unique name
    task_supervisor = Keyword.get(opts, :task_supervisor, Task.Supervisor)
    recovery_name = Keyword.get(opts, :recovery_name, TaskRecovery)
    
    children = [
      {Task.Supervisor, name: task_supervisor},
      {TaskCheckpoint, [name: TaskCheckpoint]},
      {TaskRecovery, [name: recovery_name, task_supervisor: task_supervisor]}
    ]

    # Use one_for_one since we want to manage the task supervisor ourselves
    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Starts a supervised task with automatic recovery.
  
  ## Options
    * `:task_supervisor` - The name of the Task.Supervisor to use (default: Task.Supervisor)
    * `:recovery_name` - The name of the TaskRecovery process (default: TaskRecovery)
    * `:max_attempts` - Maximum number of retry attempts (default: 3)
    * `:backoff` - Initial backoff time in milliseconds (default: 1000)
    * `:max_backoff` - Maximum backoff time in milliseconds (default: 30000)
  """
  @spec start_task((() -> any()), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_task(fun, opts \\ []) when is_function(fun, 0) do
    task_supervisor = Keyword.get(opts, :task_supervisor, Task.Supervisor)
    recovery_name = Keyword.get(opts, :recovery_name, TaskRecovery)
    
    # Ensure the task supervisor is running
    ensure_task_supervisor_started(task_supervisor)
    
    # Ensure the recovery process is running
    ensure_recovery_started(recovery_name, task_supervisor)
    
    # Start the task under the supervisor
    case Task.Supervisor.start_child(task_supervisor, fun) do
      {:ok, pid} ->
        # Monitor the task for recovery if it fails
        :ok = GenServer.call(recovery_name, {:monitor_task, pid, fun, opts})
        {:ok, pid}
        
      error ->
        error
    end
  end
  
  defp ensure_recovery_started(recovery_name, task_supervisor) do
    case Process.whereis(recovery_name) do
      nil ->
        {:ok, _pid} = TaskRecovery.start_link(name: recovery_name, task_supervisor: task_supervisor)
      _ ->
        :ok
    end
  end
  
  defp ensure_task_supervisor_started(name) do
    case Process.whereis(name) do
      nil ->
        {:ok, _} = Task.Supervisor.start_link(name: name)
      _ ->
        :ok
    end
  end
  
  @doc """
  Stops a supervised task.
  """
  @spec stop_task(pid()) :: :ok
  def stop_task(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :shutdown)
    end
    :ok
  end
end
