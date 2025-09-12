defmodule StarweaveCore.Intelligence.DistributedWorkingMemory do
  @moduledoc """
  A distributed working memory system that shards memory across multiple nodes
  using process groups for distribution and provides replication for fault tolerance.
  """
  
  use GenServer
  require Logger
  
  alias StarweaveCore.Intelligence.WorkingMemory
  
  # Default configuration
  @default_replicas 2
  @default_retry_attempts 3
  @default_retry_delay 100
  @group_name :starweave_memory_nodes
  
  # Client API
  
  @doc """
  Starts the DistributedWorkingMemory GenServer.
  
  ## Options
    - `:replicas` - Number of replicas for each memory entry (default: #{@default_replicas})
    - `:retry_attempts` - Number of retry attempts for operations (default: #{@default_retry_attempts})
    - `:retry_delay` - Delay between retries in milliseconds (default: #{@default_retry_delay})
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Stores a value in distributed working memory.
  
  ## Parameters
    - `context` - The context of the memory (e.g., :conversation, :environment)
    - `key` - The key to store the value under
    - `value` - The value to store
    - `opts` - Additional options (ttl, importance, etc.)
  """
  @spec store(atom(), term(), term(), keyword()) :: :ok | {:error, term()}
  def store(context, key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:store, context, key, value, opts}, :infinity)
  end
  
  @doc """
  Retrieves a value from distributed working memory.
  
  Returns `{:ok, value}` if found, or `:not_found` otherwise.
  """
  @spec retrieve(atom(), term()) :: {:ok, term()} | :not_found | {:error, term()}
  def retrieve(context, key) do
    GenServer.call(__MODULE__, {:retrieve, context, key}, :infinity)
  end
  
  @doc """
  Retrieves all memories for a given context.
  
  Returns a list of `{key, value, metadata}` tuples.
  """
  @spec get_context(atom()) :: [{term(), term(), map()}] | {:error, term()}
  def get_context(context) do
    GenServer.call(__MODULE__, {:get_context, context}, :infinity)
  end
  
  @doc """
  Performs a distributed search across all nodes.
  
  Returns a list of `{context, key, value, score}` tuples sorted by relevance.
  """
  @spec search(String.t(), keyword()) :: [{atom(), term(), term(), float()}] | {:error, term()}
  def search(query, opts \\ []) do
    GenServer.call(__MODULE__, {:search, query, opts}, :infinity)
  end
  
  # Server Callbacks
  
  defmodule State do
    defstruct [
      group_name: nil,         # Process group name
      members: MapSet.new(),   # Current members in the process group
      replicas: 2,             # Number of replicas for each entry
      retry_attempts: 3,       # Number of retry attempts for operations
      retry_delay: 100,        # Delay between retries in milliseconds
      local_memory: %{}        # Local in-memory cache for performance
    ]
  end
  
  @impl true
  def init(opts) do
    replicas = Keyword.get(opts, :replicas, @default_replicas)
    retry_attempts = Keyword.get(opts, :retry_attempts, @default_retry_attempts)
    retry_delay = Keyword.get(opts, :retry_delay, @default_retry_delay)
    
    # Start the process group if it's not already started
    case :pg.get_members(@group_name) do
      [] -> 
        # No existing group, create one
        :pg.start_link()
      _ -> 
        # Group already exists
        :ok
    end
    
    # Join the process group
    :ok = :pg.join(@group_name, self())
    
    # Get all members of the group
    members = :pg.get_members(@group_name)
    
    # Schedule periodic membership check
    schedule_ring_update()
    
    {:ok, %State{
      group_name: @group_name,
      members: MapSet.new(members),
      replicas: replicas,
      retry_attempts: retry_attempts,
      retry_delay: retry_delay
    }}
  end
  
  @impl true
  def handle_call({:store, context, key, value, opts}, _from, state) do
    entry_key = {context, key}
    
    # Determine the primary node and replica nodes
    nodes = get_responsible_nodes(state.ring, entry_key, state.replicas)
    
    # Store on all responsible nodes
    results = 
      nodes
      |> Enum.map(fn node ->
        if node == node() do
          # Local storage
          WorkingMemory.store(context, key, value, opts)
        else
          # Remote storage
          :rpc.call(node, WorkingMemory, :store, [context, key, value, opts], :infinity)
        end
      end)
    
    # Check if all storage operations were successful
    case Enum.all?(results, &(&1 == :ok)) do
      true -> 
        # Update local cache
        local_memory = Map.put(state.local_memory, entry_key, value)
        {:reply, :ok, %{state | local_memory: local_memory}}
      false ->
        # Handle partial failures
        failed_nodes = 
          Enum.zip(nodes, results)
          |> Enum.filter(fn {_node, result} -> result != :ok end)
          |> Enum.map(&elem(&1, 0))
        
        Logger.error("Failed to store on nodes: #{inspect(failed_nodes)}")
        {:reply, {:error, :storage_failure, failed_nodes}, state}
    end
  end
  
  @impl true
  def handle_call({:retrieve, context, key}, _from, state) do
    entry_key = {context, key}
    
    # Check local cache first
    case Map.get(state.local_memory, entry_key) do
      nil ->
        # Not in cache, determine the primary node
        [primary_node | _] = get_responsible_nodes(state.ring, entry_key, 1)
        
        result = 
          if primary_node == node() do
            # Local retrieval
            WorkingMemory.retrieve(context, key)
          else
            # Remote retrieval
            case :rpc.call(primary_node, WorkingMemory, :retrieve, [context, key], :infinity) do
              {:ok, value} -> 
                # Cache the result
                local_memory = Map.put(state.local_memory, entry_key, value)
                {:ok, value, %{state | local_memory: local_memory}}
              other -> 
                other
            end
          end
        
        case result do
          {:ok, value, new_state} -> 
            {:reply, {:ok, value}, new_state}
          other -> 
            {:reply, other, state}
        end
        
      cached_value ->
        # Return from cache
        {:reply, {:ok, cached_value}, state}
    end
  end
  
  @impl true
  def handle_call({:get_context, context}, _from, state) do
    # Gather results from all nodes and merge them
    results = 
      state.nodes
      |> Enum.flat_map(fn node ->
        if node == node() do
          WorkingMemory.get_context(context)
        else
          case :rpc.call(node, WorkingMemory, :get_context, [context], :infinity) do
            {:ok, entries} -> entries
            _ -> []
          end
        end
      end)
      |> Enum.uniq_by(fn {key, _value, _meta} -> key end)
      
    {:reply, {:ok, results}, state}
  end
  
  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    # Gather search results from all nodes
    results = 
      state.nodes
      |> Enum.flat_map(fn node ->
        if node == node() do
          WorkingMemory.search(query, opts)
        else
          case :rpc.call(node, WorkingMemory, :search, [query, opts], :infinity) do
            {:ok, entries} -> entries
            _ -> []
          end
        end
      end)
      
    # Merge and sort results by score
    merged_results = 
      results
      |> Enum.group_by(fn {ctx, key, _value, _score} -> {ctx, key} end)
      |> Enum.map(fn {{ctx, key}, entries} ->
        # Take the entry with the highest score for each key
        {_ctx, _key, value, score} = 
          entries 
          |> Enum.max_by(fn {_ctx, _key, _value, score} -> score end)
        
        {ctx, key, value, score}
      end)
      |> Enum.sort_by(fn {_ctx, _key, _value, score} -> -score end)
      
    {:reply, {:ok, merged_results}, state}
  end
  
  @impl true
  def handle_info(:update_membership, state) do
    # Get current members of the group
    current_members = MapSet.new(:pg.get_members(state.group_name))
    
    if MapSet.equal?(current_members, state.members) do
      {:noreply, state}
    else
      # Trigger rebalancing if membership changed
      trigger_rebalancing(current_members, state)
      
      {:noreply, %{state | members: current_members}}
    end
  end
  
  # Helper functions
  
  defp get_responsible_nodes(members, key, count) do
    # Simple consistent hashing using the key to determine responsible nodes
    key_str = :erlang.term_to_binary(key)
    hash = :erlang.phash2(key_str)
    
    members_list = MapSet.to_list(members)
    num_members = length(members_list)
    
    if num_members == 0 do
      []
    else
      # Select nodes based on hash
      start_idx = rem(hash, num_members)
      
      Stream.cycle(members_list)
      |> Stream.drop(start_idx)
      |> Enum.take(min(count, num_members))
    end
  end
  
  defp schedule_ring_update do
    # Check for membership changes every 5 seconds
    Process.send_after(self(), :update_membership, 5_000)
  end
  
  defp trigger_rebalancing(_new_members, _state) do
    # TODO: Implement data rebalancing when nodes are added or removed
    # This would involve:
    # 1. Identifying keys that need to be moved
    # 2. Transferring data between nodes
    # 3. Updating the routing information
    :ok
  end
  
  defp with_retry(fun, max_attempts, delay) when max_attempts > 1 do
    try do
      fun.()
    rescue
      _e ->
        Process.sleep(delay)
        with_retry(fun, max_attempts - 1, delay)
    end
  end
  
  defp with_retry(fun, _max_attempts, _delay) do
    fun.()
  end
end
