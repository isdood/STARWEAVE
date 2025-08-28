defmodule StarweaveCore.PatternMatcher do
  @moduledoc """
  Basic pattern matching strategies.
  """

  alias StarweaveCore.Pattern

  @type match_option :: {:strategy, :exact | :contains | :jaccard}

  @spec match([Pattern.t()], String.t(), [match_option]) :: [Pattern.t()]
  def match(patterns, query, opts \\ []) when is_list(patterns) and is_binary(query) do
    strategy = Keyword.get(opts, :strategy, :contains)

    scored =
      for %Pattern{} = p <- patterns do
        score = score(p.data, query, strategy)
        {score, p}
      end
      |> Enum.filter(fn {s, _} -> s > 0 end)
      |> Enum.sort_by(fn {s, _} -> -s end)

    Enum.map(scored, fn {_s, p} -> p end)
  end

  defp score(data, query, :exact) when is_binary(data), do: if(data == query, do: 1.0, else: 0.0)
  defp score(data, query, :contains) when is_binary(data), do: if(String.contains?(data, query), do: 1.0, else: 0.0)
  defp score(data, query, :jaccard) when is_binary(data) do
    a = tokenize(data)
    b = tokenize(query)
    jaccard(a, b)
  end
  defp score(_, _, _), do: 0.0

  defp tokenize(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s]+/u, " ")
    |> String.split()
    |> MapSet.new()
  end

  defp jaccard(a, b) do
    inter = MapSet.size(MapSet.intersection(a, b))
    uni = MapSet.size(MapSet.union(a, b))
    if uni == 0, do: 0.0, else: inter / uni
  end
end


