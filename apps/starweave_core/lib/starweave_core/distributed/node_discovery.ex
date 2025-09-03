defmodule StarweaveCore.Distributed.NodeDiscovery do
  @moduledoc """
  Handles node discovery and cluster formation in the distributed system.
  Implements node registration, heartbeats, and basic cluster management.
  """
  use GenServer
  require Logger

  alias __MODULE__.State

  # Client API

  @doc """
  Starts the NodeDiscovery process.
  
  ## Options
    * `:name` - The name to register the process under. Defaults to `__MODULE__`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a new node in the cluster.
  """
  @spec register_node(node()) :: :ok
  def register_node(node) when is_atom(node) do
    GenServer.cast(__MODULE__, {:register_node, node})
  end

  @doc """
  Returns the list of known nodes in the cluster.
  """
  @spec list_nodes() :: [node()]
  def list_nodes do
    GenServer.call(__MODULE__, :list_nodes)
  end

  @doc """
  Subscribes the calling process to node up/down events.
  The process will receive {:nodeup, node, info} and {:nodedown, node, info} messages.
  """
  @spec subscribe(pid()) :: :ok
  def subscribe(pid) when is_pid(pid) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  # Server Callbacks

  defmodule State do
    @moduledoc false
    defstruct [
      nodes: %{},
      subscribers: MapSet.new(),
      heartbeat_interval: 5_000,
      cleanup_interval: 30_000,
      token_count: 0,
      summary_cache: %{},
      max_tokens: 4_000,
      max_history: 20
    ]
  end

  @impl true
  def init(opts) do
    :net_kernel.monitor_nodes(true, node_type: :visible, nodedown_reason: :noconnection)
    
    state = %State{
      heartbeat_interval: Keyword.get(opts, :heartbeat_interval, 5_000),
      cleanup_interval: Keyword.get(opts, :cleanup_interval, 30_000)
    }
    
    # Schedule periodic cleanup of dead nodes
    Process.send_after(self(), :cleanup_dead_nodes, state.cleanup_interval)
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:register_node, node}, %State{nodes: nodes, subscribers: subscribers} = state) do
    now = :erlang.system_time(:second)
    Logger.debug("Node registered: #{inspect(node)}")
    
    # Notify subscribers
    Enum.each(subscribers, fn pid ->
      send(pid, {:nodeup, node, %{timestamp: now}})
    end)
    
    {:noreply, %{state | nodes: Map.put(nodes, node, now)}}
  end
  
  @impl true
  def handle_cast({:subscribe, pid}, %State{subscribers: subscribers} = state) do
    Process.monitor(pid)
    {:noreply, %{state | subscribers: MapSet.put(subscribers, pid)}}
  end

  @impl true
  def handle_call(:list_nodes, _from, %State{nodes: nodes} = state) do
    {:reply, Map.keys(nodes), state}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("Node connected: #{inspect(node)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node, _info}, %State{nodes: nodes, subscribers: subscribers} = state) do
    Logger.warning("Node disconnected: #{inspect(node)}")
    
    # Notify subscribers
    Enum.each(subscribers, fn pid ->
      send(pid, {:nodedown, node, %{timestamp: :erlang.system_time(:second)}})
    end)
    
    {:noreply, %{state | nodes: Map.delete(nodes, node)}}
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{subscribers: subscribers} = state) do
    # Remove dead subscribers
    {:noreply, %{state | subscribers: MapSet.delete(subscribers, pid)}}
  end

  @impl true
  def handle_info(:cleanup_dead_nodes, %State{nodes: nodes, cleanup_interval: interval} = state) do
    now = :erlang.system_time(:second)
    # Remove nodes that haven't sent a heartbeat in the last interval
    alive_nodes = nodes
    |> Enum.reject(fn {_node, last_seen} ->
      (now - last_seen) * 1000 > interval
    end)
    |> Map.new()
    
    # Log if any nodes were removed
    if map_size(nodes) > map_size(alive_nodes) do
      Logger.debug("Cleaned up #{map_size(nodes) - map_size(alive_nodes)} dead nodes")
    end
    
    # Reschedule cleanup
    Process.send_after(self(), :cleanup_dead_nodes, interval)
    
    {:noreply, %{state | nodes: alive_nodes}}
  end
end
