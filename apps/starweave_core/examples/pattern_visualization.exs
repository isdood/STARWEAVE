defmodule PatternVisualization do
  @moduledoc """
  A self-contained pattern visualization module that demonstrates:
  - Text-based pattern visualization
  - Timeline visualization
  - DOT graph output for GraphViz
  """
  
  @doc """
  Main entry point that demonstrates all visualization features.
  """
  def demo do
    patterns = generate_sample_patterns()
    
    IO.puts("\n=== Pattern Visualization Demo ===\n")
    
    IO.puts("1. Text-based Pattern List:")
    IO.puts(text_visualization(patterns))
    
    IO.puts("\n2. Timeline Visualization:")
    IO.puts(timeline(patterns))
    
    IO.puts("\n3. DOT Graph Output (saved to pattern_graph.dot):")
    dot = to_dot(patterns, title: "Pattern Relationships")
    File.write!("pattern_graph.dot", dot)
    IO.puts("   Run: dot -Tpng pattern_graph.dot -o pattern_graph.png")
  end
  
  @doc """
  Generates a text-based visualization of patterns.
  """
  def text_visualization(patterns) do
    patterns
    |> Enum.map(&pattern_summary/1)
    |> Enum.join("\n")
  end
  
  @doc """
  Generates a timeline visualization of patterns.
  """
  def timeline(patterns) do
    patterns = Enum.sort_by(patterns, & &1.inserted_at)
    
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
          "#{String.pad_leading(id, 4)}: #{bar} #{String.slice(to_string(data), 0..40)}"
        end)
        |> Enum.join("\n")
    end
  end
  
  @doc """
  Generates a DOT format representation of pattern relationships.
  """
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
    "##{id} \"#{data_preview}...\" (energy: #{:erlang.float_to_binary(energy, [decimals: 2])})"
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
  
  # Generate sample patterns for demonstration
  defp generate_sample_patterns do
    now = System.system_time(:second)
    
    [
      %{
        id: "animal1",
        data: "The quick brown fox jumps over the lazy dog",
        energy: 0.85,
        inserted_at: now - 3600,
        metadata: %{category: "animals"}
      },
      %{
        id: "animal2",
        data: "The quick brown fox jumps over the lazy dog",
        energy: 0.92,
        inserted_at: now - 1800,
        metadata: %{category: "animals"}
      },
      %{
        id: "shakespeare",
        data: "To be or not to be, that is the question",
        energy: 0.75,
        inserted_at: now - 900,
        metadata: %{category: "literature"}
      },
      %{
        id: "proverb",
        data: "All that glitters is not gold",
        energy: 0.68,
        inserted_at: now - 300,
        metadata: %{category: "literature"}
      },
      %{
        id: "animal3",
        data: "The lazy dog sleeps all day",
        energy: 0.6,
        inserted_at: now - 600,
        metadata: %{category: "animals"}
      }
    ]
  end
end

# Run the demo if this file is executed directly
if System.get_env("MIX_ENV") != "test" do
  PatternVisualization.demo()
end
