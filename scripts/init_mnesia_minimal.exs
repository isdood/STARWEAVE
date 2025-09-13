# Set the node name before starting any applications
Node.start(:"starweave@127.0.0.1")
:net_kernel.set_net_ticktime(10)

# Set Mnesia directory
mnesia_dir = Path.join(File.cwd!(), "priv/data/mnesia")
File.mkdir_p!(mnesia_dir)
IO.puts("Mnesia directory: #{mnesia_dir}")

# Set Mnesia directory in application env
Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))

# Start Mnesia
case :mnesia.start() do
  :ok -> IO.puts("✅ Mnesia started successfully")
  {:error, {:already_started, :mnesia}} -> IO.puts("ℹ️ Mnesia already started")
  error -> IO.puts("❌ Failed to start Mnesia: #{inspect(error)}")
end

# Create schema if it doesn't exist
case :mnesia.create_schema([node()]) do
  :ok -> IO.puts("✅ Created new Mnesia schema")
  {:error, {_, {:already_exists, _}}} -> IO.puts("ℹ️ Mnesia schema already exists")
  error -> IO.puts("❌ Failed to create Mnesia schema: #{inspect(error)}")
end

# Verify Mnesia is running
if :mnesia.system_info(:is_running) == :yes do
  IO.puts("✅ Mnesia is running and ready to use")
  :init.stop(0)
else
  IO.puts("❌ Mnesia failed to start properly")
  :init.stop(1)
end
