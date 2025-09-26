defmodule StarweaveCore.Autonomous.Toolbox.CodeSearch do
  @moduledoc """
  Code search functionality for autonomous tool creation.

  Allows STARWEAVE to find relevant code snippets and understand the codebase structure.
  """

  @project_root "/home/isdood/STARWEAVE"

  @doc """
  Searches for code patterns within the project.
  """
  def search_code(query, opts \\ []) do
    file_pattern = Keyword.get(opts, :file_pattern, "**/*.ex")
    context_lines = Keyword.get(opts, :context, 3)

    # Use grep to search for the query
    case System.cmd("grep", [
      "-r", "-n", "-C", Integer.to_string(context_lines),
      "--include=#{file_pattern}",
      query,
      @project_root
    ]) do
      {output, 0} ->
        parse_search_results(output)
      {error_output, _} ->
        {:error, "Search failed: #{error_output}"}
    end
  end

  @doc """
  Finds files containing specific patterns or structures.
  """
  def find_files_by_pattern(pattern, opts \\ []) do
    file_pattern = Keyword.get(opts, :type, "**/*.ex")

    case System.cmd("find", [
      @project_root,
      "-name", file_pattern,
      "-exec", "grep", "-l", pattern, "{}", ";"
    ]) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.trim/1)
      {_, _} ->
        []
    end
  end

  @doc """
  Gets the structure of a specific module or file.
  """
  def analyze_file_structure(file_path) do
    safe_path = StarweaveCore.Autonomous.Toolbox.FileSystem.validate_and_sanitize_path(file_path)

    case StarweaveCore.Autonomous.Toolbox.FileSystem.read_file(safe_path) do
      {:ok, content} ->
        analyze_code_structure(content, file_path)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds similar code patterns or implementations.
  """
  def find_similar_code(functionality_description) do
    # This would use more sophisticated analysis
    # For now, return a simple keyword-based search

    keywords = extract_keywords(functionality_description)

    results = keywords
    |> Enum.flat_map(fn keyword ->
      case search_code(keyword, context: 2) do
        {:ok, results} -> results
        {:error, _} -> []
      end
    end)
    |> Enum.uniq_by(fn {file, _, _} -> file end)

    {:ok, results}
  end

  @doc """
  Gets dependencies and imports for a module.
  """
  def get_module_dependencies(module_name) do
    # Search for the module definition and its dependencies
    case search_code("defmodule #{module_name}") do
      {:ok, [{file_path, line_number, context} | _]} ->
        # Extract dependencies from the file
        analyze_dependencies(file_path, line_number)
      _ ->
        {:error, "Module not found"}
    end
  end

  # Private Functions

  defp parse_search_results(output) do
    lines = String.split(output, "\n")
    results = []

    current_file = nil
    current_context = []

    Enum.reduce(lines, {[], nil, []}, fn line, {results, current_file, current_context} ->
      cond do
        # New file match
        String.match?(line, ~r/--$/) ->
          # Save previous context if exists
          results = if current_file && current_context != [] do
            [{current_file, current_context} | results]
          else
            results
          end

          # Start new context
          {results, String.trim(String.replace_suffix(line, "--", "")), []}

        # Context line
        current_file && String.trim(line) != "" ->
          {results, current_file, [line | current_context]}

        # Empty line or end of context
        true ->
          # Save context if we have one
          results = if current_file && current_context != [] do
            [{current_file, Enum.reverse(current_context)} | results]
          else
            results
          end

          {results, nil, []}
      end
    end)
    |> then(fn {results, _, _} -> {:ok, Enum.reverse(results)} end)
  end

  defp analyze_code_structure(content, file_path) do
    lines = String.split(content, "\n")

    structure = %{
      file_path: file_path,
      modules: extract_modules(lines),
      functions: extract_functions(lines),
      imports: extract_imports(lines),
      aliases: extract_aliases(lines),
      line_count: length(lines)
    }

    {:ok, structure}
  end

  defp extract_modules(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} ->
      String.match?(line, ~r/^\s*defmodule\s+/)
    end)
    |> Enum.map(fn {line, index} ->
      module_name = Regex.run(~r/defmodule\s+([^\s]+)/, line)
      |> case do
        [_, name] -> name
        _ -> "Unknown"
      end

      {module_name, index + 1}
    end)
  end

  defp extract_functions(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} ->
      String.match?(line, ~r/^\s*def\s+/)
    end)
    |> Enum.map(fn {line, index} ->
      func_name = Regex.run(~r/def\s+([^\s(]+)/, line)
      |> case do
        [_, name] -> name
        _ -> "Unknown"
      end

      {func_name, index + 1}
    end)
  end

  defp extract_imports(lines) do
    lines
    |> Enum.filter(fn line ->
      String.match?(line, ~r/^\s*import\s+/)
    end)
    |> Enum.map(fn line ->
      Regex.run(~r/import\s+([^\s,]+)/, line)
      |> case do
        [_, module] -> module
        _ -> "Unknown"
      end
    end)
  end

  defp extract_aliases(lines) do
    lines
    |> Enum.filter(fn line ->
      String.match?(line, ~r/^\s*alias\s+/)
    end)
    |> Enum.map(fn line ->
      Regex.run(~r/alias\s+([^\s,]+)/, line)
      |> case do
        [_, module] -> module
        _ -> "Unknown"
      end
    end)
  end

  defp analyze_dependencies(file_path, start_line) do
    case StarweaveCore.Autonomous.Toolbox.FileSystem.read_file(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        relevant_lines = lines
        |> Enum.slice(max(0, start_line - 20)..min(length(lines) - 1, start_line + 50))

        %{
          imports: extract_imports(relevant_lines),
          aliases: extract_aliases(relevant_lines),
          dependencies: extract_dependencies_from_lines(relevant_lines)
        }
      {:error, _} ->
        %{imports: [], aliases: [], dependencies: []}
    end
  end

  defp extract_dependencies_from_lines(lines) do
    # Extract module dependencies from use, require, import statements
    lines
    |> Enum.flat_map(fn line ->
      regexes = [
        ~r/use\s+([^\s,]+)/,
        ~r/require\s+([^\s,]+)/,
        ~r/import\s+([^\s,]+)/
      ]

      regexes
      |> Enum.flat_map(fn regex ->
        Regex.scan(regex, line)
        |> Enum.map(fn [_, module] -> module end)
      end)
    end)
    |> Enum.uniq()
  end

  defp extract_keywords(description) do
    description
    |> String.downcase()
    |> String.split(~r/[^a-zA-Z0-9]+/)
    |> Enum.filter(fn word -> String.length(word) > 3 end)
    |> Enum.take(10)
  end
end
