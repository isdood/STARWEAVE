#!/bin/bash

# Clean up any existing Mnesia data
rm -rf priv/data/mnesia/*

# Start the Mnesia initialization script
elixir --sname starweave@127.0.0.1 -e "
  # Ensure the Mnesia directory exists
  File.mkdir_p!('priv/data/mnesia')
  
  # Start the Mnesia application
  :application.start(:mnesia)
  
  # Stop Mnesia to ensure clean state
  :mnesia.stop()
  
  # Create schema for the current node
  case :mnesia.create_schema([node()]) do
    :ok -> IO.puts("✅ Created new Mnesia schema for #{node()}")
    {:error, {_, {:already_exists, _}}} -> IO.puts("ℹ️ Mnesia schema already exists for #{node()}")
    error -> IO.puts("❌ Failed to create Mnesia schema: #{inspect(error)}"); exit(1)
  end
  
  # Start Mnesia
  case :mnesia.start() do
    :ok -> IO.puts("✅ Mnesia started successfully on #{node()}")
    {:error, {:already_started, :mnesia}} -> IO.puts("ℹ️ Mnesia already started on #{node()}")
    error -> IO.puts("❌ Failed to start Mnesia: #{inspect(error)}"); exit(1)
  end
  
  # Verify Mnesia is running
  if :mnesia.system_info(:is_running) == :yes do
    IO.puts("✅ Mnesia is running and ready to use")
  else
    IO.puts("❌ Mnesia failed to start properly")
    exit(1)
  end
"
