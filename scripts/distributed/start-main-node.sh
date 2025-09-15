#!/bin/bash

# Main Node Startup Script for STARWEAVE
# This script starts the main node (STARCORE) with the web interface

# Set the node name and cookie
NODE_NAME=main
COOKIE=starweave-cookie
HOSTNAME=STARCORE
HTTP_PORT=4000

# Set distribution ports
DIST_MIN=9000
DIST_MAX=9100

echo "Starting STARWEAVE Main Node on $HOSTNAME..."
echo "HTTP server will be available on port $HTTP_PORT"

# Set the PORT environment variable for Phoenix
export PORT=$HTTP_PORT

# Create a temporary .exs file for startup commands
cat > /tmp/main_node_startup.exs << 'EOF'
defmodule MainNode do
  def start do
    # Set the node name for better visibility
    Node.set_cookie(String.to_atom(System.get_env("COOKIE")))
    
    # Start the distributed supervision tree
    IO.puts("\n🌟 STARWEAVE Main Node Starting...")
    IO.puts("==============================")
    IO.puts("Node name:    #{inspect(Node.self())}")
    IO.puts("Cookie:       #{inspect(Node.get_cookie())}")
    IO.puts("Distribution: #{:net_kernel.nodename()}")
    
    # Create data directory for DETS
    data_dir = Path.join(File.cwd!(), "priv/data")
    File.mkdir_p!(data_dir)
    IO.puts("📂 Data directory: #{data_dir}")
    
    # Start the application
    IO.puts("\n🚀 Starting STARWEAVE application...")
    
    # Start the application
    case Application.ensure_all_started(:starweave_core) do
      {:ok, _} ->
        IO.puts("✅ STARWEAVE Core started successfully")
      error ->
        IO.puts("❌ Failed to start STARWEAVE Core: #{inspect(error)}")
        System.halt(1)
    end
    
    # Start the web interface
    case Application.ensure_all_started(:starweave_web) do
      {:ok, _} ->
        IO.puts("✅ STARWEAVE Web started successfully")
      error ->
        IO.puts("❌ Failed to start STARWEAVE Web: #{inspect(error)}")
        System.halt(1)
    end
    
    # Print the web interface URL
    IO.puts("\n🌐 Web interface available at: http://localhost:#{System.get_env("PORT")}")
    IO.puts("📡 Node name: #{Node.self()}")
    IO.puts("🍪 Cookie:    #{inspect(Node.get_cookie())}")
    IO.puts("📂 Data directory: #{Path.join(File.cwd!(), "priv/data")}")
    IO.puts("\n✅ Distributed components started successfully")
    IO.puts("\nPhoenix web server is running...")
    IO.puts("Web interface available at http://#{System.get_env("HOSTNAME")}:#{System.get_env("PORT")}")
    IO.puts("\nWaiting for worker connections...")
    IO.puts("Use Node.list() to see connected nodes")
    IO.puts("Press Ctrl+C to stop")
    
    # Keep the node running
    Process.sleep(:infinity)
  end
end

defmodule NodeMonitor do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :net_kernel.monitor_nodes(true, node_type: :all)
    {:ok, %{}}
  end

  def handle_info({:nodedown, node, _info}, state) do
    IO.puts("\n⚠️  Node disconnected: #{node}")
    {:noreply, state}
  end

  def handle_info({:nodeup, node, _info}, state) do
    IO.puts("\n✅ Node connected: #{node}")
    IO.puts("   Connected nodes: #{inspect(Node.list())}")
    {:noreply, state}
  end
end

# Start the main node
MainNode.start()

# This will keep the node running until interrupted
receive do
  _ -> :ok
end
EOF

# Export environment variables
export COOKIE=$COOKIE

# Function to handle cleanup
cleanup() {
  echo -e "\nShutting down gracefully..."
  # Kill the Phoenix server and any related processes
  pkill -f "iex.*$NODE_NAME"
  rm -f /tmp/main_node_startup.exs
  exit 0
}

# Set up trap to catch Ctrl+C
trap cleanup INT TERM

# Start the Phoenix server with the node monitor in the same IEx session
echo "Starting Phoenix web server with node monitoring..."
ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  --erl "-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
  -S mix phx.server

# This will keep the script running until Phoenix exits
echo "Phoenix server has stopped"
cleanup
