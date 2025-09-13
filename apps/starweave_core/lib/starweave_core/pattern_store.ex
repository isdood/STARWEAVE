defmodule StarweaveCore.PatternStore do
  @moduledoc """
  Distributed pattern store backed by Mnesia.
  """
  use GenServer

  alias StarweaveCore.Pattern
  alias StarweaveCore.Pattern.Storage.MnesiaPatternStore
  require Logger

  # Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores a pattern in the database.
  """
  @spec put(Pattern.t()) :: :ok | {:error, term()}
  def put(%Pattern{} = pattern) do
    case MnesiaPatternStore.put(pattern) do
      :ok -> :ok
      error -> 
        Logger.error("Failed to store pattern: #{inspect(error)}")
        error
    end
  end

  @doc """
  Retrieves a pattern by ID.
  """
  @spec get(String.t()) :: Pattern.t() | nil
  def get(id) when is_binary(id) do
    case MnesiaPatternStore.get(id) do
      {:ok, pattern} -> pattern
      :not_found -> nil
      error ->
        Logger.error("Failed to retrieve pattern: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Retrieves all patterns, sorted by insertion time (newest first).
  """
  @spec all() :: [Pattern.t()]
  def all do
    case MnesiaPatternStore.all() do
      {:ok, patterns} -> patterns
      error ->
        Logger.error("Failed to retrieve patterns: #{inspect(error)}")
        []
    end
  end

  @doc """
  Deletes all patterns.
  """
  @spec clear() :: :ok
  def clear do
    case MnesiaPatternStore.clear() do
      :ok -> :ok
      error ->
        Logger.error("Failed to clear patterns: #{inspect(error)}")
        :error
    end
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # No ETS table needed anymore
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, %Pattern{} = pattern}, _from, state) do
    {:reply, put(pattern), state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    {:reply, clear(), state}
  end
end
