# Setup Mnesia Cluster Script

defmodule MnesiaCluster do
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
    
    # Start the node
    case Node.start(node_name) do
      {:ok, _} -> 
        IO.puts "✅ Node started: #{node()}"
      {:error, reason} -> 
        IO.puts "❌ Failed to start node: #{inspect reason}"
        exit(1)
    end
    
    # Set Mnesia directory
    mnesia_dir = "priv/mnesia/#{node_type}"
    File.mkdir_p!(mnesia_dir)
    Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))
    IO.puts "📂 Mnesia directory: #{mnesia_dir}"
    
    # Stop Mnesia if running
    :mnesia.stop()
    
    if node_type == "main" do
      # Main node setup
      IO.puts "🚀 Setting up main node..."
      
      # Create schema
      case :mnesia.create_schema([node()]) do
        :ok -> 
          IO.puts "✅ Created schema for #{node()}"
          
          # Start Mnesia
          case :mnesia.start() do
            :ok -> 
              IO.puts "✅ Mnesia started on #{node()}"
              
              # Create a test table
              case :mnesia.create_table(:test_table, [
                {:disc_copies, [node()]},
                {:attributes, [:id, :data]}
              ]) do
                {:atomic, :ok} -> 
                  IO.puts "✅ Created test table"
                error -> 
                  IO.puts "❌ Failed to create test table: #{inspect error}"
              end
              
            error -> 
              IO.puts "❌ Failed to start Mnesia: #{inspect error}"
              exit(1)
          end
          
        {:error, {_, {:already_exists, _}}} -> 
          IO.puts "ℹ️ Schema already exists for #{node()}"
          
          # Start Mnesia if schema exists
          case :mnesia.start() do
            :ok -> 
              IO.puts "✅ Mnesia started on existing schema"
            error -> 
              IO.puts "❌ Failed to start Mnesia: #{inspect error}"
              exit(1)
          end
          
        error -> 
          IO.puts "❌ Failed to create schema: #{inspect error}"
          exit(1)
      end
      
    else
      # Worker node setup
      IO.puts "🚀 Setting up worker node..."
      
      # Start Mnesia
      case :mnesia.start() do
        :ok -> 
          IO.puts "✅ Mnesia started on worker node"
          
          # Connect to main node
          IO.puts "🔗 Connecting to main node: #{main_node}"
          
          case Node.connect(main_node) do
            true ->
              IO.puts "✅ Connected to #{main_node}"
              
              # Add to cluster
              case :mnesia.change_config(:extra_db_nodes, [main_node]) do
                {:ok, _} ->
                  IO.puts "✅ Added to Mnesia cluster"
                  
                  # Copy schema from main node
                  case :mnesia.change_table_copy_type(:schema, node(), :disc_copies) do
                    {:atomic, :ok} ->
                      IO.puts "✅ Copied schema to worker node"
                      
                      # Replicate the test table
                      :mnesia.add_table_copy(:test_table, node(), :disc_copies)
                      IO.puts "✅ Replicated test table to worker node"
                      
                    error ->
                      IO.puts "❌ Failed to copy schema: #{inspect error}"
                      exit(1)
                  end
                  
                error ->
                  IO.puts "❌ Failed to join cluster: #{inspect error}"
                  exit(1)
              end
              
            false ->
              IO.puts "❌ Could not connect to #{main_node}"
              exit(1)
          end
          
        error ->
          IO.puts "❌ Failed to start Mnesia on worker: #{inspect error}"
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
MnesiaCluster.setup()
