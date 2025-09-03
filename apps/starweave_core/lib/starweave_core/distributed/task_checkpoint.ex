defmodule StarweaveCore.Distributed.TaskCheckpoint do
  @moduledoc """
  Handles checkpointing of task state for fault tolerance.
  Persists task state to allow recovery in case of failures.
  """
  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the TaskCheckpoint process.
  
  ## Options
    * `:name` - The name to register the process under
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, [name: name])
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

  @doc """
  Saves a checkpoint for a task.
  """
  @spec checkpoint(pid() | atom(), any(), keyword()) :: :ok
  def checkpoint(server \\ __MODULE__, task_ref, state, opts \\ []) do
    GenServer.cast(server, {:checkpoint, task_ref, state, opts})
  end

  @doc """
  Retrieves the latest checkpoint for a task.
  """
  @spec get_checkpoint(pid() | atom(), any()) :: {:ok, any()} | :not_found
  def get_checkpoint(server \\ __MODULE__, task_ref) do
    GenServer.call(server, {:get_checkpoint, task_ref})
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    {:ok, %{checkpoints: %{}}}
  end

  @impl true
  def handle_cast({:checkpoint, task_ref, state, _opts}, state_data) do
    Logger.debug("Checkpointing task #{inspect(task_ref)}")
    # In a production system, you might want to persist this to disk or a database
    new_checkpoints = Map.put(state_data.checkpoints, task_ref, %{
      state: state,
      timestamp: System.system_time(:millisecond)
    })
    {:noreply, %{state_data | checkpoints: new_checkpoints}}
  end

  @impl true
  def handle_call({:get_checkpoint, task_ref}, _from, state_data) do
    case Map.get(state_data.checkpoints, task_ref) do
      nil -> {:reply, :not_found, state_data}
      checkpoint -> {:reply, {:ok, checkpoint.state}, state_data}
    end
  end

  @impl true
  def handle_call({:delete_checkpoint, task_ref}, _from, state_data) do
    new_checkpoints = Map.delete(state_data.checkpoints, task_ref)
    {:reply, :ok, %{state_data | checkpoints: new_checkpoints}}
  end
end
