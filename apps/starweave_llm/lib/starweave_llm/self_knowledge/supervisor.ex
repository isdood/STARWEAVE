defmodule StarweaveLLM.SelfKnowledge.Supervisor do
  @moduledoc """
  Supervisor for the Self-Knowledge system components.
  """
  
  use Supervisor
  
  alias StarweaveLLM.SelfKnowledge
  alias StarweaveLLM.SelfKnowledge.KnowledgeBase
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end
  
  @impl true
  def init(:ok) do
    # Ensure the registry is started
    Registry.start_link(keys: :duplicate, name: KnowledgeBase.Registry)
    
    children = [
      # KnowledgeBase worker
      {KnowledgeBase, [
        name: KnowledgeBase,
        table_name: :starweave_self_knowledge,
        dets_path: Application.app_dir(:starweave_llm, "priv/data/self_knowledge.dets")
      ]},
      
      # SelfKnowledge worker
      {SelfKnowledge, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
