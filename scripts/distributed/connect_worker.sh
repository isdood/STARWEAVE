#!/bin/bash

# Simple script to connect a worker node to the main node

# Configuration
WORKER_NAME="worker1"
MAIN_NODE="main@127.0.0.1"
COOKIE="starweave-cookie"

# Create a temporary Elixir script
cat > /tmp/worker_connect.exs << 'EOF'
IO.puts("\n=== STARWEAVE Worker Node ===")
IO.puts("Worker node: #{node()}")
IO.puts("Connecting to main node: #{System.get_env("MAIN_NODE")}")

# Format the main node name as an atom
main_node = String.to_atom(System.get_env("MAIN_NODE"))

# Try to connect to main node
IO.puts("Attempting to ping: #{inspect(main_node)}...")

case Node.ping(main_node) do
  :pong -> 
    IO.puts("\n✅ Successfully connected to #{inspect(main_node)}!")
    IO.puts("Connected nodes: #{inspect(Node.list())}")
    IO.puts("\nType Ctrl+C to exit")
    # Keep the node alive
    :timer.sleep(:infinity)
  _ -> 
    IO.puts("\n❌ Failed to connect to #{inspect(main_node)}")
    IO.puts("\nPossible issues:")
    IO.puts("1. Main node not running or not in distributed mode")
    IO.puts("2. Firewall blocking the connection")
    IO.puts("3. Cookie mismatch (check ~/.erlang.cookie on both nodes)")
    :timer.sleep(5)
    System.halt(1)
end
EOF

# Start the worker node
export MAIN_NODE="$MAIN_NODE"
iex --name "${WORKER_NAME}@127.0.0.1" --cookie "$COOKIE" -S mix run /tmp/worker_connect.exs
