defmodule StarweaveCore.Pattern.Evolution do
  @moduledoc """
  Handles the evolution of patterns over time through merging, splitting,
  and adaptation based on feedback and usage patterns.
  """
  
  alias StarweaveCore.Pattern
  alias StarweaveCore.Pattern.Resonance
  
  @default_merge_threshold 0.7
  @default_split_threshold 0.3
  @max_pattern_size 1000
  
  @doc """
  Evolves patterns based on new input and feedback.
  
  This is the main entry point for pattern evolution, which may result in:
  - New patterns being created
  - Existing patterns being merged
  - Patterns being split
  - Pattern metadata being updated
  """
  @spec evolve([Pattern.t()], Pattern.t(), keyword()) :: [Pattern.t()]
  def evolve(patterns, new_pattern, opts \\ []) do
    merge_threshold = Keyword.get(opts, :merge_threshold, @default_merge_threshold)
    split_threshold = Keyword.get(opts, :split_threshold, @default_split_threshold)
    
    patterns
    |> maybe_merge_similar(new_pattern, merge_threshold)
    |> maybe_split_large(split_threshold)
    |> update_pattern_metadata(new_pattern)
  end
  
  @doc """
  Merges similar patterns to reduce redundancy.
  
  Returns an updated list of patterns with similar ones merged.
  """
  @spec merge_similar([Pattern.t()], float()) :: [Pattern.t()]
  def merge_similar(patterns, threshold \\ @default_merge_threshold) do
    # First group patterns by their data for exact matches
    {exact_matches, remaining} = 
      patterns
      |> Enum.group_by(& &1.data)
      |> Map.to_list()
      |> Enum.split_with(fn {_data, ps} -> length(ps) > 1 end)
    
    # Merge exact matches
    merged_exact = 
      exact_matches
      |> Enum.flat_map(fn {_data, ps} -> 
        [ps |> Enum.reduce(&merge_patterns/2)] 
      end)
    
    # Then find and merge similar patterns among remaining
    remaining_patterns = Enum.flat_map(remaining, fn {_, [p]} -> [p] end)
    
    similar_merged = 
      find_similar_pairs(remaining_patterns, threshold)
      |> Enum.reduce(remaining_patterns, fn {p1, p2}, acc ->
        merged = merge_patterns(p1, p2)
        acc -- [p1, p2] ++ [merged]
      end)
    
    # Combine results
    merged_exact ++ similar_merged
  end
  
  @doc """
  Splits large or complex patterns into smaller, more focused ones.
  """
  @spec split_large([Pattern.t()], float()) :: [Pattern.t()]
  def split_large(patterns, threshold \\ @default_split_threshold) do
    patterns
    |> Enum.flat_map(fn pattern ->
      if should_split?(pattern, threshold) do
        split_pattern(pattern)
      else
        [pattern]
      end
    end)
  end
  
  # Private functions
  
  defp maybe_merge_similar(patterns, new_pattern, threshold) do
    # Find patterns similar to the new one
    similar = 
      patterns
      |> Enum.filter(fn p -> 
        Resonance.similarity(p, new_pattern) >= threshold 
      end)
    
    case similar do
      [] -> [new_pattern | patterns]  # No similar patterns, just add the new one
      [match | _] -> 
        # Merge with the most similar pattern
        merged = merge_patterns(match, new_pattern)
        [merged | patterns -- similar]
    end
  end
  
  defp maybe_split_large(patterns, threshold) do
    Enum.flat_map(patterns, fn pattern ->
      if should_split?(pattern, threshold) do
        split_pattern(pattern)
      else
        [pattern]
      end
    end)
  end
  
  @doc """
  Updates metadata for patterns based on new input.
  
  This is exposed for testing purposes.
  """
  @spec update_pattern_metadata([Pattern.t()], Pattern.t()) :: [Pattern.t()]
  def update_pattern_metadata(patterns, new_pattern) do
    # Update usage statistics, last_used, etc.
    now = System.system_time(:second)
    
    patterns
    |> Enum.map(fn %Pattern{} = p ->
      # If this is the pattern that was just matched/used
      if p.id == new_pattern.id do
        %{p | 
          metadata: Map.merge(p.metadata || %{}, %{
            last_used: now,
            use_count: (get_in(p.metadata || %{}, [:use_count]) || 0) + 1
          })
        }
      else
        p
      end
    end)
  end
  
  defp find_similar_pairs(patterns, threshold) do
    for p1 <- patterns,
        p2 <- patterns,
        p1.id < p2.id,  # Avoid duplicate pairs and self-comparison
        Resonance.similarity(p1, p2) >= threshold,
        do: {p1, p2}
  end
  
  defp merge_patterns(%Pattern{} = p1, %Pattern{} = p2) do
    # Simple concatenation for now - could be enhanced with more sophisticated merging
    merged_data = "#{p1.data} #{p2.data}"
    
    %Pattern{
      id: "#{p1.id}_#{p2.id}_#{:crypto.strong_rand_bytes(4) |> Base.encode16()}",
      data: merged_data,
      metadata: merge_metadata(p1, p2),
      energy: (p1.energy + p2.energy) / 2,
      inserted_at: System.system_time(:second)
    }
  end
  
  defp merge_metadata(p1, p2) do
    # Merge metadata from both patterns
    Map.merge(p1.metadata, p2.metadata, fn 
      _k, v1, v2 when is_integer(v1) -> v1 + v2
      _k, _v1, v2 -> v2  # Prefer the second pattern's value for non-integers
    end)
  end
  
  defp should_split?(%Pattern{data: data}, threshold) do
    # Consider splitting if the pattern is too large or has low coherence
    size = String.length(data)
    coherence = calculate_coherence(data)
    
    size > @max_pattern_size or coherence < threshold
  end
  
  defp split_pattern(%Pattern{data: data} = pattern) do
    # Simple splitting by sentences for now - could be enhanced with NLP
    sentences = 
      data 
      |> String.split(~r/(?<=[.!?])\s+/, trim: true)
      |> Enum.filter(&(String.length(&1) > 10))  # Filter out very short fragments
    
    case sentences do
      [] -> [pattern]  # Don't split if we can't get meaningful parts
      parts ->
        parts
        |> Enum.map(fn part ->
          %Pattern{
            id: "#{pattern.id}_#{:crypto.strong_rand_bytes(2) |> Base.encode16()}",
            data: String.trim(part),
            metadata: pattern.metadata,
            energy: pattern.energy * 0.9,  # New patterns start with slightly less energy
            inserted_at: System.system_time(:second)
          }
        end)
    end
  end
  
  defp calculate_coherence(data) do
    # Simple coherence measure based on sentence similarity
    sentences = String.split(data, ~r/(?<=[.!?])\s+/)
    
    case length(sentences) do
      0 -> 1.0  # No sentences means trivially coherent
      1 -> 1.0  # Single sentence is perfectly coherent
      _ ->
        # Calculate average similarity between adjacent sentences
        similarities = 
          sentences 
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [s1, s2] ->
            tokens1 = tokenize(s1)
            tokens2 = tokenize(s2)
            jaccard_similarity(tokens1, tokens2)
          end)
        
        Enum.sum(similarities) / length(similarities)
    end
  end
  
  defp tokenize(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s]+/u, " ")
    |> String.split()
    |> Enum.reject(&(String.length(&1) < 2))
    |> MapSet.new()
  end
  
  defp jaccard_similarity(a, b) do
    intersection = MapSet.intersection(a, b) |> MapSet.size()
    union = MapSet.union(a, b) |> MapSet.size()
    
    if union == 0 do
      0.0
    else
      intersection / union
    end
  end
end
