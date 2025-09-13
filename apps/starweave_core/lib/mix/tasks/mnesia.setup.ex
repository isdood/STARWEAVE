defmodule Mix.Tasks.Mnesia.Setup do
  use Mix.Task
  require Logger

  @shortdoc "Initialize Mnesia database with schema and tables"
  
  @moduledoc """
  Initializes the Mnesia database with the proper schema and tables.
  This task should be run before starting the application.
  """

  @doc false
  def run(_args) do
    # Set node name
    node_name = System.get_env("NODE_NAME") || "starweave@127.0.0.1"
    Node.start(:"#{node_name}")
    :net_kernel.set_net_ticktime(10)

    # Set Mnesia directory
    mnesia_dir = Path.join(File.cwd!(), "priv/data/mnesia")
    File.mkdir_p!(mnesia_dir)
    Logger.info("Mnesia directory: #{mnesia_dir}")

    # Set Mnesia directory in application env
    Application.put_env(:mnesia, :dir, String.to_charlist(mnesia_dir))

    # Stop Mnesia if it's running
    :mnesia.stop()

    # Create schema
    case :mnesia.create_schema([node()]) do
      :ok -> 
        Logger.info("✅ Created new Mnesia schema for #{node()}")
      {:error, {_, {:already_exists, _}}} -> 
        Logger.info("ℹ️ Mnesia schema already exists for #{node()}")
      error -> 
        Logger.error("❌ Failed to create Mnesia schema: #{inspect(error)}")
        exit(1)
    end

    # Start Mnesia
    case :mnesia.start() do
      :ok -> 
        Logger.info("✅ Mnesia started successfully on #{node()}")
      {:error, {:already_started, :mnesia}} -> 
        Logger.info("ℹ️ Mnesia already started on #{node()}")
      error -> 
        Logger.error("❌ Failed to start Mnesia: #{inspect(error)}")
        exit(1)
    end

    # Verify Mnesia is running
    if :mnesia.system_info(:is_running) == :yes do
      Logger.info("✅ Mnesia is running and ready to use")
      :init.stop(0)
    else
      Logger.error("❌ Mnesia failed to start properly")
      :init.stop(1)
    end
  end
end
