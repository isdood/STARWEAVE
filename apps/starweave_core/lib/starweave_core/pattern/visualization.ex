defmodule StarweaveCore.Pattern.Visualization do
  @moduledoc """
  Provides visualization utilities for patterns and their relationships.
  This module offers text-based visualizations that can be rendered in the console
  or converted to other formats like GraphViz DOT format.
  """
  
  @type pattern :: %{
    id: String.t(),
    data: any(),
    metadata: map() | nil,
    energy: float() | nil,
    inserted_at: integer() | nil
  }
  
  @doc """
  Generates a visualization of patterns in the specified format.
  
  ## Options
    * `:format` - Output format, either `:text` (default) or `:dot` for GraphViz format
    * `:similarity_threshold` - Minimum similarity score to show relationships (0.0-1.0)
    * `:max_patterns` - Maximum number of patterns to visualize (for performance)
  """
  @spec visualize([pattern()], keyword()) :: String.t()
  def visualize(patterns, opts \\ []) do
    format = Keyword.get(opts, :format, :text)
    threshold = Keyword.get(opts, :similarity_threshold, 0.1)
    max_patterns = Keyword.get(opts, :max_patterns, 50)
    
    patterns = patterns |> Enum.take(max_patterns)
    
    case format do
      :dot -> to_dot(patterns, similarity_threshold: threshold)
      _ -> text_visualization(patterns)
    end
  end
  
  @doc """
  Generates a text-based visualization of patterns.
  """
  @spec text_visualization([pattern()]) :: String.t()
  def text_visualization(patterns) do
    """
    === Pattern Visualization ===
    
    Patterns:
    #{Enum.map_join(patterns, "\n", &("  " <> pattern_summary(&1)))}
    """
  end
  
  @doc """
  Generates a timeline visualization of patterns.
  """
  @spec timeline([pattern()], keyword()) :: String.t()
  def timeline(patterns, _opts \\ []) do
    patterns = Enum.sort_by(patterns, & &1[:inserted_at] || 0)
    
    case patterns do
      [] -> "No patterns to display"
      _ ->
        min_time = patterns |> hd() |> Map.get(:inserted_at, 0)
        max_time = patterns |> List.last() |> Map.get(:inserted_at, min_time + 1)
        time_span = max(max_time - min_time, 1)
        
        patterns
        |> Enum.map(fn %{id: id, inserted_at: time, data: data} ->
          rel_time = ((time - min_time) / time_span) * 50
          bar = String.duplicate(" ", round(rel_time)) <> "●"
          "#{String.pad_leading(id, 6)}: #{bar} #{String.slice(to_string(data), 0..40)}"
        end)
        |> Enum.join("\n")
    end
  end
  
  @doc """
  Generates a DOT format representation of pattern relationships.
  """
  @spec to_dot([pattern()], keyword()) :: String.t()
  def to_dot(patterns, opts \\ []) do
    title = Keyword.get(opts, :title, "Pattern Relationships")
    threshold = Keyword.get(opts, :similarity_threshold, 0.1)
    
    """
    digraph "#{title}" {
      rankdir=LR;
      node [shape=box, style=rounded];
      
      #{patterns |> Enum.with_index() |> Enum.map_join("\n", fn {pattern, i} ->
        label = "#{pattern.id}\n#{String.slice(to_string(pattern.data), 0..15)}..."
        ~s(  p#{i} [label="#{label}"];)
      end)}
      
      #{find_relationships(patterns, threshold) |> Enum.map_join("\n", fn {i, j, sim} ->
        ~s(  p#{i} -> p#{j} [label="#{:erlang.float_to_binary(sim, [decimals: 2])}"];)
      end)}
    }
    """
  end
  
  # Private helper functions
  
  defp pattern_summary(%{id: id, data: data, energy: energy}) do
    data_preview = data |> to_string() |> String.slice(0..40)
    "##{id} \"#{data_preview}...\" (energy: #{:erlang.float_to_binary(energy || 0.0, [decimals: 2])})"
  end
  
  defp find_relationships(patterns, threshold) do
    for {p1, i} <- Enum.with_index(patterns),
        {p2, j} <- Enum.with_index(patterns),
        i < j,
        sim = similarity(p1, p2),
        sim > threshold do
      {i, j, sim}
    end
  end
  
  # Simple similarity function for demo purposes
  defp similarity(p1, p2) do
    s1 = String.downcase(to_string(p1.data))
    s2 = String.downcase(to_string(p2.data))
    
    # Simple Jaccard similarity on words
    words1 = String.split(s1) |> Enum.uniq()
    words2 = String.split(s2) |> Enum.uniq()
    
    intersection = length(Enum.filter(words1, &(&1 in words2)))
    union = length(Enum.uniq(words1 ++ words2))
    
    if union > 0, do: intersection / union, else: 0.0
  end
end
