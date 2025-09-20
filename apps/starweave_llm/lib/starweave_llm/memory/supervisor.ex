defmodule StarweaveLlm.Memory.Supervisor do
  @moduledoc """
  Supervisor for memory-related processes.
  """
  
  use Supervisor
  
  @doc """
  Starts the memory supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    # WorkingMemory is already started by starweave_core
    # No need to start it again here
    Supervisor.init([], strategy: :one_for_one)
  end
end
