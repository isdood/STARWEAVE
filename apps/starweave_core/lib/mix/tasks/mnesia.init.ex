defmodule Mix.Tasks.Mnesia.Init do
  use Mix.Task
  require Logger

  @shortdoc "Initialize Mnesia database"
  @moduledoc """
  Initializes the Mnesia database with the proper schema and tables.
  """

  @impl Mix.Task
  def run(_args) do
    # Set node name if not already set
    if Node.self() == :nonode@nohost do
      node_name = :"starweave@127.0.0.1"
      :net_kernel.start([node_name, :longnames])
    end

    # Get Mnesia directory from config or use default
    mnesia_dir = 
      case Application.get_env(:mnesia, :dir) do
        nil ->
          dir = Path.join([File.cwd!(), "priv", "data", "mnesia"])
          String.to_charlist(dir)
        dir -> dir
      end

    # Ensure the directory exists
    mnesia_dir_str = List.to_string(mnesia_dir)
    File.mkdir_p!(mnesia_dir_str)
    Logger.info("Mnesia directory: #{mnesia_dir_str}")

    # Stop Mnesia if it's running
    :mnesia.stop()

    # Set Mnesia directory in application env (this is the recommended way)
    Application.put_env(:mnesia, :dir, mnesia_dir)

    # Create schema for the current node
    case :mnesia.create_schema([node()]) do
      :ok ->
        Logger.info("Created new Mnesia schema for node #{inspect(node())}")
      {:error, {_, {:already_exists, _}}} ->
        Logger.info("Mnesia schema already exists for node #{inspect(node())}")
      error ->
        Logger.error("Failed to create Mnesia schema: #{inspect(error)}")
        exit({:error, error})
    end

    # Start Mnesia
    case :mnesia.start() do
      :ok ->
        Logger.info("Mnesia started successfully on node #{inspect(node())}")
      {:error, {:already_started, :mnesia}} ->
        Logger.info("Mnesia already started on node #{inspect(node())}")
      error ->
        Logger.error("Failed to start Mnesia: #{inspect(error)}")
        exit({:error, error})
    end

    # Verify Mnesia is running
    if :mnesia.system_info(:is_running) == :yes do
      Logger.info("Mnesia is running and ready to use")
    else
      Logger.error("Mnesia failed to start properly")
      exit({:error, :mnesia_not_running})
    end
  end
end
