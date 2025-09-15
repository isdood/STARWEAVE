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
      |> Enum.map(fn pattern -> 
        score = calculate_relevance_score(pattern, query)
        {pattern, score}
      end)
      |> Enum.filter(fn {_pattern, score} -> score >= min_relevance end)
      |> Enum.sort_by(fn {_pattern, score} -> score end, :desc)
      |> Enum.take(limit)
    
    # Convert to memory results
    Enum.map(scored_patterns, fn {pattern, score} ->
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
  
  defp calculate_relevance_score(pattern, query) do
    # Simple TF-IDF inspired scoring
    query_words = String.downcase(query) |> String.split(~r/\W+/)
    content_words = String.downcase(pattern.data) |> String.split(~r/\W+/)
    
    # Count matching words
    matches = 
      query_words
      |> Enum.count(fn word -> 
        String.length(word) > 2 && word in content_words
      end)
    
    # Calculate score based on matches and pattern energy
    base_score = if length(query_words) > 0, do: matches / length(query_words), else: 0.0
    energy_boost = pattern.energy * 0.2
    
    min(base_score + energy_boost, 1.0)
  end
  
  defp extract_content(pattern) do
    case pattern.data do
      content when is_binary(content) -> content
      data when is_map(data) -> Map.get(data, :content, inspect(data))
      other -> inspect(other)
    end
  end
  
  defp generate_memory_id do
    "memory_#{System.system_time(:millisecond)}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end
