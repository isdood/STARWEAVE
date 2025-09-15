defmodule StarweaveCore.Intelligence.PatternLearner do
  @moduledoc """
  Pattern-based learning system for STARWEAVE.
  
  This module is responsible for identifying, storing, and utilizing patterns
  from the system's experiences to improve future decision-making.
  """
  
  use GenServer
  
  alias StarweaveCore.Intelligence.WorkingMemory
  
  # Default pattern learning parameters
  @default_min_confidence 0.7
  @max_patterns_to_store 1000
  
  # Client API
  
  @doc """
  Starts the PatternLearner.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Processes a new event and attempts to learn patterns from it.
  """
  @spec learn_from_event(map()) :: :ok
  def learn_from_event(event) when is_map(event) do
    GenServer.cast(__MODULE__, {:learn_from_event, event})
  end
  
  @doc """
  Finds patterns that match the given context.
  """
  @spec find_matching_patterns(map(), keyword()) :: [map()]
  def find_matching_patterns(context, opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, @default_min_confidence)
    GenServer.call(__MODULE__, {:find_matching_patterns, context, min_confidence})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Load patterns from working memory or initialize empty
    patterns = 
      case WorkingMemory.retrieve(:patterns, :all) do
        {:ok, saved_patterns} -> saved_patterns
        _ -> %{}
      end
    
    {:ok, %{patterns: patterns, event_buffer: []}}
  end
  
  @impl true
  def handle_cast({:learn_from_event, event}, state) do
    %{patterns: patterns, event_buffer: buffer} = state
    
    # Add to buffer and check for patterns if buffer is large enough
    updated_buffer = [event | buffer] |> Enum.take(100)  # Keep buffer size manageable
    
    # If buffer has enough events, try to find patterns
    if length(updated_buffer) >= 5 do
      new_patterns = extract_patterns(updated_buffer, patterns)
      
      # Merge new patterns with existing ones
      updated_patterns = 
        Map.merge(patterns, new_patterns, fn _k, v1, v2 -> 
          # Merge pattern occurrences and update confidence
          %{
            pattern: v1.pattern,
            occurrences: v1.occurrences + v2.occurrences,
            last_seen: NaiveDateTime.utc_now(),
            confidence: (v1.confidence * v1.occurrences + v2.confidence * v2.occurrences) / 
                       (v1.occurrences + v2.occurrences)
          }
        end)
      
      # Limit the number of stored patterns
      trimmed_patterns = 
        updated_patterns
        |> Enum.sort_by(fn {_k, v} -> v.confidence * v.occurrences end, :desc)
        |> Enum.take(@max_patterns_to_store)
        |> Map.new()
      
      # Persist patterns to working memory
      WorkingMemory.store(:patterns, :all, trimmed_patterns)
      
      {:noreply, %{state | patterns: trimmed_patterns, event_buffer: []}}
    else
      {:noreply, %{state | event_buffer: updated_buffer}}
    end
  end
  
  @impl true
  def handle_call({:find_matching_patterns, context, min_confidence}, _from, state) do
    patterns = 
      state.patterns
      |> Enum.filter(fn {_id, pattern} -> 
        pattern.confidence >= min_confidence and
        pattern_matches_context?(pattern.pattern, context)
      end)
      |> Enum.map(fn {_id, pattern} -> 
        %{
          pattern: pattern.pattern,
          confidence: pattern.confidence,
          occurrences: pattern.occurrences,
          last_seen: pattern.last_seen
        }
      end)
      |> Enum.sort_by(&(-&1.confidence * &1.occurrences))
    
    {:reply, patterns, state}
  end
  
  # Private functions
  
  defp extract_patterns(events, existing_patterns) do
    # Extract features from events
    features = extract_features(events)
    
    # Look for patterns in the features
    find_frequent_patterns(features, existing_patterns)
  end
  
  defp extract_features(events) do
    # Convert events to feature maps
    events
    |> Enum.map(fn event ->
      # This is a simplified feature extraction
      # In a real implementation, you'd extract more meaningful features
      %{
        type: event[:type],
        timestamp: event[:timestamp] || NaiveDateTime.utc_now(),
        # Add more features based on your event structure
        # For example:
        # - Event type
        # - Timestamp patterns
        # - Sequence of actions
        # - Contextual information
      }
    end)
  end
  
  defp find_frequent_patterns(features, existing_patterns) do
    # This is a simplified pattern mining approach
    # In a real implementation, you might use algorithms like:
    # - Apriori
    # - FP-Growth
    # - PrefixSpan (for sequential patterns)
    
    # For now, we'll look for simple co-occurrence patterns
    patterns = %{}
    
    # Look for sequential patterns
    patterns = find_sequential_patterns(features, patterns, existing_patterns)
    
    # Look for co-occurrence patterns
    patterns = find_co_occurrence_patterns(features, patterns, existing_patterns)
    
    patterns
  end
  
  defp find_sequential_patterns(features, patterns, _existing_patterns) do
    # Look for sequences of events that occur in order
    # This is a simplified version - in practice, you'd use a proper algorithm
    features
    |> Enum.chunk_every(3, 1, :discard)  # Look at sequences of 3 events
    |> Enum.reduce(patterns, fn seq, acc ->
      pattern_id = :crypto.hash(:sha256, inspect(seq)) |> Base.encode16()
      
      Map.update(acc, pattern_id, %{
        pattern: seq,
        occurrences: 1,
        confidence: 1.0,
        last_seen: NaiveDateTime.utc_now()
      }, fn existing ->
        %{
          pattern: existing.pattern,
          occurrences: existing.occurrences + 1,
          confidence: existing.confidence * 0.95 + 0.05,  # Slight confidence boost
          last_seen: NaiveDateTime.utc_now()
        }
      end)
    end)
  end
  
  defp find_co_occurrence_patterns(features, patterns, _existing_patterns) do
    # Look for features that commonly occur together
    # This is a simplified version - in practice, you'd use a proper algorithm
    features
    |> Enum.flat_map(fn feature ->
      # Create pairs of features that occur together
      for {k1, v1} <- Map.to_list(feature),
          {k2, v2} <- Map.to_list(feature),
          k1 != k2 do
        {{k1, v1, k2, v2}, 1}
      end
    end)
    |> Enum.reduce(%{}, fn {pair, count}, acc ->
      Map.update(acc, pair, count, &(&1 + count))
    end)
    |> Enum.filter(fn {_pair, count} -> count > 1 end)  # Only keep pairs that occur together multiple times
    |> Enum.reduce(patterns, fn {{k1, v1, k2, v2}, count}, acc ->
      pattern_id = :crypto.hash(:sha256, inspect({{k1, v1}, {k2, v2}})) |> Base.encode16()
      
      Map.update(acc, pattern_id, %{
        pattern: %{k1 => v1, k2 => v2},
        occurrences: count,
        confidence: count / length(features),
        last_seen: NaiveDateTime.utc_now()
      }, fn existing ->
        %{
          pattern: existing.pattern,
          occurrences: existing.occurrences + 1,
          confidence: (existing.confidence * existing.occurrences + count) / (existing.occurrences + 1),
          last_seen: NaiveDateTime.utc_now()
        }
      end)
    end)
  end
  
  defp pattern_matches_context?(pattern, context) when is_map(pattern) and is_map(context) do
    # Check if all key-value pairs in the pattern exist in the context
    Enum.all?(pattern, fn {k, v} -> 
      case context do
        %{^k => context_val} -> 
          # If the pattern value is a function, use it as a predicate
          if is_function(v) do
            v.(context_val)
          else
            v == context_val
          end
        _ -> false
      end
    end)
  end
  
  defp pattern_matches_context?(_pattern, _context), do: false
end
