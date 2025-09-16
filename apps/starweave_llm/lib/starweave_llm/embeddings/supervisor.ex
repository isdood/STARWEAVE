defmodule StarweaveLlm.Embeddings.Supervisor do
  @moduledoc """
  Supervisor for the embedding service components.
  """
  
  use Supervisor
  
  alias StarweaveLlm.Embeddings.BertEmbedder
  
  @doc """
  Starts the embedding supervisor.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      # BERT embedder worker
      {BertEmbedder, [
        name: BertEmbedder,
        model: "sentence-transformers/all-MiniLM-L6-v2",
        batch_size: 8
      ]}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Generates embeddings for the given texts using the default embedder.
  """
  def embed_texts(texts) when is_list(texts) do
    case Process.whereis(BertEmbedder) do
      nil -> 
        {:error, :embedder_not_started}
      pid ->
        BertEmbedder.embed(pid, texts)
    end
  end
  
  @doc """
  Calculates cosine similarity between two embedding vectors.
  """
  def cosine_similarity(vec1, vec2) do
    BertEmbedder.cosine_similarity(vec1, vec2)
  end
end
