# Script to initialize Mnesia with proper settings

# Set the node name
node_name = :"starweave@localhost"
:net_kernel.start([node_name, :longnames])

# Set Mnesia directory
mnesia_dir = Path.join([File.cwd!(), "priv", "data", "mnesia"])
:ok = File.mkdir_p!(mnesia_dir)

# Configure Mnesia
:ok = :mnesia.system_info(:directory, String.to_charlist(mnesia_dir))

# Stop Mnesia if it's running
:mnesia.stop()

# Delete any existing schema
schema_file = Path.join(mnesia_dir, "schema.DAT")
if File.exists?(schema_file) do
  IO.puts("Removing existing schema file...")
  File.rm!(schema_file)
end

# Create a new schema
case :mnesia.create_schema([node()]) do
  :ok -> 
    IO.puts("Created new Mnesia schema in #{mnesia_dir}")
    :ok
    
  {:error, {_, {:already_exists, _}}} ->
    IO.puts("Mnesia schema already exists")
    :ok
    
  error ->
    IO.puts("Failed to create Mnesia schema: #{inspect(error)}")
    error
end

# Start Mnesia
case :mnesia.start() do
  :ok -> 
    IO.puts("Mnesia started successfully on node #{inspect(node())}")
    :ok
      
  {:error, {:already_started, :mnesia}} -> 
    IO.puts("Mnesia already started")
    :ok
    
  error -> 
    IO.puts("Failed to start Mnesia: #{inspect(error)}")
    error
end

# Keep the script running
receive do
  _ -> :ok
end
