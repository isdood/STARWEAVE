defmodule StarweaveCore.Pattern.Temporal do
  @moduledoc """
  Handles temporal pattern recognition and analysis.
  
  This module provides functionality for:
  - Detecting patterns in time-series data
  - Analyzing event sequences
  - Modeling temporal relationships between patterns
  """
  
  alias StarweaveCore.Pattern
  
  @default_window_size 5
  @min_sequence_length 2
  
  @doc """
  Detects temporal patterns in a sequence of patterns.
  
  ## Parameters
  - patterns: List of patterns with timestamps
  - opts: Options including :window_size (default: 5)
  
  Returns a list of detected temporal patterns.
  """
  @spec detect_sequence([Pattern.t()], keyword()) :: [Pattern.t()]
  def detect_sequence(patterns, opts \\ []) do
    window_size = Keyword.get(opts, :window_size, @default_window_size)
    
    patterns
    |> Enum.sort_by(&(&1.inserted_at || 0))
    |> Enum.chunk_every(window_size, 1, :discard)
    |> Enum.flat_map(&find_sequences/1)
    |> Enum.uniq()
  end
  
  @doc """
  Analyzes the temporal relationship between two patterns.
  
  Returns a map with temporal relationship information.
  """
  @spec analyze_relationship(Pattern.t(), Pattern.t()) :: map()
  def analyze_relationship(%Pattern{} = p1, %Pattern{} = p2) do
    t1 = p1.inserted_at || 0
    t2 = p2.inserted_at || 0
    
    %{
      time_diff: abs(t1 - t2),
      order: if(t1 < t2, do: :before, else: :after),
      similarity: Pattern.Resonance.similarity(p1, p2)
    }
  end
  
  @doc """
  Finds recurring event sequences in the pattern history.
  """
  @spec find_recurring_sequences([Pattern.t()], pos_integer()) :: [list(Pattern.t())]
  def find_recurring_sequences(patterns, min_length \\ @min_sequence_length)
  
  def find_recurring_sequences([], _min_length), do: []
  def find_recurring_sequences(patterns, min_length) when is_list(patterns) do
    sorted = Enum.sort_by(patterns, &(&1.inserted_at || 0))
    find_sequences_recursive(sorted, [], min_length)
    |> Enum.filter(fn seq -> length(seq) >= min_length end)
    |> Enum.uniq_by(fn seq -> Enum.map(seq, & &1.id) end)
  end
  
  # Private functions
  
  defp find_sequences([_]), do: []
  
  defp find_sequences(patterns) do
    # Find all possible sequences within the window
    for i <- 0..(length(patterns) - 2),
        j <- (i + 1)..(length(patterns) - 1),
        seq = Enum.slice(patterns, i..j),
        length(seq) >= @min_sequence_length,
        into: [] do
      seq
    end
  end
  
  defp find_sequences_recursive([], acc, _min_length), do: acc
  defp find_sequences_recursive([head | tail] = patterns, acc, min_length) do
    # Find all sequences starting with the current pattern
    sequences = 
      patterns
      |> Enum.take_while(fn p -> time_diff(head, p) < 10_000 end) # 10 second window
      |> find_sequences()
    
    # Filter sequences by minimum length
    new_sequences = 
      sequences 
      |> Enum.filter(fn seq -> length(seq) >= min_length end)
    
    # Continue with the next pattern
    find_sequences_recursive(tail, new_sequences ++ acc, min_length)
  end
  
  defp time_diff(p1, p2) do
    t1 = p1.inserted_at || 0
    t2 = p2.inserted_at || 0
    abs(t1 - t2)
  end
end
