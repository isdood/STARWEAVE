defmodule StarweaveCore.Intelligence.WorkingMemory do
  @moduledoc """
  A GenServer-based working memory system for maintaining and managing the agent's
  short-term memory. This module provides functionality to store, retrieve, and
  manage information in a structured way.
  
  The working memory is organized into different contexts (e.g., :conversation, :environment, :goals)
  to allow for better organization and retrieval of information.
  """
  
  use GenServer
  require Logger
  
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
      - `:ttl`: Time to live in milliseconds (default: 30_000)
      - `:importance`: Importance score (0.0 to 1.0, default: 0.5)
  """
  @spec store(context(), memory_key(), memory_value(), keyword()) :: :ok
  def store(context, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 30_000)
    importance = Keyword.get(opts, :importance, 0.5)
    
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
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    # Start the cleanup process
    Process.send_after(self(), :cleanup, 10_000)  # Run cleanup every 10 seconds
    {:ok, %{memories: %{}, cleanup_ref: nil}}
  end
  
  @impl true
  def handle_cast({:store, context, key, value, ttl, importance}, %{memories: memories} = state) do
    now = DateTime.utc_now()
    
    new_entry = %{
      value: value,
      timestamp: now,
      ttl: ttl,
      importance: importance
    }
    
    # Update the memories, creating the context and key if they don't exist
    updated_memories = 
      memories
      |> Map.put_new(context, %{})
      |> put_in([context, key], new_entry)
    
    {:noreply, %{state | memories: updated_memories}}
  end
  
  def handle_cast({:forget, context, key}, %{memories: memories} = state) do
    updated_memories = 
      case Map.get(memories, context) do
        nil -> memories
        context_memories -> 
          updated_context = Map.delete(context_memories, key)
          if map_size(updated_context) == 0 do
            Map.delete(memories, context)
          else
            Map.put(memories, context, updated_context)
          end
      end
    
    {:noreply, %{state | memories: updated_memories}}
  end
  
  def handle_cast({:clear_context, context}, %{memories: memories} = state) do
    {:noreply, %{state | memories: Map.delete(memories, context)}}
  end
  
  @impl true
  def handle_call({:retrieve, context, key}, _from, %{memories: memories} = state) do
    result = 
      case get_in(memories, [context, key]) do
        nil -> :not_found
        %{value: value} -> {:ok, value}
      end
    
    {:reply, result, state}
  end
  
  def handle_call({:get_context, context}, _from, %{memories: memories} = state) do
    result = 
      case Map.get(memories, context, %{}) do
        context_memories when map_size(context_memories) > 0 ->
          context_memories
          |> Enum.map(fn {key, %{value: value} = meta} -> 
            {key, value, Map.drop(meta, [:value])}
          end)
          |> Enum.sort_by(
            fn {_key, _value, %{timestamp: ts, importance: imp}} -> 
              # Sort by recency and importance
              DateTime.to_unix(ts) * imp
            end,
            :desc
          )
        _ ->
          []
      end
    
    {:reply, result, state}
  end
  
  def handle_call({:search, query, threshold, limit}, _from, %{memories: memories} = state) do
    # Simple string similarity search (can be enhanced with more sophisticated NLP)
    results = 
      memories
      |> Enum.flat_map(fn {context, context_memories} ->
        Enum.map(context_memories, fn {key, %{value: value} = meta} ->
          score = jaccard_similarity(query, to_string(key) <> " " <> to_string(value))
          {context, key, value, score, meta}
        end)
      end)
      |> Enum.filter(fn {_c, _k, _v, score, _m} -> score >= threshold end)
      |> Enum.sort_by(fn {_c, _k, _v, score, _m} -> -score end)
      |> Enum.take(limit)
      |> Enum.map(fn {context, k, v, score, _m} -> {context, k, v, score} end)
    
    {:reply, results, state}
  end
  
  @impl true
  def handle_info(:cleanup, %{memories: memories} = state) do
    now = DateTime.utc_now()
    now_ts = DateTime.to_unix(now, :millisecond)
    
    # Remove expired memories
    updated_memories = 
      memories
      |> Enum.map(fn {context, context_memories} ->
        updated_context = 
          context_memories
          |> Enum.reject(fn {_key, %{timestamp: ts, ttl: ttl}} ->
            ttl != :infinity && 
            DateTime.diff(now, ts, :millisecond) > ttl
          end)
          |> Enum.into(%{})
          
        {context, updated_context}
      end)
      |> Enum.reject(fn {_context, mems} -> map_size(mems) == 0 end)
      |> Enum.into(%{})
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup, 10_000)
    
    {:noreply, %{state | memories: updated_memories}}
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
