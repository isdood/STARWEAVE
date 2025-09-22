defmodule StarweaveLlm.Embeddings.Supervisor do
  @moduledoc """
  Supervisor for the embedding service components.
  """

  use Supervisor

  alias StarweaveLlm.Embeddings.MockEmbedder  # Use mock embedder for now

  @doc """
  Starts the embedding supervisor.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Use mock embedder for now to avoid Bumblebee issues
      {MockEmbedder, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Generates embeddings for the given texts using the default embedder.
  """
  def embed_texts(texts) when is_list(texts) do
    MockEmbedder.embed(texts)
  end

  @doc """
  Calculates cosine similarity between two embedding vectors.
  """
  def cosine_similarity(vec1, vec2) do
    MockEmbedder.cosine_similarity(vec1, vec2)
  end
end
