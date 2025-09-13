# Simple Mnesia Cluster Setup Script

defmodule MnesiaSetup do
  def setup do
    # Get node type from command line arguments
    [node_type | _] = System.argv()
    
    # Common settings
    cookie = :"starweave-cookie"
    Node.set_cookie(cookie)
    
    # Set node name based on type
    {node_name, main_node} = case node_type do
      "main" -> 
        {
          :"main@127.0.0.1",
          nil
        }
      "worker" -> 
        {
          :"worker@127.0.0.1",
          :"main@127.0.0.1"
        }
    end
    
    # Set the node name
    Node.start(node_name)
    
    # Set Mnesia directory
    mnesia_dir = "priv/mnesia/#{node_type}"
    File.mkdir_p!(mnesia_dir)
    Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))
    
    # Stop Mnesia if running
    :mnesia.stop()
    
    if node_type == "main" do
      # Main node setup
      IO.puts "🚀 Starting main node: #{node()}"
      
      # Create schema
      case :mnesia.create_schema([node()]) do
        :ok -> IO.puts "✅ Created schema for #{node()}"
        {:error, {_, {:already_exists, _}}} -> IO.puts "ℹ️ Schema already exists for #{node()}"
        error -> IO.puts "❌ Failed to create schema: #{inspect error}"; exit(1)
      end
      
      # Start Mnesia
      case :mnesia.start() do
        :ok -> IO.puts "✅ Mnesia started on #{node()}"
        {:error, {:already_started, :mnesia}} -> IO.puts "ℹ️ Mnesia already running on #{node()}"
        error -> IO.puts "❌ Failed to start Mnesia: #{inspect error}"; exit(1)
      end
      
      # Make sure schema is disc_copies
      :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
      
    else
      # Worker node setup
      IO.puts "🚀 Starting worker node: #{node()}"
      
      # Start Mnesia
      case :mnesia.start() do
        :ok -> IO.puts "✅ Mnesia started on #{node()}"
        error -> IO.puts "❌ Failed to start Mnesia: #{inspect error}"; exit(1)
      end
      
      # Connect to main node
      IO.puts "🔗 Connecting to main node: #{main_node}"
      
      case Node.connect(main_node) do
        true ->
          IO.puts "✅ Connected to #{main_node}"
          
          # Add to cluster
          case :mnesia.change_config(:extra_db_nodes, [main_node]) do
            {:ok, _} ->
              IO.puts "✅ Added to Mnesia cluster"
              :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
            error ->
              IO.puts "❌ Failed to join cluster: #{inspect error}"
              exit(1)
          end
          
        false ->
          IO.puts "❌ Could not connect to #{main_node}"
          exit(1)
      end
    end
    
    # Print status
    IO.puts "\n📋 Node Info:"
    IO.puts "Node: #{node()}"
    IO.puts "Cookie: #{inspect Node.get_cookie()}"
    IO.puts "Mnesia dir: #{inspect Application.get_env(:mnesia, :dir)}"
    
    IO.puts "\n📋 Mnesia Tables:"
    IO.inspect :mnesia.system_info(:tables)
    
    # Keep the node running
    IO.puts "\n✅ #{node_type} node running. Press Ctrl+C to stop."
    :timer.sleep(:infinity)
  end
end

# Run the setup
MnesiaSetup.setup()
