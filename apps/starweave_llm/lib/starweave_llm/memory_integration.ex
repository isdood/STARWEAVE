defmodule StarweaveLLM.MemoryIntegration do
  @moduledoc """
  Integrates LLM system with the pattern engine for memory retrieval and consolidation.
  Provides intelligent memory access and pattern-based context enhancement.
  """
  
  require Logger
  
  alias StarweaveCore.PatternStore
  alias StarweaveCore.PatternMatcher
  
  @type memory_query :: %{
    query: String.t(),
    limit: non_neg_integer(),
    min_relevance: float()
  }
  
  @type memory_result :: %{
    id: String.t(),
    content: String.t(),
    relevance_score: float(),
    timestamp: DateTime.t(),
    pattern_data: map()
  }
  
  @doc """
  Retrieves relevant memories from the pattern store based on a query.
  """
  @spec retrieve_memories(memory_query()) :: [memory_result()]
  def retrieve_memories(%{query: query, limit: limit, min_relevance: min_relevance}) do
    # Get all patterns from the store
    patterns = PatternStore.all()
    
    # Score patterns based on relevance to query
    scored_patterns = 
      patterns
      |> Enum.map(fn 
        {_id, pattern} = pattern_tuple -> 
          score = calculate_relevance_score(pattern, query)
          {pattern_tuple, score}
        pattern ->
          score = calculate_relevance_score(pattern, query)
          {pattern, score}
      end)
      |> Enum.filter(fn {_pattern, score} -> score >= min_relevance end)
      |> Enum.sort_by(fn {_pattern, score} -> score end, :desc)
      |> Enum.take(limit)
    
    # Convert to memory results
    Enum.map(scored_patterns, fn 
      {{id, pattern}, score} ->
        %{
          id: id || :crypto.strong_rand_bytes(16) |> Base.encode16(),
          content: extract_content(pattern),
          relevance_score: score,
          timestamp: pattern[:inserted_at] || DateTime.utc_now(),
          pattern_data: %{
            data: pattern[:data],
            metadata: pattern[:metadata] || %{},
            energy: pattern[:energy] || 1.0
          }
        }
      {pattern, score} ->
        %{
          id: pattern[:id] || :crypto.strong_rand_bytes(16) |> Base.encode16(),
          content: extract_content(pattern),
          relevance_score: score,
          timestamp: pattern[:inserted_at] || DateTime.utc_now(),
          pattern_data: %{
            data: pattern[:data],
            metadata: pattern[:metadata] || %{},
            energy: pattern[:energy] || 1.0
          }
        }
    end)
  end
  
  @doc """
  Consolidates multiple memories into a coherent summary.
  """
  @spec consolidate_memories([memory_result()]) :: String.t()
  def consolidate_memories(memories) when is_list(memories) do
    case memories do
      [] -> 
        "No relevant memories found."
      
      [single_memory] -> 
        "Relevant memory: #{single_memory.content}"
      
      _ ->
        # Group memories by relevance and create a summary
        high_relevance = Enum.filter(memories, &(&1.relevance_score >= 0.8))
        medium_relevance = Enum.filter(memories, &(&1.relevance_score >= 0.5 and &1.relevance_score < 0.8))
        
        parts = []
        
        parts = 
          if length(high_relevance) > 0 do
            high_summary = 
              high_relevance
              |> Enum.map(&(&1.content))
              |> Enum.join("; ")
            
            parts ++ ["Highly relevant: #{high_summary}"]
          else
            parts
          end
        
        parts = 
          if length(medium_relevance) > 0 do
            medium_summary = 
              medium_relevance
              |> Enum.map(&(&1.content))
              |> Enum.join("; ")
            
            parts ++ ["Related: #{medium_summary}"]
          else
            parts
          end
        
        Enum.join(parts, "\n")
    end
  end
  
  @doc """
  Stores a new memory in the pattern store.
  """
  @spec store_memory(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def store_memory(content, metadata \\ %{}) do
    pattern_id = "memory_#{System.system_time(:millisecond)}_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    pattern_data = %{
      data: content,
      metadata: Map.merge(metadata || %{}, %{
        type: "memory",
        created_at: DateTime.utc_now()
      }),
      energy: 1.0,
      inserted_at: System.system_time(:millisecond)
    }
    
    case PatternStore.put(pattern_id, pattern_data) do
      :ok -> {:ok, pattern_id}
      error -> 
        Logger.error("Failed to store memory: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Updates the energy/importance of a memory based on usage.
  """
  @spec update_memory_energy(String.t(), float()) :: :ok | {:error, term()}
  def update_memory_energy(memory_id, new_energy) do
    case PatternStore.get(memory_id) do
      {:ok, pattern_data} ->
        updated_pattern = Map.put(pattern_data, :energy, new_energy)
        PatternStore.put(memory_id, updated_pattern)
        :ok
        
      :not_found ->
        {:error, :memory_not_found}
        
      error ->
        Logger.error("Error updating memory energy: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Performs a comprehensive memory search with pattern matching.
  """
  @spec search_memories(String.t(), keyword()) :: [memory_result()]
  def search_memories(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_relevance = Keyword.get(opts, :min_relevance, 0.3)
    strategy = Keyword.get(opts, :strategy, :jaccard)
    
    patterns = PatternStore.all()
    
    # Use pattern matcher for more sophisticated matching
    relevant_patterns = 
      patterns
      |> Enum.filter(fn pattern -> 
        case PatternMatcher.match([pattern], query, strategy: strategy) do
          [] -> false
          _ -> true
        end
      end)
      |> Enum.map(fn pattern -> 
        score = calculate_relevance_score(pattern, query)
        {pattern, score}
      end)
      |> Enum.filter(fn {_pattern, score} -> score >= min_relevance end)
      |> Enum.sort_by(fn {_pattern, score} -> score end, :desc)
      |> Enum.take(limit)
    
    Enum.map(relevant_patterns, fn {pattern, score} ->
      %{
        id: pattern.id,
        content: extract_content(pattern),
        relevance_score: score,
        timestamp: pattern.inserted_at,
        pattern_data: %{
          data: pattern.data,
          metadata: pattern.metadata,
          energy: pattern.energy
        }
      }
    end)
  end
  
  # Private functions
  
  defp calculate_relevance_score({_id, pattern}, query) when is_binary(query) do
    calculate_relevance_score(pattern, query)
  end
  
  defp calculate_relevance_score(pattern, query) when is_binary(query) do
    try do
      # Extract content and energy safely
      content = extract_content(pattern)
      energy = if is_map(pattern), do: Map.get(pattern, :energy, 0.0), else: 0.0
      
      # Ensure content is a string
      content = if is_binary(content), do: content, else: inspect(content)
      
      # Simple Jaccard similarity scoring with energy boost
      query_words = 
        query 
        |> String.downcase() 
        |> String.split(~r/\W+/, trim: true)
        
      content_words = 
        content
        |> String.downcase() 
        |> String.split(~r/\W+/, trim: true)
      
      # Skip if no content to compare
      if Enum.empty?(query_words) or Enum.empty?(content_words) do
        0.0
      else
      
      # Calculate Jaccard similarity
      query_set = MapSet.new(query_words)
      content_set = MapSet.new(content_words)
      
      intersection_size = MapSet.intersection(query_set, content_set) |> MapSet.size()
      union_size = MapSet.union(query_set, content_set) |> MapSet.size()
      
      # Calculate base score with Jaccard similarity
      base_score = if union_size > 0, do: intersection_size / union_size, else: 0.0
      
      # Add energy boost (20% of pattern's energy)
      energy_boost = (energy || 0.0) * 0.2
      
      # Ensure score is between 0 and 1
        min(base_score + energy_boost, 1.0)
      end
    rescue
      e ->
        Logger.error("Error calculating relevance score: #{inspect(e)}")
        0.0
    end
  end
  
  defp calculate_relevance_score(_, _), do: 0.0
  
  defp extract_content({_id, %{data: content}}) when is_binary(content), do: content
  defp extract_content({_id, %{data: data}}) when is_map(data), do: Map.get(data, :content, inspect(data))
  defp extract_content({_id, map}) when is_map(map), do: Map.get(map, :content, inspect(map))
  defp extract_content(%{data: content}) when is_binary(content), do: content
  defp extract_content(%{data: data}) when is_map(data), do: Map.get(data, :content, inspect(data))
  defp extract_content(pattern) when is_map(pattern), do: Map.get(pattern, :content, inspect(pattern))
  defp extract_content(other), do: inspect(other)
  
end
