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

case Node.connect(String.to_atom(System.get_env("MAIN_NODE"))) do
  true -> 
    IO.puts("✅ Successfully connected to #{System.get_env("MAIN_NODE")}")
    IO.puts("Connected nodes: #{inspect(Node.list())}")
  false -> 
    IO.puts("❌ Failed to connect to #{System.get_env("MAIN_NODE")}")
    IO.puts("Please ensure the main node is running and accessible")
end

# Start an interactive shell
IO.puts("\nInteractive shell ready. You can check node connections with Node.list()")
EOF

# Start the IEx session with distribution settings
echo "Starting IEx with distribution settings..."
export MAIN_NODE="$MAIN_NODE"
ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  -S mix run /tmp/worker_connect.exs
