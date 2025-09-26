defmodule StarweaveCore.Autonomous.Supervisor do
  @moduledoc """
  Supervisor for autonomous system components.
  """
  
  use Supervisor
  
  @doc """
  Starts the autonomous supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # System Integrator coordinates all autonomous activities
      {StarweaveCore.Autonomous.SystemIntegrator, []},
      
      # Other autonomous components can be added here
      # {StarweaveCore.Autonomous.LearningOrchestrator, []},
      # {StarweaveCore.Autonomous.WebKnowledgeAcquirer, []},
      # {StarweaveCore.Autonomous.SelfModificationAgent, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
