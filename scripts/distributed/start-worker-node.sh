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
# Attempt to connect to the main node
IO.puts("\nWorker node started. Attempting to connect to main node at #{System.get_env("MAIN_NODE")}...")

# Start the distributed supervision tree
IO.puts("Starting distributed components...")
{:ok, _} = Application.ensure_all_started(:starweave_core)

# Connect to the main node
case Node.connect(String.to_atom(System.get_env("MAIN_NODE"))) do
  true -> 
    IO.puts("✅ Successfully connected to #{System.get_env("MAIN_NODE")}")
    IO.puts("Connected nodes: #{inspect(Node.list())}")
    
    # Register with the main node's TaskDistributor
    main_node = String.to_atom("main@STARCORE")
    :rpc.call(main_node, StarweaveCore.Distributed.TaskDistributor, :register_worker, [node()])
    IO.puts("✅ Registered as worker with TaskDistributor on #{inspect(main_node)}")
    
  false -> 
    IO.puts("❌ Failed to connect to #{System.get_env("MAIN_NODE")}")
    IO.puts("Please ensure the main node is running and accessible")
end

# Start an interactive shell
IO.puts("\nWorker node ready. You can check node connections with Node.list()")
IO.puts("To test distributed processing, run on the main node:")
IO.puts("  StarweaveCore.Distributed.TaskDistributor.submit_task(\"test\", fn x -> \"Processed: #{inspect(node())} got: \" <> x end, distributed: true)")
EOF

# Start the IEx session with distribution settings
echo "Starting IEx with distribution settings..."
export MAIN_NODE="$MAIN_NODE"
ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  -S mix run /tmp/worker_connect.exs
