defmodule StarweaveLlm.SelfKnowledge.FindCallersTest do
  use ExUnit.Case, async: true
  alias StarweaveLlm.SelfKnowledge.CodeCrossReferencer
  
  setup do
    # Create a simple graph for testing
    graph = :digraph.new([:private])
    
    # Add some test vertices and edges
    # Function that calls String.contains?
    caller_vertex = {:function, "User.create/2"}
    :digraph.add_vertex(graph, caller_vertex, %{
      name: "User.create/2",
      type: :function,
      file: "lib/user.ex"
    })
    
    # The called function
    called_vertex = {:function, "String.contains?/2"}
    :digraph.add_vertex(graph, called_vertex, %{
      name: "String.contains?/2",
      type: :function,
      file: "lib/string.ex"
    })
    
    # Add the edge between them with label and metadata
    _edge = :digraph.add_edge(graph, caller_vertex, called_vertex, [
      label: :calls, 
      from: "User.create/2", 
      to: "String.contains?/2"
    ])
    
    # Log the graph structure for debugging
    IO.puts("\n=== Graph Structure ===")
    IO.puts("Vertices:")
    :digraph.vertices(graph) |> Enum.each(&IO.inspect/1)
    
    IO.puts("\nEdges:")
    :digraph.edges(graph) 
    |> Enum.map(fn e -> :digraph.edge(graph, e) end)
    |> Enum.each(&IO.inspect/1)
    
    IO.puts("\nVertex Data:")
    :digraph.vertices(graph)
    |> Enum.each(fn v -> 
      IO.inspect({:vertex_data, v, :digraph.vertex(graph, v)})
    end)
    
    on_exit(fn ->
      try do
        :digraph.delete(graph)
      rescue
        _ -> :ok
      end
    end)
    
    {:ok, graph: graph}
  end
  
  test "finds callers of a function", %{graph: graph} do
    IO.puts("\n=== Testing find_callers ===")
    IO.puts("Graph type: #{inspect(graph)}")
    
    # First, verify the target function exists in the graph
    # The function name in the graph is just the name without the module
    target_function = "contains?/2"
    
    # Test with function name and arity (without module)
    IO.puts("\nTesting with 'contains?/2'")
    
    # Debug: Print the graph structure
    IO.puts("\n=== Graph Structure ===")
    IO.puts("Graph type: #{inspect(graph)}")
    
    # Debug: Print all vertices
    IO.puts("\nAll vertices:")
    vertices = :digraph.vertices(graph)
    IO.inspect(vertices, label: "Vertices")
    
    # Debug: Print all edges
    IO.puts("\nAll edges:")
    edges = :digraph.edges(graph)
    Enum.each(edges, fn edge ->
      {edge, v1, v2, label} = :digraph.edge(graph, edge)
      IO.puts("Edge: #{inspect(edge)} from #{inspect(v1)} to #{inspect(v2)} with label #{inspect(label)}")
    end)
    
    # Debug: Try to find the target function vertex
    IO.puts("\nLooking for function: #{target_function}")
    
    # Try to find the target function vertex directly
    target_vertex = {:function, target_function}
    IO.puts("Looking for vertex: #{inspect(target_vertex)}")
    
    case :digraph.vertex(graph, target_vertex) do
      {^target_vertex, data} ->
        IO.puts("Found vertex data: #{inspect(data)}")
      false ->
        IO.puts("Vertex not found")
    end
    
    # Try to find any vertex that contains the target function name
    matching_vertices = Enum.filter(vertices, fn
      {:function, name} -> String.contains?(name, "contains?")
      _ -> false
    end)
    
    IO.puts("Matching vertices: #{inspect(matching_vertices)}")
    
    # Now try to find the callers
    callers = CodeCrossReferencer.find_callers(graph, target_function)
    
    IO.puts("\nFound callers: #{inspect(callers)}")
    
    # Verify we found at least one caller
    assert length(callers) > 0, "Expected at least one caller, got none"
    
    # Verify the caller is correct
    caller = List.first(callers)
    assert %{module: "User", function: "create", file: "lib/user.ex"} = caller
  end
end
