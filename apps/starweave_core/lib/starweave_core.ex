defmodule StarweaveCore do
  @moduledoc """
  Documentation for `StarweaveCore`.
  """

  alias StarweaveCore.{Pattern, PatternStore, PatternMatcher}

  @doc """
  Add or upsert a pattern into the store.
  """
  @spec add_pattern(String.t(), String.t(), keyword()) :: :ok
  def add_pattern(id, data, opts \\ []) when is_binary(id) and is_binary(data) do
    pattern = %{
      id: id,
      data: data,
      metadata: Keyword.get(opts, :metadata, %{}),
      energy: Keyword.get(opts, :energy, 0.0)
    }

    PatternStore.put(id, pattern)
  end

  @doc """
  Get a pattern by id.
  """
  @spec get_pattern(String.t()) :: Pattern.t() | nil
  def get_pattern(id), do: PatternStore.get(id)

  @doc """
  Find matching patterns for a query string.
  """
  @spec match(String.t(), keyword()) :: [Pattern.t()]
  def match(query, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :contains)
    PatternStore.all() |> PatternMatcher.match(query, strategy: strategy)
  end
end
