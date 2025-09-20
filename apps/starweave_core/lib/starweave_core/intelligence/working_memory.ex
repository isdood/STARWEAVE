defmodule StarweaveCore.Intelligence.WorkingMemory do
  @moduledoc """
  A GenServer-based working memory system for maintaining and managing the agent's
  short-term and long-term memory using DETS for persistence. This module provides 
  functionality to store, retrieve, and manage information in a structured way.
  
  The working memory is organized into different contexts (e.g., :conversation, :environment, :goals)
  to allow for better organization and retrieval of information.
  
  Memories are persisted to disk using DETS for reliability.
  """
  
  use GenServer
  require Logger
  
  alias StarweaveCore.Intelligence.Storage.DetsWorkingMemory
  
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
  
  ## Options
    - `:dets_dir` - Directory to store DETS files (default: "priv/data")
    - `:dets_file` - DETS filename (default: "working_memory.dets")
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
  def init(opts) do
    # Store DETS configuration in state
    state = %{
      dets_dir: Keyword.get(opts, :dets_dir, "priv/data"),
      dets_file: Keyword.get(opts, :dets_file, "working_memory.dets")
    }
    
    # Initialize DETS storage
    case DetsWorkingMemory.init() do
      :ok ->
        Logger.info("WorkingMemory initialized successfully")
        # Schedule cleanup of expired entries every hour
        schedule_cleanup()
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("Failed to initialize WorkingMemory: #{inspect(reason)}")
        # Still start the server but in a degraded state
        {:ok, Map.put(state, :degraded, true)}
    end
  end
  
  @impl true
  def handle_cast({:store, _context, _key, _value, _ttl, _importance}, %{degraded: true} = state) do
    # In degraded mode, just log the error
    Logger.error("WorkingMemory is in degraded mode, cannot store data")
    {:noreply, state}
  end
  
  def handle_cast({:store, context, key, value, ttl, importance}, state) do
    case DetsWorkingMemory.store(context, key, value, ttl, importance) do
      :ok ->
        Logger.debug("Stored in working memory: #{inspect(context)}/#{inspect(key)}")
      
      {:error, reason} ->
        Logger.error("Failed to store in working memory: #{inspect(reason)}")
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:forget, _context, _key}, %{degraded: true} = state) do
    # In degraded mode, do nothing
    {:noreply, state}
  end
  
  def handle_cast({:forget, context, key}, state) do
    case DetsWorkingMemory.delete(context, key) do
      :ok ->
        Logger.debug("Forgot key: #{inspect(key)} from context: #{inspect(context)}")
      
      {:error, reason} ->
        Logger.error("Error forgetting key #{inspect(key)} from context #{inspect(context)}: #{inspect(reason)}")
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:clear_context, _context}, %{degraded: true} = state) do
    # In degraded mode, do nothing
    {:noreply, state}
  end
  
  def handle_cast({:clear_context, context}, state) do
    case DetsWorkingMemory.clear_context(context) do
      :ok ->
        Logger.info("Cleared context: #{inspect(context)}")
      
      {:error, reason} ->
        Logger.error("Error clearing context #{inspect(context)}: #{inspect(reason)}")
        
        # Fallback to manual clearing if the context clear failed
        case DetsWorkingMemory.get_context(context) do
          {:ok, entries} ->
            count = length(entries)
            Enum.each(entries, fn {key, _value, _metadata} -> 
              DetsWorkingMemory.delete(context, key) 
            end)
            Logger.info("Manually cleared #{count} entries from context: #{inspect(context)}")
          
          _ ->
            :ok
        end
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call({:retrieve, _context, _key}, _from, %{degraded: true} = state) do
    # In degraded mode, return not found
    {:reply, :not_found, state}
  end
  
  def handle_call({:retrieve, context, key}, _from, state) do
    result = case DetsWorkingMemory.retrieve(context, key) do
      {:ok, value} -> 
        {:ok, value}
        
      :not_found -> 
        :not_found
        
      {:error, reason} ->
        Logger.error("Error retrieving from working memory: #{inspect(reason)}")
        :not_found
        
      other ->
        Logger.error("Unexpected result from DETS retrieve: #{inspect(other)}")
        :not_found
    end
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:get_context, _context}, _from, %{degraded: true} = state) do
    # In degraded mode, return empty list
    {:reply, [], state}
  end
  
  def handle_call({:get_context, context}, _from, state) do
    entries = case DetsWorkingMemory.get_context(context) do
      {:error, reason} ->
        Logger.error("Error getting context from working memory: #{inspect(reason)}")
        []
      
      result when is_list(result) ->
        result
        
      other ->
        Logger.error("Unexpected result from DETS get_context: #{inspect(other)}")
        []
    end
    
    {:reply, entries, state}
  end
  
  @impl true
  def handle_call({:search, _query, _threshold, _limit}, _from, %{degraded: true} = state) do
    # In degraded mode, return empty list
    {:reply, [], state}
  end
  
  def handle_call({:search, query, _threshold, limit}, _from, state) do
    result = 
      case DetsWorkingMemory.search(query) do
        results when is_list(results) ->
          results
          |> Enum.take(limit)
          |> Enum.map(fn {k, v, %{importance: imp}} -> {k, v, imp} end)
        
        {:error, reason} ->
          Logger.error("Error searching working memory: #{inspect(reason)}")
          []
          
        other ->
          Logger.error("Unexpected result from DETS search: #{inspect(other)}")
          []
      end
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:persist_now, _from, state) do
    # No-op with DETS as it handles persistence automatically
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Cleanup is handled automatically by DetsWorkingMemory
    # during retrieval operations
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, state}
  end
  
  # Schedules the next cleanup
  defp schedule_cleanup do
    # Clean up every hour
    Process.send_after(self(), :cleanup, :timer.hours(1))
  end
end
