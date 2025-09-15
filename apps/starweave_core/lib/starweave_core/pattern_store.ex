defmodule StarweaveCore.PatternStore do
  @moduledoc """
  Pattern store backed by DETS for persistence.
  
  This module provides a simple key-value store for patterns using DETS.
  Each pattern is stored with a unique ID as the key and the pattern data as the value.
  """
  use GenServer
  require Logger

  alias StarweaveCore.Pattern.Storage.DetsPatternStore

  # Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores a pattern in the database.
  
  ## Parameters
    - `id`: The unique identifier for the pattern
    - `pattern_data`: The pattern data to store (should be a map)
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec put(String.t(), map()) :: :ok | {:error, term()}
  def put(id, pattern_data) when is_binary(id) and is_map(pattern_data) do
    GenServer.call(__MODULE__, {:put, id, pattern_data})
  end

  @doc """
  Retrieves a pattern by ID.
  
  Returns `{:ok, pattern_data}` if found, `:not_found` if not found,
  or `{:error, reason}` on failure.
  """
  @spec get(String.t()) :: {:ok, map()} | :not_found | {:error, term()}
  def get(id) when is_binary(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  @doc """
  Retrieves all patterns.
  
  Returns a list of `{id, pattern_data}` tuples.
  """
  @spec all() :: [{String.t(), map()}]
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc """
  Deletes a pattern by ID.
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(id) when is_binary(id) do
    GenServer.call(__MODULE__, {:delete, id})
  end

  @doc """
  Deletes all patterns.
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec clear() :: :ok | {:error, term()}
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Initialize DETS table
    case DetsPatternStore.init() do
      :ok -> 
        {:ok, %{}}
      error ->
        Logger.error("Failed to initialize PatternStore: #{inspect(error)}")
        {:stop, error}
    end
  end

  @impl true
  def handle_call({:put, id, pattern_data}, _from, state) do
    result = DetsPatternStore.put(id, pattern_data)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    result = DetsPatternStore.get(id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:all, _from, state) do
    result = case DetsPatternStore.all() do
      {:ok, patterns} -> patterns
      error ->
        Logger.error("Failed to get all patterns: #{inspect(error)}")
        []
    end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete, id}, _from, state) do
    result = DetsPatternStore.delete(id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    result = DetsPatternStore.clear()
    {:reply, result, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Close the DETS table when the GenServer terminates
    DetsPatternStore.close()
    :ok
  end
end
