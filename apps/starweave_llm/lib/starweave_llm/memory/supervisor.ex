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
    children = [
      {StarweaveCore.Intelligence.WorkingMemory, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
