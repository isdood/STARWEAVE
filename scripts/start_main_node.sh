#!/bin/bash

# Clean up any running nodes
pkill -f "beam.smp" || true

# Start the main node
iex --sname main --cookie starweave-cookie -e "
  # Set Mnesia directory
  mnesia_dir = \"priv/mnesia/main\"
  File.mkdir_p!(mnesia_dir)
  Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))
  
  # Stop Mnesia if running
  :mnesia.stop()
  
  # Create schema
  case :mnesia.create_schema([node()]) do
    :ok -> IO.puts(\"✅ Created schema for #{node()}\")
    {:error, {_, {:already_exists, _}}} -> IO.puts(\"ℹ️ Schema already exists for #{node()}\")
    error -> IO.puts(\"❌ Failed to create schema: #{inspect(error)}\"); exit(1)
  end
  
  # Start Mnesia
  case :mnesia.start() do
    :ok -> 
      IO.puts(\"✅ Mnesia started on #{node()}\")
      
      # Create a test table
      case :mnesia.create_table(:test_table, [
        {:disc_copies, [node()]},
        {:attributes, [:id, :data]}
      ]) do
        {:atomic, :ok} -> IO.puts(\"✅ Created test table\")
        error -> IO.puts(\"❌ Failed to create test table: #{inspect(error)}\")
      end
      
    error -> 
      IO.puts(\"❌ Failed to start Mnesia: #{inspect(error)}\")
      exit(1)
  end
  
  # Print status
  IO.puts(\"\\n📋 Node Info:\")
  IO.puts(\"Node: #{node()}\")
  IO.puts(\"Cookie: #{inspect(Node.get_cookie())}\")
  IO.puts(\"Mnesia dir: #{inspect(Application.get_env(:mnesia, :dir))}\")
  IO.puts(\"\\n📋 Mnesia Tables:\")
  IO.inspect(:mnesia.system_info(:tables), pretty: true)
  
  # Keep the node running
  IO.puts(\"\\n✅ Main node running. Press Ctrl+C to stop.\")
  Process.sleep(:infinity)
"
