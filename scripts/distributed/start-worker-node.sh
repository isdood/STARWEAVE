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
IO.puts("\nWorker node started.")
IO.puts("\nTo connect to the main node, run in this IEx session:")
IO.puts("  Node.connect(String.to_atom(\"main@STARCORE\"))")
IO.puts("  Node.list()  # Should show the main node if connected")
EOF

# Start the IEx session with distribution settings
echo "Starting IEx with distribution settings..."
ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  -S mix run /tmp/worker_connect.exs
