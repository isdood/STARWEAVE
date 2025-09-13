# Simple Mnesia initialization script

# Set Mnesia directory
mnesia_dir = Path.join(File.cwd!(), "priv/data/mnesia")
File.mkdir_p!(mnesia_dir)
IO.puts("Mnesia directory: #{mnesia_dir}")

# Configure Mnesia
Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))

# Start Mnesia if not already started
if :mnesia.system_info(:is_running) != :yes do
  case :mnesia.start() do
    :ok -> IO.puts("✅ Mnesia started successfully")
    {:error, {:already_started, :mnesia}} -> IO.puts("ℹ️ Mnesia already started")
    error -> IO.puts("❌ Failed to start Mnesia: #{inspect(error)}"); exit(1)
  end
end

# Create schema if it doesn't exist
if :mnesia.system_info(:is_running) == :yes do
  case :mnesia.create_schema([node()]) do
    :ok -> IO.puts("✅ Created new Mnesia schema")
    {:error, {_, {:already_exists, _}}} -> IO.puts("ℹ️ Mnesia schema already exists")
    error -> IO.puts("❌ Failed to create Mnesia schema: #{inspect(error)}")
  end
else
  IO.puts("❌ Mnesia is not running")
  exit(1)
end

IO.puts("Mnesia is ready to use")
:init.stop(0)
