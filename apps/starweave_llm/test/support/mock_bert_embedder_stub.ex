defmodule StarweaveLlm.MockBertEmbedderStub do
  @moduledoc """
  Stub implementation of the MockBertEmbedder for testing purposes.
  This is used with Mox to provide default implementations of the callbacks.
  """
  
  @behaviour StarweaveLlm.Embeddings.Behaviour
  
  @impl true
  def embed(_server, text) when is_binary(text) do
    # Generate a simple deterministic embedding based on the text
    embedding = 
      text
      |> String.to_charlist()
      |> Enum.take(5)
      |> Enum.map(fn char -> char / 1000 end)
    
    # Ensure we have at least 5 dimensions
    embedding = List.duplicate(0.1, max(0, 5 - length(embedding))) ++ embedding
    {:ok, Enum.take(embedding, 5)}
  end
  
  @impl true
  def embed(_server, texts) when is_list(texts) do
    # For lists, generate an embedding for each text
    embeddings = Enum.map(texts, &(elem(embed(nil, &1), 1)))
    {:ok, embeddings}
  end
end
