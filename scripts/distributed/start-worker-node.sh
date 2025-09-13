#!/bin/bash

# Worker Node Startup Script for STARWEAVE
# This script starts a worker node (001-LITE) that connects to the main node

# Set the node name and cookie
NODE_NAME=worker
COOKIE=starweave-cookie
HOSTNAME=001-LITE
MAIN_NODE=main@STARCORE

# Set distribution ports
DIST_MIN=9000
DIST_MAX=9100

echo "Starting STARWEAVE Worker Node on $HOSTNAME..."
echo "Will attempt to connect to main node: $MAIN_NODE"

# Create a temporary .exs file for startup commands
cat > /tmp/worker_connect.exs << 'EOF'
defmodule WorkerNode do
  def start do
    IO.puts("\nWorker node started. Attempting to connect to main node at #{System.get_env("MAIN_NODE")}...")

    # Set Mnesia directory for worker node first
    mnesia_dir = Path.join(File.cwd!(), "priv/mnesia/worker")
    File.mkdir_p!(mnesia_dir)
    
    # Set Mnesia directory in application env
    Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))
    
    # Get main node name
    main_node = System.get_env("MAIN_NODE") |> String.to_atom()
    
    # Stop Mnesia if it's running
    :mnesia.stop()
    
    # Connect to the main node first
    IO.puts("🔗 Connecting to main node: #{inspect(main_node)}")
    
    # Try to connect to the main node with a timeout
    case Node.ping(main_node) do
      :pong ->
        IO.puts("✅ Connected to main node")
        
        # Start Mnesia without creating a schema
        case :mnesia.start() do
          :ok ->
            IO.puts("✅ Mnesia started on worker node")
            
            # Add this node to the Mnesia cluster
            case :mnesia.change_config(:extra_db_nodes, [main_node]) do
              {:ok, _} ->
                IO.puts("✅ Added to Mnesia cluster")
                
                # Copy the schema from the main node
                :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
                
                # Start the distributed supervision tree
                IO.puts("🚀 Starting distributed components...")
                {:ok, _} = Application.ensure_all_started(:starweave_core)
                
                # Start the Task.Supervisor
                case Task.Supervisor.start_link(name: StarweaveCore.Distributed.TaskSupervisor) do
                  {:ok, _} -> :ok
                  {:error, {:already_started, _}} -> :ok
                  error -> error
                end
                
                # Start the TaskDistributor
                case StarweaveCore.Distributed.TaskDistributor.start_link(name: StarweaveCore.Distributed.TaskDistributor) do
                  {:ok, _} -> :ok
                  {:error, {:already_started, _}} -> 
                    IO.puts("TaskDistributor already running, continuing...")
                    :ok
                  error -> error
                end
                
              error ->
                IO.puts("❌ Failed to connect to Mnesia cluster: #{inspect(error)}")
                error
            end
            
          error ->
            IO.puts("❌ Failed to start Mnesia: #{inspect(error)}")
            error
        end
        
      false ->
        IO.puts("❌ Failed to connect to main node: $MAIN_NODE")
        {:error, :connection_failed}
    end
    
    # Keep the node alive
    Process.sleep(:infinity)
  end
  
  defp connect_to_main do
    main_node = String.to_atom(System.get_env("MAIN_NODE"))
    
    case Node.connect(main_node) do
      true -> 
        IO.puts("✅ Successfully connected to #{inspect(main_node)}")
        IO.puts("Connected nodes: #{inspect(Node.list())}")
        
        # Register with the main node's TaskDistributor
        :rpc.call(main_node, StarweaveCore.Distributed.TaskDistributor, :register_worker, [Node.self()])
        case :rpc.call(main_node, StarweaveCore.Distributed.TaskDistributor, :register_worker, [node()]) do
          :ok ->
            IO.puts("✅ Registered as worker with TaskDistributor on #{inspect(main_node)}")
            :ok
          error ->
            IO.puts("❌ Failed to register with TaskDistributor: #{inspect(error)}")
            :error
        end
        
      false -> 
        IO.puts("❌ Failed to connect to #{inspect(main_node)}")
        IO.puts("Retrying in 5 seconds...")
        Process.sleep(5000)
        connect_to_main()
    end
  end
end

# Start the worker node
IO.puts("Starting STARWEAVE Worker Node...")
IO.puts("Node name: #{inspect(Node.self())}")
IO.puts("Cookie: #{inspect(Node.get_cookie())}")

# Start the worker node
WorkerNode.start()

# This will keep the node running until interrupted
receive do
  _ -> :ok
end
EOF

# Start the IEx session with distribution settings
echo "Starting IEx with distribution settings..."
export MAIN_NODE="$MAIN_NODE"
ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  -S mix run /tmp/worker_connect.exs
