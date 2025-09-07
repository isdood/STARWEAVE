defmodule StarweaveCore.Intelligence.WorkingMemory do
  @moduledoc """
  A GenServer-based working memory system for maintaining and managing the agent's
  short-term and long-term memory using ETS for persistence. This module provides 
  functionality to store, retrieve, and manage information in a structured way.
  
  The working memory is organized into different contexts (e.g., :conversation, :environment, :goals)
  to allow for better organization and retrieval of information.
  
  Memories are persisted to disk to survive application restarts.
  """
  
  use GenServer
  require Logger
  
  alias StarweaveCore.Intelligence.MemoryPersistence
  
  @table_name :starweave_working_memory
  @cleanup_interval 60_000  # 60 seconds
  @default_ttl :timer.hours(24)  # 24 hours default TTL
  @persist_interval 5_000  # 5 seconds between persistence operations
  
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
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec persist_now() :: :ok | {:error, term()}
  def persist_now do
    GenServer.call(__MODULE__, :persist_now)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    # Create ETS table if it doesn't exist
    _table = 
      case :ets.info(@table_name) do
        :undefined ->
          :ets.new(@table_name, [
            :set,
            :named_table,
            :public,
            {:read_concurrency, true},
            {:write_concurrency, true},
            # Persist the table even if the owner dies
            {:heir, Process.whereis(:init), []},
            # Compress terms to save memory
            :compressed
          ])
        _ ->
          @table_name
      end
    
    # Load any persisted memories
    :ok = load_persisted_memories()
    
    # Schedule the first cleanup and persistence
    cleanup_ref = Process.send_after(self(), :cleanup, @cleanup_interval)
    persist_ref = Process.send_after(self(), :persist_memories, @persist_interval)
    
    {:ok, %{
      cleanup_ref: cleanup_ref,
      persist_ref: persist_ref,
      last_persist_count: 0
    }}
  end
  
  @impl true
  def handle_cast({:store, context, key, value, ttl, importance}, state) do
    now = DateTime.utc_now()
    expires_at = if is_integer(ttl), do: DateTime.add(now, ttl, :millisecond), else: :infinity
    
    entry = %{
      value: value,
      timestamp: now,
      ttl: ttl,
      expires_at: expires_at,
      importance: importance,
      context: context,
      key: key
    }
    
    Logger.debug("Storing entry: #{inspect({context, key})} with TTL: #{inspect(ttl)}")
    
    # Store in ETS with a composite key of {context, key}
    true = :ets.insert(@table_name, {{context, key}, entry})
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(msg, state) do
    case msg do
      :persist_memories ->
        handle_persist_memories(state)
      
      :cleanup ->
        handle_cleanup(state)
      
      _ ->
        Logger.warning("Received unknown message: #{inspect(msg)}")
        {:noreply, state}
    end
  end
  
  defp handle_persist_memories(%{last_persist_count: last_count} = state) do
    entries = :ets.match_object(@table_name, :_)
    current_count = length(entries)
    
    # Only persist if there are changes
    if current_count != last_count do
      case MemoryPersistence.save_memories(entries) do
        :ok ->
          Logger.debug("Persisted #{current_count} memories to disk")
        {:error, reason} ->
          Logger.error("Failed to persist memories: #{inspect(reason)}")
      end
    end
    
    # Schedule next persistence check
    persist_ref = Process.send_after(self(), :persist_memories, @persist_interval)
    {:noreply, %{state | persist_ref: persist_ref, last_persist_count: current_count}}
  end
  
  defp handle_cleanup(%{cleanup_ref: _} = state) do
    now = DateTime.utc_now()
    
    # Get all entries and process them
    entries = :ets.match_object(@table_name, :_)
    
    {deleted_count, updated_count} = 
      Enum.reduce(entries, {0, 0}, fn {{context, key}, %{expires_at: expires_at} = entry}, {del, upd} ->
        cond do
          # Delete if expired
          expires_at != :infinity && DateTime.compare(now, expires_at) == :gt ->
            Logger.debug("Deleting expired entry: #{inspect({context, key})}")
            :ets.delete(@table_name, {context, key})
            {del + 1, upd}
            
          # Keep important entries even if they would expire
          entry.importance > 0.8 ->
            # Extend TTL for important entries
            new_expires_at = DateTime.add(now, div(entry.ttl, 2), :millisecond)
            :ets.update_element(@table_name, {context, key}, 
              {2, %{entry | expires_at: new_expires_at}})
            {del, upd + 1}
            
          true ->
            # Keep the entry
            {del, upd}
        end
      end)
      
    # Log cleanup results if there were changes
    if deleted_count > 0 || updated_count > 0 do
      Logger.debug("Memory cleanup: #{deleted_count} entries deleted, #{updated_count} entries updated")
    end
    
    # Schedule next cleanup
    cleanup_ref = Process.send_after(self(), :cleanup, @cleanup_interval)
    {:noreply, %{state | cleanup_ref: cleanup_ref}}
  end
  
  @impl true
  def handle_call({:retrieve, context, key}, _from, state) do
    result = 
      case :ets.lookup(@table_name, {context, key}) do
        [{{^context, ^key}, %{value: value, expires_at: expires_at}}] ->
          # Check if the entry has expired
          if expires_at == :infinity or DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
            {:ok, value}
          else
            # Entry has expired, clean it up
            :ets.delete(@table_name, {context, key})
            :not_found
          end
        _ ->
          :not_found
      end
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:get_context, context}, _from, state) do
    now = DateTime.utc_now()
    
    # Match all entries for this context
    result = 
      :ets.match_object(@table_name, {{context, :_}, :_})
      |> Enum.filter(fn {{_ctx, _key}, %{expires_at: expires_at}} ->
          expires_at == :infinity or DateTime.compare(now, expires_at) == :lt
      end)
      |> Enum.map(fn {{_ctx, key}, %{value: value} = meta} ->
          {key, value, Map.drop(meta, [:value, :expires_at])}
      end)
      |> Enum.sort_by(
        fn {_key, _value, %{timestamp: ts, importance: imp}} -> 
          # Sort by recency and importance
          DateTime.to_unix(ts) * imp
        end,
        :desc
      )
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:search, query, threshold, limit}, _from, state) do
    now = DateTime.utc_now()
    
    results = 
      :ets.match_object(@table_name, {:_, :_})
      |> Enum.filter(fn {{_ctx, _key}, %{expires_at: expires_at}} ->
          expires_at == :infinity or DateTime.compare(now, expires_at) == :lt
      end)
      |> Enum.flat_map(fn {{context, key}, %{value: value} = meta} ->
        score = jaccard_similarity(query, to_string(key) <> " " <> to_string(value))
        if score >= threshold do
          [{context, key, value, score, meta}]
        else
          []
        end
      end)
      |> Enum.sort_by(fn {_c, _k, _v, score, _m} -> -score end)
      |> Enum.take(limit)
      |> Enum.map(fn {context, k, v, score, _m} -> {context, k, v, score} end)
    
    {:reply, results, state}
  end
  
  @impl true
  def handle_call(:persist_now, _from, %{last_persist_count: _} = state) do
    entries = :ets.match_object(@table_name, :_)
    
    case MemoryPersistence.save_memories(entries) do
      :ok ->
        Logger.info("Manually persisted #{length(entries)} memories to disk")
        {:reply, :ok, %{state | last_persist_count: length(entries)}}
      error ->
        Logger.error("Failed to persist memories: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  # Load persisted memories into ETS
  defp load_persisted_memories do
    case StarweaveCore.Intelligence.MemoryPersistence.load_memories() do
      entries when is_list(entries) and entries != [] ->
        Logger.info("Loading #{length(entries)} persisted memories from disk")
        
        # Insert all entries into ETS
        Enum.each(entries, fn {key, value} ->
          :ets.insert(@table_name, {key, value})
        end)
        
        Logger.info("Successfully loaded #{length(entries)} memories into ETS")
        :ok
        
      _ ->
        Logger.info("No persisted memories found to load")
        :ok
    end
  end
  
  
  # Helper functions
  
  @doc """
  Calculates Jaccard similarity between two strings.
  Returns a value between 0.0 (no similarity) and 1.0 (identical).
  """
  @spec jaccard_similarity(String.t(), String.t()) :: float()
  def jaccard_similarity(a, b) do
    set_a = a |> String.downcase() |> String.graphemes() |> MapSet.new()
    set_b = b |> String.downcase() |> String.graphemes() |> MapSet.new()
    
    intersection_size = MapSet.intersection(set_a, set_b) |> MapSet.size()
    union_size = MapSet.union(set_a, set_b) |> MapSet.size()
    
    if union_size > 0 do
      intersection_size / union_size
    else
      0.0
    end
  end
end
