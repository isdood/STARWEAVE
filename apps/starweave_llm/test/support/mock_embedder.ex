defmodule StarweaveLlm.Embeddings.MockEmbedder do
  @moduledoc """
  A simple mock embedder for testing purposes.
  Generates deterministic embeddings based on text content.
  """
  
  @behaviour StarweaveLlm.Embeddings.Behaviour
  
  @doc """
  Generates a simple deterministic embedding for the given text.
  For testing purposes only.
  """
  @impl true
  def embed(text) when is_binary(text) do
    # Generate a simple deterministic embedding based on text length and content
    embedding = 
      text
      |> String.length()
      |> :erlang.phash2()
      |> Kernel.rem(100)  # Keep numbers small for testing
      |> List.duplicate(384)  # Standard BERT embedding size
      |> Enum.map(fn x -> x / 100.0 end)  # Convert to float between 0 and 1
      
    {:ok, embedding}
  end
  
  @doc """
  Generates embeddings for multiple texts.
  """
  @impl true
  def embed(texts) when is_list(texts) do
    embeddings = Enum.map(texts, &(elem(embed(&1), 1)))
    {:ok, embeddings}
  end
  
  @doc """
  Calculates cosine similarity between two embeddings.
  """
  @impl true
  def cosine_similarity(embedding1, embedding2) do
    # Simple implementation for testing
    dot = Enum.sum(Enum.zip_with(embedding1, embedding2, &(&1 * &2)))
    norm1 = :math.sqrt(Enum.sum(Enum.map(embedding1, &(&1 * &1))))
    norm2 = :math.sqrt(Enum.sum(Enum.map(embedding2, &(&1 * &1))))
    
    if norm1 > 0.0 and norm2 > 0.0 do
      max(-1.0, min(1.0, dot / (norm1 * norm2)))
    else
      0.0
    end
  end
end
