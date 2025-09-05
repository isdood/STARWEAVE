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
    children = [
      # Core components
      {StarweaveCore.Intelligence.WorkingMemory, []},
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
