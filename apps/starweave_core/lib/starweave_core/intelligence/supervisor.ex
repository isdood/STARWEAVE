defmodule StarweaveCore.Intelligence.Supervisor do
  @moduledoc """
  Supervisor for the intelligence layer components.
  """
  
  use Supervisor
  
  @doc """
  Starts the intelligence supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    # Determine which memory implementation to use based on configuration
    use_distributed = Application.get_env(:starweave_core, :use_distributed_memory, false)
    
    memory_children = if use_distributed do
      # Start distributed working memory
      [
        {StarweaveCore.Intelligence.DistributedWorkingMemory, []}
      ]
    else
      # Start local working memory
      [
        {StarweaveCore.Intelligence.WorkingMemory, []}
      ]
    end
    
    children = memory_children ++ [
      # Core components
      {StarweaveCore.Intelligence.GoalManager, []},
      {StarweaveCore.Intelligence.ReasoningEngine, []},
      
      # Learning components
      {StarweaveCore.Intelligence.ReinforcementLearning, []},
      {StarweaveCore.Intelligence.PatternLearner, []},
      {StarweaveCore.Intelligence.FeedbackMechanism, []},
      
      # Future components will be added here
      # {StarweaveCore.Intelligence.Attention, []},
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
