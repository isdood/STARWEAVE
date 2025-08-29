defmodule StarweaveCore.Pattern.Resonance do
  @moduledoc """
  Implements resonance-based learning for patterns.
  
  Resonance measures how strongly a new pattern activates existing patterns
  based on their similarity and energy levels.
  """
  
  alias StarweaveCore.Pattern
  
  @default_threshold 0.3
  @decay_rate 0.95
  @max_energy 1.0
  @min_energy 0.01
  
  @doc """
  Calculates resonance between a new pattern and existing patterns.
  
  Returns a list of {resonance_score, pattern} tuples sorted by score in descending order.
  """
  @spec calculate_resonance([Pattern.t()], Pattern.t(), keyword()) :: [{float(), Pattern.t()}]
  def calculate_resonance(patterns, %Pattern{} = new_pattern, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    
    patterns
    |> Enum.map(fn pattern ->
      score = calculate_resonance_score(pattern, new_pattern, opts)
      {score, pattern}
    end)
    |> Enum.filter(fn {score, _} -> score >= threshold end)
    |> Enum.sort_by(fn {score, _} -> -score end)
  end
  
  @doc """
  Updates the energy of patterns based on resonance.
  
  Returns the updated list of patterns with adjusted energy levels.
  """
  @spec update_energy([Pattern.t()], Pattern.t(), keyword()) :: [Pattern.t()]
  def update_energy(patterns, %Pattern{} = new_pattern, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    
    # Apply decay to all patterns first
    patterns = Enum.map(patterns, &decay_energy/1)
    
    # Calculate resonance and update matching patterns
    {updated, unchanged} = patterns
    |> Enum.split_with(fn pattern ->
      calculate_resonance_score(pattern, new_pattern, opts) >= threshold
    end)
    
    # Increase energy of resonant patterns
    updated = Enum.map(updated, &increase_energy/1)
    
    # Add new pattern with initial energy
    new_pattern = %{new_pattern | energy: initial_energy()}
    
    [new_pattern | updated] ++ unchanged
    |> Enum.sort_by(&{-&1.energy, &1.inserted_at || 0})
  end
  
  # Private functions
  
  defp calculate_resonance_score(%Pattern{data: data1}, %Pattern{data: data2}, _opts) do
    # Simple Jaccard similarity for now, can be enhanced with more sophisticated metrics
    tokens1 = tokenize(data1)
    tokens2 = tokenize(data2)
    jaccard_similarity(tokens1, tokens2)
  end
  
  defp tokenize(text) when is_binary(text) do
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
  
  defp decay_energy(%Pattern{energy: energy} = pattern) do
    new_energy = energy * @decay_rate
    %{pattern | energy: max(new_energy, @min_energy)}
  end
  
  defp increase_energy(%Pattern{energy: energy} = pattern) do
    new_energy = min(energy + 0.1, @max_energy)
    %{pattern | energy: new_energy}
  end
  
  defp initial_energy, do: 0.5
  
  @doc """
  Returns a similarity score between two patterns (0.0 to 1.0).
  """
  @spec similarity(Pattern.t(), Pattern.t()) :: float()
  def similarity(%Pattern{data: data1}, %Pattern{data: data2}) do
    tokens1 = tokenize(data1)
    tokens2 = tokenize(data2)
    jaccard_similarity(tokens1, tokens2)
  end
end
