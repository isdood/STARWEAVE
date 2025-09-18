defmodule StarweaveLlm.LLM.ComplexQueryParser do
  @moduledoc """
  Handles parsing of complex natural language queries with multiple intents.
  
  This module is responsible for breaking down complex queries into individual
  intents that can be processed separately by the query service.
  """

  @doc """
  Parses a complex query into a list of intents.
  
  ## Examples
      iex> ComplexQueryParser.parse("find all functions and then explain them")
      {:ok, [
        %{type: :search, content: "find all functions"},
        %{type: :explain, content: "them"}
      ]}
  """
  @spec parse(String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def parse(query) when is_binary(query) do
    query
    |> String.downcase()
    |> split_into_segments()
    |> Enum.map(&parse_intent/1)
    |> Enum.map(fn {type, content} -> %{type: type, content: String.trim(content)} end)
    |> combine_continuations()
    |> wrap_in_ok()
  end

  @doc """
  Parses a single query segment into an intent.
  
  ## Examples
      iex> ComplexQueryParser.parse_intent("explain this function")
      {:explain, "this function"}
      
      iex> ComplexQueryParser.parse_intent("search for tests")
      {:search, "search for tests"}
  """
  @spec parse_intent(String.t()) :: {atom(), String.t()}
  def parse_intent(segment) do
    cond do
      String.starts_with?(segment, "explain") -> 
        {:explain, String.replace_prefix(segment, "explain", "")}
      String.starts_with?(segment, "what is") ->
        {:explain, String.replace_prefix(segment, "what is", "")}
      String.starts_with?(segment, "how does") ->
        {:explain, String.replace_prefix(segment, "how does", "")}
      String.starts_with?(segment, "find") ->
        {:search, segment}
      String.starts_with?(segment, ["search for", "look for", "show me"]) ->
        {:search, segment}
      String.starts_with?(segment, ["optimize", "improve", "refactor"]) ->
        {:optimize, segment}
      String.starts_with?(segment, ["run", "execute", "test"]) ->
        {:execute, segment}
      true ->
        {:search, segment}
    end
  end

  # Splits the query into segments based on conjunctions
  defp split_into_segments(query) do
    query
    |> String.split(~r/\s+(?:and|then|after that|next|,|;|\n)\s+|(?<=\w)\.\s+/i, trim: true)
    |> Enum.map(&String.trim/1)
  end

  # Handles continuations like "them" or "it" that refer to previous results
  defp combine_continuations(intents) do
    Enum.reduce(intents, [], fn
      %{content: _content} = intent, [] ->
        [intent]
        
      %{content: content} = intent, acc ->
        case String.downcase(String.trim(content)) do
          "it" <> rest ->
            [prev | rest_acc] = acc
            [%{prev | content: "#{prev.content} #{String.trim(rest)}"} | rest_acc]
            
          "them" <> rest ->
            [prev | rest_acc] = acc
            [%{prev | content: "#{prev.content} #{String.trim(rest)}"} | rest_acc]
            
          _ ->
            [intent | acc]
        end
    end)
    |> Enum.reverse()
  end

  defp wrap_in_ok([]), do: {:error, "No valid intents found in query"}
  defp wrap_in_ok(intents) when is_list(intents), do: {:ok, intents}
end
