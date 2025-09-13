#!/bin/bash

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Initialize Mnesia for the worker node
NODE_NAME="worker@${LOCAL_IP}"
MAIN_NODE="main@${LOCAL_IP}"
COOKIE="starweave-cookie"
MNESIA_DIR="$(pwd)/priv/mnesia/worker"

# Create Mnesia directory
mkdir -p "$MNESIA_DIR"

echo "🚀 Initializing Mnesia for worker node $NODE_NAME"
echo "🔗 Connecting to main node: $MAIN_NODE"
echo "🔑 Cookie: $COOKIE"
echo "📂 Mnesia directory: $MNESIA_DIR"

# Create a temporary .exs file for initialization
cat > /tmp/mnesia_worker_init.exs << 'EOF'
# Set Mnesia directory
mnesia_dir = "#{System.get_env("MNESIA_DIR")}"
File.mkdir_p!(mnesia_dir)
Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))

# Stop Mnesia if it's running
:mnesia.stop()

# Get the current node and main node
current_node = node()
main_node = String.to_atom("#{System.get_env("MAIN_NODE")}")

IO.puts("Current node: #{inspect(current_node)}")
IO.puts("Main node: #{inspect(main_node)}")

# Start Mnesia without creating a schema
case :mnesia.start() do
  :ok -> 
    IO.puts("✅ Mnesia started on worker node")
    
    # Try to connect to the main node
    IO.puts("🔗 Connecting to main node: #{inspect(main_node)}")
    
    case Node.ping(main_node) do
      :pong ->
        IO.puts("✅ Connected to main node")
        
        # Add this node to the Mnesia cluster
        case :mnesia.change_config(:extra_db_nodes, [main_node]) do
          {:ok, _} ->
            IO.puts("✅ Added to Mnesia cluster")
            
            # Copy the schema from the main node
            case :mnesia.change_table_copy_type(:schema, current_node, :disc_copies) do
              {:atomic, :ok} ->
                IO.puts("✅ Copied schema to worker node")
                
                # Print schema info
                IO.puts("\n📋 Mnesia schema info:")
                IO.inspect(:mnesia.table_info(:schema, :all), pretty: true)
                
                # List all tables in the schema
                IO.puts("\n📋 All tables in schema:")
                IO.inspect(:mnesia.system_info(:tables), pretty: true)
                
              error ->
                IO.puts("❌ Failed to copy schema: #{inspect(error)}")
                exit(1)
            end
            
          error ->
            IO.puts("❌ Failed to join Mnesia cluster: #{inspect(error)}")
            exit(1)
        end
        
      :pang ->
        IO.puts("❌ Could not connect to main node: #{inspect(main_node)}")
        exit(1)
    end
    
  error ->
    IO.puts("❌ Failed to start Mnesia: #{inspect(error)}")
    exit(1)
end

# Keep the node running
IO.puts("\n✅ Mnesia worker initialization complete for #{inspect(current_node)}")
IO.puts("Node name: #{inspect(node())}")
IO.puts("Main node: #{inspect(main_node)}")
IO.puts("Cookie: #{inspect(Node.get_cookie())}")
IO.puts("Mnesia dir: #{inspect(Application.get_env(:mnesia, :dir))}")
IO.puts("\nPress Ctrl+C to stop")

# Keep the node running
Process.sleep(:infinity)
EOF

# Run the initialization script
MNESIA_DIR="$MNESIA_DIR" \
MAIN_NODE="$MAIN_NODE" \
elixir --name "$NODE_NAME" --cookie "$COOKIE" /tmp/mnesia_worker_init.exs
