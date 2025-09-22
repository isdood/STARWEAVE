defmodule StarweaveLlm.SelfKnowledge.ElixirCodeParser do
  @moduledoc """
  Parses Elixir source code to extract structured information including:
  - Module documentation
  - Function documentation and specs
  - Type definitions
  - Module attributes
  - Cross-references between modules and functions
  """

  require Logger

  @doc """
  Parses Elixir source code and extracts structured information.
  Returns a map with the extracted information.
  """
  @spec parse(String.t(), String.t()) :: map()
  def parse(source, file_path) do
    {module_name, _} = extract_module_name(source, file_path)
    
    %{
      module: module_name,
      file: file_path,
      content: source,
      docs: extract_docs(source),
      functions: extract_functions(source),
      types: extract_types(source),
      attributes: extract_attributes(source),
      references: extract_references(source, module_name),
      metadata: %{
        parsed_at: DateTime.utc_now(),
        source_language: "elixir"
      }
    }
  end

  # Extracts the module name from the source code
  defp extract_module_name(source, file_path) do
    case Regex.run(~r/defmodule\s+([A-Z]\w*(?:\.[A-Z]\w*)*)/, source) do
      [_, module_name] -> {module_name, nil}
      _ -> 
        module_name = Path.basename(file_path) 
                      |> String.replace(".ex", "") 
                      |> String.split("_") 
                      |> Enum.map_join(".", &String.capitalize/1)
        {module_name, :unknown}
    end
  end

  # Extracts module and function documentation
  defp extract_docs(source) do
    lines = String.split(source, "\n")
    {doc_state, _rest} = do_extract_docs(lines, %{module: nil, next_doc: nil, next_spec: nil, funcs: []})
    %{
      module: doc_state.module,
      functions: Enum.reverse(doc_state.funcs)
    }
  end

  defp do_extract_docs([], %{module: mod, next_doc: next_doc, next_spec: spec, funcs: acc}) do
    # If a trailing doc/spec without a def exists, ignore it for functions list
    {%{module: mod, next_doc: next_doc, next_spec: spec, funcs: acc}, []}
  end

  defp do_extract_docs([line | rest], state) do
    cond do
      String.match?(line, ~r/^\s*@moduledoc\s+"""/) ->
        {content, remaining} = extract_heredoc(rest)
        mod_doc = %{type: :moduledoc, content: content}
        do_extract_docs(remaining, %{state | module: mod_doc})

      String.match?(line, ~r/^\s*@moduledoc\s+"([^"]*)"\s*$/) ->
        [_, short] = Regex.run(~r/^\s*@moduledoc\s+"([^"]*)"\s*$/, line)
        mod_doc = %{type: :moduledoc, content: short}
        do_extract_docs(rest, %{state | module: mod_doc})

      String.match?(line, ~r/^\s*@doc\s+"""/) ->
        {content, remaining} = extract_heredoc(rest)
        do_extract_docs(remaining, %{state | next_doc: content})

      String.match?(line, ~r/^\s*@doc\s+"([^"]*)"\s*$/) ->
        [_, short] = Regex.run(~r/^\s*@doc\s+"([^"]*)"\s*$/, line)
        do_extract_docs(rest, %{state | next_doc: short})

      String.match?(line, ~r/^\s*@spec\s+/) ->
        spec = String.trim_leading(line)
        do_extract_docs(rest, %{state | next_spec: spec})

      String.match?(line, ~r/^\s*defp?\s+[a-z_]\w*[?!]?\s*\(/) ->
        # Attach any pending @doc to the function docs list
        funcs = if state.next_doc do
          [%{content: state.next_doc} | state.funcs]
        else
          state.funcs
        end
        do_extract_docs(rest, %{state | next_doc: nil, next_spec: nil, funcs: funcs})

      true ->
        do_extract_docs(rest, state)
    end
  end
  
  defp count_args(line) do
    case Regex.run(~r/\(([^)]*)\)/, line) do
      [_, args] -> length(String.split(args, ",", trim: true))
      _ -> 0
    end
  end
  
  # Extract heredoc content until a closing triple quote (""") line.
  defp extract_heredoc(lines), do: do_extract_heredoc(lines, [])

  defp do_extract_heredoc([], acc), do: {String.trim(Enum.join(Enum.reverse(acc), "\n")), []}
  defp do_extract_heredoc([line | rest], acc) do
    case String.split(line, ~s/"""/, parts: 2) do
      [before, _after] ->
        # Found closing delimiter on this line; include content before it and stop
        content = [before | acc] |> Enum.reverse() |> Enum.join("\n") |> String.trim()
        {content, rest}
      _ ->
        do_extract_heredoc(rest, [line | acc])
    end
  end

  # Extracts function definitions with enhanced metadata
  defp extract_functions(source) do
    source
    |> String.split("\n")
    |> Enum.reduce({[], nil, nil, 1}, &process_function_line/2)
    |> (fn {functions, _, _, _} -> Enum.reverse(functions) end).()
  end
  
  defp process_function_line(line, {functions, current_doc, current_spec, line_num}) do
    cond do
      # Function definition with enhanced parsing
      String.match?(line, ~r/^\s*def(p?)\s+([a-z_]\w*[?!]?)/) ->
        [_, visibility, func_name] = Regex.run(~r/^\s*def(p?)\s+([a-z_]\w*[?!]?)/, line)
        arity = count_args(line)
        
        # Enhanced metadata extraction
        # Extract parameter types from spec if available
        param_types = extract_param_types(current_spec)
        return_type = extract_return_type(current_spec)
        
        # Build the function info with all metadata
        func_info = %{
          name: func_name,
          arity: arity,
          line: line_num,
          param_types: param_types,
          return_type: return_type
        }
        
        # Add the function to the list and reset the spec
        {[func_info | functions], current_doc, nil, line_num + 1}
        
      # Function spec with enhanced parsing
      String.match?(line, ~r/^\s*@spec\s+/) ->
        spec = String.trim(line)
        {functions, current_doc, spec, line_num + 1}
        
      # Other lines
      true ->
        {functions, current_doc, current_spec, line_num + 1}
    end
  end

  # Enhanced type extraction with more metadata
  defp extract_types(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_num}, acc ->
      cond do
        # Type definition with enhanced metadata
        String.match?(line, ~r/^\s*@type(p)?\s+(\w+)\s*::/) ->
          [_, visibility, type_name] = Regex.run(~r/^\s*@type(p)?\s+(\w+)\s*::/, line)
          [type_def] = Regex.run(~r/@type(?:p)?\s+\w+\s*::.*$/, line)
          
          [%{
            name: String.to_atom(type_name),
            definition: String.trim(type_def),
            line: line_num,
            visibility: if(visibility == "p", do: :private, else: :public)
          } | acc]
        
        true ->
          acc
      end
    end)
  end

  # Extracts module attributes
  defp extract_attributes(source) do
    Regex.scan(
      ~r/@(\w+)(?:\s+(.*?))?\s*$/m,
      source,
      capture: :all_but_first
    )
    |> Enum.map(fn [name, value] ->
      {String.to_atom(name), value && String.trim(value)}
    end)
    |> Enum.into(%{})
  end

  # Extracts cross-references to other modules and functions
  defp extract_references(source, current_module) do
    # Find all module references (e.g., Module.function/1)
    module_refs = 
      Regex.scan(~r/([A-Z]\w*(?:\.[A-Z]\w*)*)\.\w+\/?\d*/, source)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.reject(&(&1 == to_string(current_module)))
    
    # Find all function calls within the same module
    function_refs = 
      Regex.scan(~r/(?<!\.)\b(?!def\s+)([a-z_]\w*!?\??)\s*(?=\()/, source)
      |> List.flatten()
      |> Enum.uniq()
    
    %{
      modules: module_refs,
      functions: function_refs
    }
  end

  # Extracts function parameter types from a spec string
  defp extract_param_types(spec) when is_binary(spec) do
    case Regex.run(~r/\w+\(([^)]*)\)\s*::\s*([^\n]+)/, spec) do
      [_, params, _] -> 
        params 
        |> String.split(",") 
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn param ->
          param
          |> String.split("::")
          |> List.last()
          |> String.trim()
        end)
      _ -> []
    end
  end
  
  defp extract_param_types(_), do: []

  # Extracts the return type from a spec string
  defp extract_return_type(spec) when is_binary(spec) do
    case Regex.run(~r/::\s*([^\n]+)/, spec) do
      [_, return_type] -> String.trim(return_type)
      _ -> "any()"
    end
  end
  
  defp extract_return_type(_), do: "any()"
  
  # Counts the number of arguments in a function definition
  defp count_args(line) do
    case Regex.run(~r/\(([^)]*)\)/, line) do
      [_, args] -> 
        args 
        |> String.split(",") 
        |> Enum.count(&(String.trim(&1) != ""))
      _ -> 0
    end
  end

  # Helper to parse function arguments
  defp parse_args(args) do
    args
    |> String.replace(~r/[()]/, "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  # Helper to parse function guards
  defp parse_guards(nil), do: []
  defp parse_guards(guards_string) do
    guards_string
    |> String.split("and", trim: true)
    |> Enum.map(&String.trim/1)
  end

  # Helper to find the line number of a string in the source
  defp find_line(source, pattern) when is_binary(source) do
    source
    |> String.split("\n")
    |> Enum.find_index(&String.contains?(&1, pattern))
    |> case do
      nil -> 1
      idx -> idx + 1
    end
  end
  
  defp find_line(_, _), do: 1
end
