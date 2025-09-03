defmodule StarweaveCore.Distributed.NodeDiscoveryTest do
  use ExUnit.Case, async: false
  alias StarweaveCore.Distributed.NodeDiscovery

  setup _context do
    # Generate a unique name for this test
    test_name = "node_discovery_#{:erlang.unique_integer([:positive])}" |> String.to_atom()
    
    # Start a new instance with test configuration and unique name
    {:ok, pid} = NodeDiscovery.start_link(
      name: test_name,
      heartbeat_interval: 100, 
      cleanup_interval: 200
    )
    
    # Store the pid and name in the test context
    %{pid: pid, test_name: test_name}
  end

  setup %{pid: pid} do
    on_exit(fn ->
      if Process.alive?(pid) do
        Process.exit(pid, :kill)
      end
    end)

    :ok
  end

  describe "node registration" do
    test "registers a new node", %{test_name: name} do
      assert :ok = GenServer.cast(name, {:register_node, :test_node@test})
      assert [:test_node@test] = GenServer.call(name, :list_nodes)
    end

    test "returns empty list when no nodes are registered", %{test_name: name} do
      assert [] = GenServer.call(name, :list_nodes)
    end
  end

  describe "node cleanup" do
    test "removes dead nodes after timeout" do
      # Create a proper state with all required fields
      state = %NodeDiscovery.State{
        nodes: %{:test_node@test => :erlang.system_time(:second) - 10},
        cleanup_interval: 5000,
        heartbeat_interval: 1000,
        token_count: 0,
        summary_cache: %{}
      }
      
      # Call the cleanup handler directly
      {:noreply, new_state} = NodeDiscovery.handle_info(:cleanup_dead_nodes, state)
      
      # Node should be removed after cleanup
      assert map_size(new_state.nodes) == 0
    end
  end
end
