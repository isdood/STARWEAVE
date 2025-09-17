defmodule StarweaveLlm.MockBertEmbedder do
  @moduledoc """
  Mock implementation of the BertEmbedder for testing purposes.
  """
  
  @behaviour StarweaveLlm.Embeddings.Behaviour
  
  @impl true
  def embed(server \\ __MODULE__, texts) when is_list(texts) do
    # For testing, return a simple embedding based on the input text
    embeddings = Enum.map(texts, fn text ->
      # Generate a simple deterministic embedding based on the text
      # This is just for testing purposes
      embedding = 
        text
        |> String.to_charlist()
        |> Enum.take(5)
        |> Enum.map(fn char -> char / 1000 end)
        
      # Ensure we have at least 5 dimensions
      case length(embedding) do
        0 -> [0.1, 0.2, 0.3, 0.4, 0.5]
        1 -> embedding ++ [0.2, 0.3, 0.4, 0.5]
        2 -> embedding ++ [0.3, 0.4, 0.5]
        3 -> embedding ++ [0.4, 0.5]
        4 -> embedding ++ [0.5]
        _ -> Enum.take(embedding, 5)
      end
    end)
    
    {:ok, List.first(embeddings)}
  end
  
  @impl true
  def embed(server \\ __MODULE__, text) when is_binary(text) do
    embed(server, [text])
  end
end
