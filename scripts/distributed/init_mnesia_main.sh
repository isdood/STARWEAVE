#!/bin/bash

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Initialize Mnesia for the main node
NODE_NAME="main@${LOCAL_IP}"
COOKIE="starweave-cookie"
MNESIA_DIR="$(pwd)/priv/mnesia/main"

# Create Mnesia directory
mkdir -p "$MNESIA_DIR"

echo "🚀 Initializing Mnesia for main node $NODE_NAME"
echo "🔑 Cookie: $COOKIE"
echo "📂 Mnesia directory: $MNESIA_DIR"

# Create a temporary .exs file for initialization
cat > /tmp/mnesia_init.exs << 'EOF'
# Set Mnesia directory
mnesia_dir = "#{System.get_env("MNESIA_DIR")}"
File.mkdir_p!(mnesia_dir)
Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))

# Stop Mnesia if it's running
:mnesia.stop()

# Get the current node
current_node = node()
IO.puts("Current node: #{inspect(current_node)}")

# Create schema for this node
case :mnesia.create_schema([current_node]) do
  :ok -> 
    IO.puts("✅ Created new Mnesia schema for #{inspect(current_node)}")
  {:error, {_, {:already_exists, _}}} -> 
    IO.puts("ℹ️ Mnesia schema already exists for #{inspect(current_node)}")
  error -> 
    IO.puts("❌ Failed to create Mnesia schema: #{inspect(error)}")
    exit(1)
end

# Start Mnesia
case :mnesia.start() do
  :ok -> 
    IO.puts("✅ Mnesia started on #{inspect(current_node)}")
    
    # Wait for schema to be available
    :mnesia.wait_for_tables([:schema], 5000)
    
    # Set the schema type
    case :mnesia.change_table_copy_type(:schema, current_node, :disc_copies) do
      {:atomic, :ok} -> 
        IO.puts("✅ Set schema copy type to disc_copies")
      error -> 
        IO.puts("❌ Failed to set schema copy type: #{inspect(error)}")
    end
    
    # Print schema info
    IO.puts("\n📋 Mnesia schema info:")
    IO.inspect(:mnesia.table_info(:schema, :all), pretty: true)
    
    # List all tables in the schema
    IO.puts("\n📋 All tables in schema:")
    IO.inspect(:mnesia.system_info(:tables), pretty: true)
    
  error -> 
    IO.puts("❌ Failed to start Mnesia: #{inspect(error)}")
    exit(1)
end

# Keep the node running
IO.puts("\n✅ Mnesia initialization complete for #{inspect(current_node)}")
IO.puts("Node name: #{inspect(node())}")
IO.puts("Cookie: #{inspect(Node.get_cookie())}")
IO.puts("Mnesia dir: #{inspect(Application.get_env(:mnesia, :dir))}")
IO.puts("\nPress Ctrl+C to stop")

# Keep the node running
Process.sleep(:infinity)
EOF

# Run the initialization script
MNESIA_DIR="$MNESIA_DIR" elixir --name "$NODE_NAME" --cookie "$COOKIE" /tmp/mnesia_init.exs
