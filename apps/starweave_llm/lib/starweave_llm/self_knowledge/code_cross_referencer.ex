defmodule StarweaveLlm.SelfKnowledge.CodeCrossReferencer do
  @moduledoc """
  Handles cross-referencing between different code elements in the codebase.

  This module is responsible for:
  - Finding references to modules, functions, and types
  - Building a graph of relationships between code elements
  - Providing context-aware lookups for related code
  """

  require Logger
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase

  @type vertex :: {:module, String.t()} | {:function, String.t()} | {:type, String.t()}
  @type graph :: :digraph.graph()

  @doc """
  Finds all references to a given module or function in the codebase.

  ## Examples
      iex> find_references(KnowledgeBase, "MyModule")
      [%{file: "lib/my_module.ex", line: 42, context: "MyModule.function_call()"}]
  """
  @spec find_references(KnowledgeBase.t(), String.t()) :: list(map())
  def find_references(knowledge_base, symbol) do
    case KnowledgeBase.get_all_documents(knowledge_base) do
      {:ok, documents} ->
        documents
        |> Enum.flat_map(fn {file_path, %{parsed_content: parsed_content}} ->
          find_references_in_file(parsed_content, file_path, symbol)
        end)
        |> Enum.reject(&is_nil/1)

      error ->
        Logger.error("Failed to get documents from knowledge base: #{inspect(error)}")
        []
    end
  end


  @doc """
  Builds a graph of relationships between code elements.

  This can be used for:
  - Finding all callers of a function
  - Finding all implementors of a behaviour
  - Finding all references to a type
  """
  @spec build_relationship_graph(KnowledgeBase.t()) :: {:ok, :digraph.graph()} | {:error, atom() | String.t()}
  def build_relationship_graph(knowledge_base) do
    # Create a new digraph
    graph = :digraph.new([:private])

    case KnowledgeBase.get_all_documents(knowledge_base) do
      {:ok, documents} when is_map(documents) ->
        try do
          Enum.each(documents, fn {file_path, %{parsed_content: content}} ->
            add_to_graph(graph, file_path, content)
          end)

          # Verify the graph has been built correctly
          if :digraph.vertices(graph) == [] do
            :digraph.delete(graph)
            {:error, :no_vertices}
          else
            {:ok, graph}
          end
        rescue
          e ->
            :digraph.delete(graph)
            Logger.error("Failed to build relationship graph: #{inspect(e)}")
            {:error, :graph_build_failed}
        end

      {:error, reason} ->
        :digraph.delete(graph)
        Logger.error("Failed to get documents from knowledge base: #{inspect(reason)}")
        {:error, reason}

      other ->
        :digraph.delete(graph)
        Logger.error("Unexpected response from knowledge base: #{inspect(other)}")
        {:error, :unexpected_response}
    end
  end

  @doc """
  Finds all related code elements for a given symbol.

  Returns a map with different types of relationships:
  - `:callers` - Functions that call this symbol
  - `:references` - Other references to this symbol
  - `:implementations` - For behaviours or protocols
  - `:types` - Related type definitions
  """
  @spec find_related(KnowledgeBase.t(), String.t()) :: map()
  def find_related(knowledge_base, symbol) do
    graph = build_relationship_graph(knowledge_base)

    # Try to find both with and without .t suffix for types
    type_name = if String.ends_with?(symbol, ".t"), do: symbol, else: "#{symbol}.t"

    %{
      callers: find_callers(graph, symbol),
      references: find_references(knowledge_base, symbol),
      implementations: find_implementations(knowledge_base, symbol),
      types: find_related_types(knowledge_base, type_name)
    }
  end

  # Private functions

  defp find_references_in_file(%{module: module, functions: functions} = content, file_path, symbol) do
    # Check module name
    module_refs =
      if String.contains?(module, symbol) do
        [%{type: :module, name: module, file: file_path}]
      else
        []
      end

    # Check function names and their calls
    func_refs =
      (functions || [])
      |> Enum.flat_map(fn %{name: name, calls: calls} = func ->
        refs = []

        # Check function name
        refs = if String.contains?(name, symbol) do
          [%{type: :function, name: "#{module}.#{name}", file: file_path} | refs]
        else
          refs
        end

        # Check function calls
        call_refs =
          (calls || [])
          |> Enum.filter(&String.contains?(to_string(&1), symbol))
          |> Enum.map(fn call ->
            if String.contains?(to_string(call), ".") do
              # Add both function and module reference when fully qualified
              mod = String.split(to_string(call), ".") |> List.first()
              [%{type: :function, name: call, file: file_path}, %{type: :module, name: mod, file: file_path}]
            else
              %{type: :function, name: "#{module}.#{call}", file: file_path}
            end
          end)
          |> List.flatten()

        refs ++ call_refs
      end)

    # Check types
    type_refs =
      (Map.get(content, :types, []) || [])
      |> Enum.filter(&String.contains?(to_string(Map.get(&1, :name, "")), symbol))
      |> Enum.map(&%{type: :type, name: "#{module}.#{&1.name}", file: file_path})

    module_refs ++ func_refs ++ type_refs
  end

  defp find_references_in_file(_, _, _) do
    []
  end

  defp add_to_graph(graph, file_path, content) when is_map(content) do
    try do
      # Handle module with functions
      module_name = Map.get(content, :module)
      functions = Map.get(content, :functions, [])

      if module_name && is_list(functions) do
        # Add module vertex if it doesn't exist
        module_vertex = {:module, module_name}
        :digraph.add_vertex(graph, module_vertex)

        # Add functions and their relationships
        for func <- functions do
          func_name = Map.get(func, :name)
          func_arity = Map.get(func, :arity, 0)
          full_func_name = "#{module_name}.#{func_name}/#{func_arity}"
          func_vertex = {:function, full_func_name}

          # Add function vertex with metadata and edge from module to function
          :digraph.add_vertex(graph, func_vertex, %{
            name: full_func_name,
            type: :function,
            file: file_path,
            spec: Map.get(func, :spec)
          })
          :digraph.add_edge(graph, module_vertex, func_vertex)

          # Add function calls
          if calls = Map.get(func, :calls, []) do
            for call <- calls do
              # Normalize call name (e.g., "User.create" -> "User.create/2")
              call_vertex =
                if String.contains?(call, "/") do
                  {:function, call}
                else
                  # If no arity specified, we'll match any arity
                  {:function, "#{call}/_"}
                end

              # Add the called function vertex if it doesn't exist
              :digraph.add_vertex(graph, call_vertex)
              :digraph.add_edge(graph, func_vertex, call_vertex)
            end
          end
        end

        # Add type references if they exist
        if types = Map.get(content, :types, []) do
          for type <- types do
            type_name = Map.get(type, :name)
            type_vertex = {:type, "#{module_name}.#{type_name}"}
            :digraph.add_vertex(graph, type_vertex)
            :digraph.add_edge(graph, module_vertex, type_vertex)
          end
        end
      end

      graph
    rescue
      error ->
        Logger.error("Error adding to graph: #{inspect(error)}")
        graph
    end
  end

  defp add_to_graph(graph, _file_path, _content) do
    # Skip invalid content
    graph
  end

  defp add_type_references(graph_ref, %{types: types}, file_path, module_name) when is_list(types) do
    Enum.each(types, fn %{name: type_name, definition: definition} ->
      type_vertex = {type_name, "#{module_name}.#{type_name}"}
      :digraph.add_vertex(graph_ref, type_vertex)

      # Add edge from module to type
      module_vertex = {module_name, module_name}
      :digraph.add_edge(graph_ref, module_vertex, type_vertex, :defines_type)

      # Find references to other types in the definition
      find_type_references(definition)
      |> Enum.each(fn referenced_type ->
        ref_type_vertex = {referenced_type, referenced_type}
        :digraph.add_vertex(graph_ref, ref_type_vertex)
        :digraph.add_edge(graph_ref, type_vertex, ref_type_vertex, :references_type)
      end)
    end)
  end

  defp add_type_references(_, _, _, _), do: :ok

  defp find_type_references(definition) when is_binary(definition) do
    # Simple regex to find type references like TypeName or Module.TypeName
    ~r/\b[A-Z]\w*(?:\.[A-Z]\w*)*\.t\b/
    |> Regex.scan(definition)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp add_function_calls(graph_ref, {_type, full_name} = function_vertex, %{calls: calls}, file_path) when is_list(calls) do
    Enum.each(calls, fn call ->
      # Create a consistent vertex for the called function
      called_vertex = {:function, call}
      
      # Add the calling function as a vertex with metadata if it doesn't exist
      :digraph.add_vertex(graph_ref, function_vertex, %{
        name: full_name,
        type: :function,
        file: file_path
      })
      
      # Add the called function as a vertex with metadata if it doesn't exist
      :digraph.add_vertex(graph_ref, called_vertex, %{
        name: call,
        type: :function,
        file: file_path
      })
      
      # Add an edge from the calling function to the called function
      edge = :digraph.add_edge(graph_ref, function_vertex, called_vertex)
      
      # Add metadata to the edge
      :digraph.edge(graph_ref, edge, {
        function_vertex,
        called_vertex,
        [
          label: :calls,
          from: full_name,
          to: call,
          file: file_path
        ]
      })
    end)
  end

  defp add_function_calls(_, _, _, _), do: :ok

  @doc """
  Finds a vertex in the graph that matches the given symbol.
  """
  @spec find_vertex(graph(), String.t()) :: vertex() | nil
  def find_vertex(graph, symbol) do
    :digraph.vertices(graph)
    |> Enum.find(fn
      {_type, name} when is_binary(name) -> String.contains?(name, symbol)
      {_type, name} -> String.contains?(to_string(name), symbol)
      _ -> false
    end)
  end

  @doc """
  Finds all functions that call the specified function.
  """
  @spec find_callers(KnowledgeBase.t() | :digraph.graph() | {:ok, any()} | {:error, any()}, String.t()) :: [map()]
  def find_callers({:ok, graph}, function_name), do: find_callers(graph, function_name)
  def find_callers({:error, _}, _function_name), do: []

  @doc """
  Finds all functions that call the specified function.

  ## Parameters
    * `graph` - The graph to search in
    * `function_name` - The name of the function to find callers for (e.g., "String.contains?" or "String.contains?/2")
  """
  @spec find_callers(:digraph.graph() | {:digraph, :digraph.graph()}, String.t()) :: [map()]
  @doc """
  Finds all functions that call the specified function.
  
  The function name can be in several formats:
  - "Module.function"
  - "Module.function/arity"
  - "function" (without module)
  - "function/arity" (without module)
  """
  def find_callers(graph, function_name) when is_binary(function_name) do
    try do
      Logger.debug("find_callers/2 called with function_name: #{inspect(function_name)}")
      Logger.debug("Input graph: #{inspect(graph, pretty: true)}")

      # Normalize graph reference: we expect the full :digraph record
      graph_ref =
        cond do
          is_tuple(graph) and tuple_size(graph) >= 1 and elem(graph, 0) == :digraph -> graph
          true -> raise ArgumentError, message: "Unsupported graph format: expected :digraph record"
        end

      # Locate all target vertices matching the function name
      target_vertices = find_function_vertex(graph_ref, function_name)

      if target_vertices == [] do
        Logger.warning("Could not find target function: #{function_name}")
        []
      else
        # Collect callers for each target vertex
        target_vertices
        |> Enum.flat_map(fn target_vertex ->
          in_edges =
            try do
              :digraph.in_edges(graph_ref, target_vertex)
            rescue
              _ -> []
            end

          Enum.flat_map(in_edges, fn edge ->
            try do
              case :digraph.edge(graph_ref, edge) do
                {^edge, from_vertex, ^target_vertex, _label} ->
                  # Try to get file info if available
                  file =
                    case :digraph.vertex(graph_ref, from_vertex) do
                      {_, %{file: f}} when is_binary(f) -> f
                      _ -> nil
                    end

                  # Extract module and function from the vertex id
                  case from_vertex do
                    {:function, full_name} ->
                      case parse_function_name(full_name) do
                        {module, function, _arity} when is_binary(function) ->
                          [%{module: module, function: function, file: file, full_name: full_name}]
                        _ -> []
                      end
                    _ -> []
                  end
                _ -> []
              end
            rescue
              _ -> []
            end
          end)
        end)
        |> Enum.uniq_by(fn %{module: m, function: f} -> {m, f} end)
      end
    rescue
      e ->
      Logger.error("Error in find_callers/2: #{inspect(e, pretty: true)}")
      []
    end
  end
  
  def find_callers(_, function_name) do
    Logger.error("Invalid function name: #{inspect(function_name)}")
    []
  end

  @doc """
  Finds a function vertex in the graph by its name.
  
  The function name can be in several formats:
  - "Module.function"
  - "Module.function/arity"
  - "function" (without module)
  - "function/arity" (without module)
  """
  defp find_function_vertex(graph_ref, function_name) when is_binary(function_name) do
    try do
      # Parse the input into components
      {input_module, input_fun, input_arity} = parse_function_name(function_name)

      vertices =
        try do
          :digraph.vertices(graph_ref)
        rescue
          _ -> []
        end

      Enum.filter(vertices, fn
        {:function, name} ->
          match_function_name?(name, input_module, input_fun, input_arity)
        _ -> false
      end)
    rescue
      _ -> []
    end
  end
  
  defp parse_function_components(full_name) do
    if String.contains?(full_name, ".") do
      [mod | rest] = String.split(full_name, ".")
      func = Enum.join(rest, ".")
      {mod, String.split(func, "/") |> hd()}
    else
      {nil, String.split(full_name, "/") |> hd()}
    end
  end
  
  defp parse_function_name(full_name) do
    case String.split(full_name, ".") do
      [module, func_with_arity] ->
        case String.split(func_with_arity, "/") do
          [func, arity] -> {module, func, String.to_integer(arity)}
          [func] -> {module, func, nil}
        end
      [func_with_arity] ->
        case String.split(func_with_arity, "/") do
          [func, arity] -> {nil, func, String.to_integer(arity)}
          [func] -> {nil, func, nil}
        end
      _ -> {nil, full_name, nil}
    end
  end

  # Match a function vertex name (e.g., "Module.func/2" or "Module.func/_") against input components
  defp match_function_name?(vertex_name, input_module, input_fun, input_arity) do
    case String.split(vertex_name, "/") do
      [mod_fun, arity_str] ->
        {mod, fun} =
          case String.split(mod_fun, ".", parts: 2) do
            [m, f] -> {m, f}
            [_] -> {nil, mod_fun}
          end

        cond do
          input_module && input_arity ->
            mod == input_module and fun == input_fun and (arity_str == Integer.to_string(input_arity) or arity_str == "_")

          input_module && is_nil(input_arity) ->
            mod == input_module and fun == input_fun

          is_nil(input_module) && input_arity ->
            fun == input_fun and (arity_str == Integer.to_string(input_arity) or arity_str == "_")

          true ->
            fun == input_fun
        end

      _ -> false
    end
  end

  # Helper to detect a type name inside a spec string in various textual forms
  defp spec_contains_type?(spec, type_name) when is_binary(spec) and is_binary(type_name) do
    base = String.trim(type_name)
    base_no_parens = String.trim_trailing(base, "()")
    with_t = if String.ends_with?(base_no_parens, ".t"), do: base_no_parens, else: base_no_parens <> ".t"
    candidates = [base, base_no_parens, with_t, with_t <> "()"]
    Enum.any?(candidates, &String.contains?(spec, &1))
  end

  @doc """
  Finds all implementations of a behaviour in the knowledge base.
  """
  @spec find_implementations(KnowledgeBase.t(), String.t()) :: [map()]
  def find_implementations(knowledge_base, behaviour_name) do
    with {:ok, documents} <- KnowledgeBase.get_all_documents(knowledge_base) do
      # Normalize behaviour name (remove .Behaviour suffix if present)
      base_behaviour = behaviour_name
        |> String.replace(~r/\.?Behaviour$/, "")

      # Try different variations of the behaviour name
      behaviour_variants = [
        base_behaviour,
        base_behaviour <> ".Behaviour",
        "Elixir." <> base_behaviour,
        "Elixir." <> base_behaviour <> ".Behaviour"
      ]

      documents
      |> Enum.flat_map(fn {file_path, %{parsed_content: parsed_content}} ->
        # Check all variants of the behaviour name
        behaviour_variants
        |> Enum.flat_map(fn variant ->
          find_behaviour_implementations(parsed_content, file_path, variant)
        end)
        |> Enum.reject(&is_nil/1)
      end)
      |> Enum.uniq()
    else
      error ->
        Logger.error("Failed to get documents from knowledge base: #{inspect(error)}")
        []
    end
  end

  @doc """
  Finds all types related to the given type name in the knowledge base.
  """
  @spec find_related_types(KnowledgeBase.t() | :digraph.graph(), String.t()) :: [map()]
  def find_related_types(knowledge_base, type_name) when is_pid(knowledge_base) do
    # Given a KnowledgeBase PID, build a fresh relationship graph
    case build_relationship_graph(knowledge_base) do
      {:ok, graph} -> find_related_types_in_graph(graph, type_name)
      _ -> []
    end
  end

  def find_related_types(graph, type_name) when is_tuple(graph) do
    # Given a digraph record, search it directly
    find_related_types_in_graph(graph, type_name)
  end

  defp find_related_types_in_graph(graph, type_name) do
    try do
      # Use the digraph record directly
      graph_ref = graph

      # Find all functions that reference this type in their specs
      :digraph.vertices(graph_ref)
      |> Enum.flat_map(fn
        {:function, full_name} = vertex ->
          # Check if this function's spec references the type
          case :digraph.vertex(graph_ref, vertex) do
            {_, %{spec: spec}} when is_binary(spec) ->
              Logger.debug("[find_related_types] #{full_name} spec: #{inspect(spec)}")
              if spec_contains_type?(spec, type_name) do
                case parse_function_name(full_name) do
                  {mod, fun, _arity} ->
                    [%{name: fun, module: mod, type: :function_with_type_reference, reference_type: :spec}]
                  _ ->
                    [%{name: full_name, type: :function_with_type_reference, reference_type: :spec}]
                end
              else
                []
              end
            _ -> []
          end
        _ -> []
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(fn
        %{type: type, module: m, name: n} when type in [:function_with_type_reference, :function_using_type] ->
          {type, m, n}
        %{type: type, module: m, name: n} ->
          {type, m, n}
      end)
    rescue
      e ->
        Logger.error("Error in find_related_types_in_graph: #{inspect(e)}")
        []
    end
  end

  defp find_behaviour_implementations(%{module: module, attributes: %{behaviour: behaviours}}, file_path, behaviour_name) when is_list(behaviours) do
    # Normalize behaviour name for comparison (remove .Behaviour suffix if present)
    normalized_behaviour = behaviour_name
      |> String.replace(~r/\.?Behaviour$/, "")
      |> String.downcase()

    # Check if any of the behaviours match
    matching_behaviours = behaviours
      |> Enum.flat_map(fn
        behaviour when is_atom(behaviour) -> [behaviour]
        behaviour when is_binary(behaviour) -> [behaviour]
        _ -> []
      end)
      |> Enum.filter(fn behaviour ->
        behaviour_str = behaviour
          |> to_string()
          |> String.replace(~r/^Elixir\.|\.?Behaviour$/, "")  # Remove Elixir. and .Behaviour
          |> String.downcase()

        # Check for exact match or module suffix match
        behaviour_str == normalized_behaviour ||
          String.ends_with?(behaviour_str, "." <> normalized_behaviour) ||
          behaviour_str == "Elixir." <> normalized_behaviour
      end)

    if Enum.any?(matching_behaviours) do
      [%{
        type: :behaviour_implementation,
        module: module,
        function: "#{behaviour_name} callbacks",
        file: file_path,
        behaviour: behaviour_name
      }]
    else
      []
    end
  end

  # Handle binary behaviour name
  defp find_behaviour_implementations(%{module: module, attributes: %{behaviour: behaviour}}, file_path, behaviour_name) when is_binary(behaviour) do
    find_behaviour_implementations(
      %{module: module, attributes: %{behaviour: [behaviour]}},
      file_path,
      behaviour_name
    )
  end

  defp find_behaviour_implementations(%{module: module, attributes: %{behaviour: behaviour}}, file_path, behaviour_name) when is_binary(behaviour) do
    find_behaviour_implementations(%{module: module, attributes: %{behaviour: [behaviour]}}, file_path, behaviour_name)
  end

  defp find_behaviour_implementations(_, _, _), do: []

  defp find_type_references_in_content(%{types: types} = content, file_path, type_name) when is_list(types) do
    # Normalize type name for comparison (remove .t if present and any module prefix)
    type_name = type_name
      |> String.replace(~r/^.*\./, "")  # Remove module prefix if present

    # Remove .t suffix but keep it for matching if it was there
    has_t_suffix = String.ends_with?(type_name, ".t")
    base_type_name = String.replace(type_name, ".t", "")

    # Check type definitions
    type_refs =
      types
      |> Enum.flat_map(fn %{name: name, definition: definition} ->
        def_str = inspect(definition)
        # Match either with or without .t suffix
        if String.contains?(def_str, base_type_name) do
          [%{
            type: :type_reference,
            name: name,
            definition: definition,
            file: file_path,
            module: content.module
          }]
        else
          []
        end
      end)

    # Check function specs and types if functions exist
    func_refs =
      if Map.has_key?(content, :functions) do
        (content.functions || [])
        |> Enum.flat_map(fn %{spec: spec, name: func_name} = func ->
          spec_str = if is_binary(spec), do: spec, else: inspect(spec)

          # Check if function name matches or spec contains the type
          name_matches = String.downcase(func_name) == String.downcase(base_type_name)
          spec_contains_type = spec_str && (
            String.contains?(spec_str, "#{base_type_name}.") ||
            String.contains?(spec_str, "#{base_type_name}.t") ||
            String.contains?(spec_str, "#{base_type_name}()") ||
            String.contains?(spec_str, "{:#{base_type_name},")
          )

          if name_matches || spec_contains_type do
            [%{
              type: :function_with_type_reference,
              name: func_name,
              spec: spec_str,
              file: file_path,
              module: content.module,
              function: func
            }]
          else
            []
          end
        end)
      else
        []
      end

    type_refs ++ func_refs
  end

  defp find_type_references_in_content(_content, _file_path, _type_name), do: []
end
