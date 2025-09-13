#!/bin/bash

# Start the worker node
iex --sname worker --cookie starweave-cookie -e "
  # Set Mnesia directory
  mnesia_dir = \"priv/mnesia/worker\"
  File.mkdir_p!(mnesia_dir)
  Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))
  
  # Stop Mnesia if running
  :mnesia.stop()
  
  # Start Mnesia
  case :mnesia.start() do
    :ok -> 
      IO.puts(\"✅ Mnesia started on worker node\")
      
      # Connect to main node
      main_node = :\"main@001-LITE\"
      IO.puts(\"🔗 Connecting to main node: #{main_node}\")
      
      case Node.connect(main_node) do
        true ->
          IO.puts(\"✅ Connected to #{main_node}\")
          
          # Add to cluster
          case :mnesia.change_config(:extra_db_nodes, [main_node]) do
            {:ok, _} ->
              IO.puts(\"✅ Added to Mnesia cluster\")
              
              # Copy schema from main node
              case :mnesia.change_table_copy_type(:schema, node(), :disc_copies) do
                {:atomic, :ok} ->
                  IO.puts(\"✅ Copied schema to worker node\")
                  
                  # Replicate the test table
                  :mnesia.add_table_copy(:test_table, node(), :disc_copies)
                  IO.puts(\"✅ Replicated test table to worker node\")
                  
                  # Verify table is accessible
                  case :mnesia.table_info(:test_table, :all) do
                    info when is_list(info) -> 
                      IO.puts(\"\\n📋 Test table info:\")
                      IO.inspect(info, pretty: true)
                    error -> 
                      IO.puts(\"❌ Failed to access test table: #{inspect(error)}\")
                  end
                  
                error ->
                  IO.puts(\"❌ Failed to copy schema: #{inspect(error)}\")
                  exit(1)
              end
              
            error ->
              IO.puts(\"❌ Failed to join cluster: #{inspect(error)}\")
              exit(1)
          end
          
        false ->
          IO.puts(\"❌ Could not connect to #{main_node}\")
          exit(1)
      end
      
    error -> 
      IO.puts(\"❌ Failed to start Mnesia: #{inspect(error)}\")
      exit(1)
  end
  
  # Print status
  IO.puts(\"\\n📋 Node Info:\")
  IO.puts(\"Node: #{node()}\")
  IO.puts(\"Connected nodes: #{inspect(Node.list())}\")
  IO.puts(\"Mnesia dir: #{inspect(Application.get_env(:mnesia, :dir))}\")
  
  # Keep the node running
  IO.puts(\"\\n✅ Worker node running. Press Ctrl+C to stop.\")
  Process.sleep(:infinity)
"
