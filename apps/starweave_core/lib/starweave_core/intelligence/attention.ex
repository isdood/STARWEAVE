defmodule StarweaveCore.Intelligence.Attention do
  @moduledoc """
  Attention mechanisms for the STARWEAVE system.
  
  This module implements various attention mechanisms to help the system
  focus on the most relevant information from its working memory and
  external inputs.
  """
  
  alias StarweaveCore.Intelligence.WorkingMemory
  
  @type attention_score :: float()
  @type attention_weights :: %{required(any()) => attention_score()}
  
  @doc """
  Calculates attention scores for a set of items based on their relevance to a query.
  
  ## Parameters
    - `query`: The current focus or query
    - `items`: A list of items to score
    - `opts`: Additional options
      - `:similarity_fn`: The similarity function to use (default: &cosine_similarity/2)
      
  Returns a map of items to their attention scores.
  """
  @spec calculate_attention(
    query :: String.t() | [float()],
    items :: [{key :: any(), vector :: [float()]}],
    opts :: keyword()
  ) :: attention_weights()
  def calculate_attention(query, items, opts \\ []) when is_list(items) do
    similarity_fn = Keyword.get(opts, :similarity_fn, &cosine_similarity/2)
    
    items
    |> Enum.map(fn {key, vector} ->
      score = similarity_fn.(query, vector)
      {key, score}
    end)
    |> Enum.into(%{})
    |> normalize_weights()
  end
  
  @doc """
  Applies softmax to attention scores to get probability distribution.
  """
  @spec softmax(attention_weights()) :: attention_weights()
  def softmax(weights) when map_size(weights) == 0, do: %{}
  
  def softmax(weights) do
    # For numerical stability
    max_score = weights |> Map.values() |> Enum.max()
    
    exp_scores = 
      weights
      |> Enum.map(fn {k, v} -> {k, :math.exp(v - max_score)} end)
      |> Map.new()
    
    sum_exp = exp_scores |> Map.values() |> Enum.sum()
    
    exp_scores
    |> Enum.map(fn {k, v} -> {k, v / sum_exp} end)
    |> Map.new()
  end
  
  @doc """
  Normalizes attention weights to sum to 1.0.
  """
  @spec normalize_weights(attention_weights()) :: attention_weights()
  def normalize_weights(weights) when map_size(weights) == 0, do: %{}
  
  def normalize_weights(weights) do
    sum = weights |> Map.values() |> Enum.sum()
    
    if sum > 0 do
      weights
      |> Enum.map(fn {k, v} -> {k, v / sum} end)
      |> Map.new()
    else
      # If all weights are zero, distribute evenly
      count = map_size(weights)
      weights
      |> Map.keys()
      |> Enum.map(fn k -> {k, 1.0 / count} end)
      |> Map.new()
    end
  end
  
  @doc """
  Calculates cosine similarity between two vectors or strings.
  
  If strings are provided, they are converted to TF-IDF vectors first.
  """
  @spec cosine_similarity(a :: any(), b :: any()) :: float()
  def cosine_similarity(a, b) when is_binary(a) and is_binary(b) do
    # Simple word-based cosine similarity for text
    a_terms = String.split(a) |> MapSet.new()
    b_terms = String.split(b) |> MapSet.new()
    
    intersection_size = MapSet.intersection(a_terms, b_terms) |> MapSet.size()
    union_size = MapSet.union(a_terms, b_terms) |> MapSet.size()
    
    if union_size > 0 do
      intersection_size / :math.sqrt(union_size)
    else
      0.0
    end
  end
  
  def cosine_similarity(a, b) when is_list(a) and is_list(b) and length(a) == length(b) do
    dot_product = dot(a, b)
    norm_a = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    norm_b = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))
    
    if norm_a > 0.0 and norm_b > 0.0 do
      dot_product / (norm_a * norm_b)
    else
      0.0
    end
  end
  
  @doc """
  Applies self-attention to a sequence of items.
  
  Returns a list of context vectors, one for each position in the sequence.
  """
  @spec self_attention(
    items :: [{key :: any(), vector :: [float()]}],
    opts :: keyword()
  ) :: [{key :: any(), context_vector :: [float()]}]
  def self_attention(items, _opts \\ []) do
    # This is a simplified version of self-attention
    # In a real implementation, you'd have learnable weights
    
    # For each item, calculate attention weights with all other items
    items_with_attention = 
      Enum.map(items, fn {key, vector} ->
        # Calculate attention scores with all items (including self)
        attention_weights = 
          items
          |> Enum.map(fn {k, v} -> {k, cosine_similarity(vector, v)} end)
          |> Map.new()
          |> normalize_weights()
        
        # Calculate weighted sum of all value vectors
        context_vector = 
          items
          |> Enum.map(fn {k, v} -> 
            weight = Map.get(attention_weights, k, 0.0)
            Enum.map(v, &(&1 * weight))
          end)
          |> Enum.reduce(fn vec, acc -> 
            Enum.zip_with(vec, acc, &(&1 + &2))
          end)
        
        {key, context_vector}
      end)
    
    items_with_attention
  end
  
  @doc """
  Focuses attention on the most relevant memories based on the current context.
  """
  @spec focus_on_memories(context :: String.t() | [float()], opts :: keyword()) ::
    {:ok, [{key :: any(), memory :: any(), score :: float()]} | :no_memories]
  def focus_on_memories(context, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    threshold = Keyword.get(opts, :threshold, 0.1)
    
    # Get all relevant memories
    with {:ok, memories} <- WorkingMemory.search(context, limit: limit * 2) do
      if Enum.empty?(memories) do
        :no_memories
      else
        # Calculate attention scores
        scored_memories = 
          memories
          |> Enum.map(fn {key, value, _meta} ->
            # In a real implementation, you'd want to use a more sophisticated
            # similarity measure that takes into account the memory content
            score = cosine_similarity(context, to_string(key) <> " " <> to_string(value))
            {key, value, score}
          end)
          |> Enum.filter(fn {_k, _v, score} -> score >= threshold end)
          |> Enum.sort_by(fn {_k, _v, score} -> -score end)
          |> Enum.take(limit)
        
        {:ok, scored_memories}
      end
    end
  end
  
  # Helper function to calculate dot product
  defp dot(a, b) do
    a
    |> Enum.zip(b)
    |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
  end
end
