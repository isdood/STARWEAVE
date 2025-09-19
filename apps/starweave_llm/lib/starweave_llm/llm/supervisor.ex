defmodule StarweaveLlm.LLM.Supervisor do
  @moduledoc """
  Supervisor for LLM-related processes.
  """
  use Supervisor

  alias StarweaveLlm.Embeddings.BertEmbedder
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  alias StarweaveLlm.LLM.OllamaClient

  @doc """
  Starts the LLM supervisor.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    # Get the application's data directory
    data_dir = Application.app_dir(:starweave_llm, "priv/data")
    File.mkdir_p!(data_dir)
    
    # Start the knowledge base process with required options
    knowledge_base_opts = [
      name: :knowledge_base,
      table_name: :knowledge_base,
      dets_path: Path.join(data_dir, "knowledge_base.dets")
    ]
    
    # Start the knowledge base
    {:ok, knowledge_base} = KnowledgeBase.start_link(knowledge_base_opts)
    
    # Start the Ollama client
    children = [
      {StarweaveLlm.LLM.QueryService, 
       [
         knowledge_base: knowledge_base,
         embedder: BertEmbedder,
         llm_client: OllamaClient,
         name: :llm_query_service
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
