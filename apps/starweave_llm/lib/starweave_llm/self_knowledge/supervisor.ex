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
    # Define the KnowledgeBase worker
    knowledge_base_spec = {
      KnowledgeBase, [
        name: KnowledgeBase,
        table_name: :starweave_self_knowledge,
        dets_path: Application.app_dir(:starweave_llm, "priv/data/self_knowledge.dets")
      ]
    }
    
    # Define the SelfKnowledge worker with a reference to the KnowledgeBase
    self_knowledge_spec = {
      SelfKnowledge, [
        knowledge_base: KnowledgeBase
      ]
    }
    
    children = [
      knowledge_base_spec,
      self_knowledge_spec
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
