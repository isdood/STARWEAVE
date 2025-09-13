defmodule StarweaveCore.Intelligence.WorkingMemory do
  @moduledoc """
  A GenServer-based working memory system for maintaining and managing the agent's
  short-term and long-term memory using Mnesia for persistence. This module provides 
  functionality to store, retrieve, and manage information in a structured way.
  
  The working memory is organized into different contexts (e.g., :conversation, :environment, :goals)
  to allow for better organization and retrieval of information.
  
  Memories are persisted to disk and replicated across nodes in the cluster.
  """
  
  use GenServer
  require Logger
  
  alias :mnesia, as: Mnesia
  alias StarweaveCore.Intelligence.Storage.MnesiaWorkingMemory
  
  @default_ttl :timer.hours(24)  # 24 hours default TTL
  
  @type context :: atom()
  @type memory_key :: atom() | String.t()
  @type memory_value :: any()
  @type ttl :: non_neg_integer() | :infinity
  @type memory_entry :: %{
    value: memory_value(),
    timestamp: DateTime.t(),
    ttl: ttl(),
    importance: float()
  }

  # Client API
  
  @doc """
  Starts the WorkingMemory GenServer.
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Stores a value in working memory with the given key and context.
  
  ## Parameters
    - `context`: The context of the memory (e.g., :conversation, :environment)
    - `key`: The key to store the value under
    - `value`: The value to store
    - `opts`: Additional options
      - `:ttl`: Time to live in milliseconds (default: #{@default_ttl})
      - `:importance`: Importance score (0.0 to 1.0, default: 0.5)
  """
  @spec store(context(), memory_key(), memory_value(), keyword()) :: :ok
  def store(context, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    importance = Keyword.get(opts, :importance, 0.5)
    
    Logger.debug("Storing in working memory: #{inspect(context)}/#{inspect(key)}")
    GenServer.cast(__MODULE__, {:store, context, key, value, ttl, importance})
  end
  
  @doc """
  Retrieves a value from working memory by context and key.
  
  Returns `{:ok, value}` if found, or `:not_found` otherwise.
  """
  @spec retrieve(context(), memory_key()) :: {:ok, memory_value()} | :not_found
  def retrieve(context, key) do
    GenServer.call(__MODULE__, {:retrieve, context, key})
  end
  
  @doc """
  Retrieves all memories for a given context, sorted by recency and importance.
  
  Returns a list of `{key, value, metadata}` tuples.
  """
  @spec get_context(context()) :: [{memory_key(), memory_value(), map()}]
  def get_context(context) do
    GenServer.call(__MODULE__, {:get_context, context})
  end
  
  @doc """
  Forgets a specific memory by context and key.
  """
  @spec forget(context(), memory_key()) :: :ok
  def forget(context, key) do
    GenServer.cast(__MODULE__, {:forget, context, key})
  end
  
  @doc """
  Clears all memories in a specific context.
  """
  @spec clear_context(context()) :: :ok
  def clear_context(context) do
    GenServer.cast(__MODULE__, {:clear_context, context})
  end
  
  @doc """
  Performs a similarity-based search across all memories.
  
  Returns a list of `{key, value, score}` tuples sorted by relevance.
  """
  @spec search(String.t(), keyword()) :: [{memory_key(), memory_value(), float()}]
  def search(query, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.3)
    limit = Keyword.get(opts, :limit, 10)
    GenServer.call(__MODULE__, {:search, query, threshold, limit})
  end
  
  @doc """
  Manually triggers persistence of all current memories to disk.
  This is a no-op with Mnesia as it handles persistence automatically.
  """
  @spec persist_now() :: :ok
  def persist_now do
    GenServer.call(__MODULE__, :persist_now)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    # Start Mnesia if not already started
    case Mnesia.start() do
      :ok -> :ok
      {:error, {:already_started, :mnesia}} -> :ok
      error -> 
        Logger.error("Failed to start Mnesia: #{inspect(error)}")
        raise "Failed to start Mnesia: #{inspect(error)}"
    end
    
    # Ensure the working memory table exists
    case ensure_table() do
      :ok -> 
        Logger.info("WorkingMemory initialized successfully")
        {:ok, %{}}
      error ->
        Logger.error("Failed to initialize WorkingMemory: #{inspect(error)}")
        {:stop, error}
    end
  end
  
  @impl true
  def handle_cast({:store, context, key, value, ttl, importance}, state) do
    # Delegate to the Mnesia storage module
    case MnesiaWorkingMemory.store(context, key, value, [ttl: ttl, importance: importance]) do
      :ok -> 
        Logger.debug("Stored in Mnesia: #{inspect({context, key})}")
      error ->
        Logger.error("Failed to store in Mnesia: #{inspect(error)}")
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:forget, context, key}, state) do
    case MnesiaWorkingMemory.delete(context, key) do
      :ok -> 
        Logger.debug("Forgot memory: #{inspect({context, key})}")
      error -> 
        Logger.error("Failed to forget memory: #{inspect(error)}")
    end
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:clear_context, context}, state) do
    case MnesiaWorkingMemory.get_context(context) do
      {:ok, entries} ->
        count = length(entries)
        Enum.each(entries, fn %{key: key} -> MnesiaWorkingMemory.delete(context, key) end)
        Logger.debug("Cleared #{count} entries from context: #{inspect(context)}")
      error ->
        Logger.error("Failed to clear context: #{inspect(error)}")
    end
    {:noreply, state}
  end
  
  @impl true
  def handle_call({:retrieve, context, key}, _from, state) do
    result = 
      case MnesiaWorkingMemory.retrieve(context, key) do
        {:ok, value} -> {:ok, value}
        :not_found -> :not_found
        error -> 
          Logger.error("Error retrieving from working memory: #{inspect(error)}")
          :not_found
      end
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:get_context, context}, _from, state) do
    result = 
      case MnesiaWorkingMemory.get_context(context) do
        {:ok, entries} -> 
          entries
          |> Enum.map(fn %{key: k, value: v, metadata: m} -> {k, v, m} end)
          |> Enum.sort_by(
            fn {_k, _v, %{importance: i, inserted_at: t}} -> 
              {i, -DateTime.to_unix(DateTime.from_unix!(div(t, 1000)))}
            end,
            :desc
          )
        error ->
          Logger.error("Error getting context from working memory: #{inspect(error)}")
          []
      end
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:search, query, _threshold, limit}, _from, state) do
    result = 
      case MnesiaWorkingMemory.search(query, limit: limit) do
        {:ok, results} ->
          results
          |> Enum.take(limit)
          |> Enum.map(fn %{key: k, value: v, metadata: m} -> {k, v, m.importance} end)
        error ->
          Logger.error("Error searching working memory: #{inspect(error)}")
          []
      end
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:persist_now, _from, state) do
    # No-op with Mnesia as it handles persistence automatically
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_info(msg, state) do
    # Handle any periodic tasks or cleanup if needed
    case msg do
      _ ->
        Logger.warning("Received unknown message: #{inspect(msg)}")
        {:noreply, state}
    end
  end
  
  defp ensure_table do
    # The table is created by the Mnesia schema, just verify it exists
    case Mnesia.table_info(:working_memory, :all) do
      {:aborted, {:no_exists, _}} ->
        Logger.error("Mnesia table :working_memory does not exist")
        {:error, :table_not_found}
      _ ->
        :ok
    end
  end
end
