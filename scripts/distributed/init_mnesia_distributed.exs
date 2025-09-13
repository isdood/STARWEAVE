# Set the node name and cookie
Node.start(:"$NODE_NAME")
Node.set_cookie(String.to_atom("$COOKIE"))
:net_kernel.set_net_ticktime(10)

# Set Mnesia directory
mnesia_dir = "$MNESIA_DIR"
File.mkdir_p!(mnesia_dir)
IO.puts("Mnesia directory: #{mnesia_dir}")

# Configure Mnesia
Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))

# Stop Mnesia if it's running
:mnesia.stop()

# Determine if this is the main node
is_main_node = "$IS_MAIN_NODE" == "true"

if is_main_node do
  # For main node, create a new schema
  case :mnesia.create_schema([node()]) do
    :ok -> 
      IO.puts("✅ Created new Mnesia schema for main node #{node()}")
    {:error, {_, {:already_exists, _}}} -> 
      IO.puts("ℹ️ Mnesia schema already exists for main node #{node()}")
    error -> 
      IO.puts("❌ Failed to create Mnesia schema: #{inspect(error)}")
      exit(1)
  end
  
  # Start Mnesia
  case :mnesia.start() do
    :ok -> 
      IO.puts("✅ Mnesia started on main node #{node()}")
      
      # Wait for tables to be available
      :mnesia.wait_for_tables([:schema], 5000)
      
      # Set as the only node in the cluster initially
      :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
      
      # Print schema info
      IO.puts("📋 Mnesia schema info:")
      IO.inspect(:mnesia.table_info(:schema, :all))
      
    error -> 
      IO.puts("❌ Failed to start Mnesia: #{inspect(error)}")
      exit(1)
  end
else
  # For worker nodes, connect to the main node first
  main_node = String.to_atom("$MAIN_NODE")
  IO.puts("🔗 Connecting to main node: #{inspect(main_node)}")
  
  # Try to connect to the main node
  case Node.ping(main_node) do
    :pong ->
      IO.puts("✅ Connected to main node")
      
      # Start Mnesia without creating a schema
      case :mnesia.start() do
        :ok ->
          IO.puts("✅ Mnesia started on worker node #{node()}")
          
          # Add this node to the Mnesia cluster
          case :mnesia.change_config(:extra_db_nodes, [main_node]) do
            {:ok, _} ->
              IO.puts("✅ Added to Mnesia cluster")
              
              # Copy the schema from the main node
              :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
              
              # Print schema info
              IO.puts("📋 Mnesia schema info:")
              IO.inspect(:mnesia.table_info(:schema, :all))
              
            error ->
              IO.puts("❌ Failed to join Mnesia cluster: #{inspect(error)}")
              exit(1)
          end
          
        error ->
          IO.puts("❌ Failed to start Mnesia: #{inspect(error)}")
          exit(1)
      end
      
    :pang ->
      IO.puts("❌ Could not connect to main node: #{inspect(main_node)}")
      exit(1)
  end
end

# Keep the node running
IO.puts("\n✅ Mnesia initialization complete for node #{node()}")
IO.puts("Node name: #{node()}")
IO.puts("Cookie: #{Node.get_cookie()}")
IO.puts("Mnesia dir: #{mnesia_dir}")
IO.puts("\nPress Ctrl+C to stop")

# Keep the node running
Process.sleep(:infinity)
