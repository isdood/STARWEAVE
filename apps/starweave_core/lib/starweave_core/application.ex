defmodule StarweaveCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @doc """
  Returns the Mnesia data directory.
  """
  def mnesia_dir do
    dir = 
      case System.get_env("MNE_DATA_DIR") do
        nil -> 
          Path.join([:code.priv_dir(:starweave_core), "data", "mnesia"])
        env_dir -> 
          env_dir
      end
    
    # Ensure the directory exists and is writable
    :ok = File.mkdir_p!(dir)
    
    # Convert to charlist for Mnesia
    String.to_charlist(dir)
  end

  @doc """
  Configures Mnesia for the application.
  """
  def setup_mnesia do
    # Get Mnesia directory from config or use default
    mnesia_dir = 
      case Application.get_env(:mnesia, :dir) do
        nil ->
          dir = Path.join([File.cwd!(), "priv", "data", "mnesia"])
          String.to_charlist(dir)
        dir -> dir
      end
    
    # Ensure the directory exists and is writable
    mnesia_dir_str = List.to_string(mnesia_dir)
    File.mkdir_p!(mnesia_dir_str)
    
    # Set Mnesia directory in application env
    Application.put_env(:mnesia, :dir, mnesia_dir)
    
    # Get the current node name
    current_node = node()
    
    # Check if Mnesia is already running
    case :mnesia.system_info(:is_running) do
      :yes ->
        Logger.info("Mnesia already running on node #{inspect(current_node)}")
        :ok
        
      _ ->
        # Stop Mnesia if it's in a weird state
        :mnesia.stop()
        
        # Start Mnesia
        case :mnesia.start() do
          :ok -> 
            Logger.info("Mnesia started successfully on #{inspect(current_node)}")
            :ok
              
          {:error, {:already_started, :mnesia}} -> 
            Logger.info("Mnesia already started on #{inspect(current_node)}")
            :ok
            
          error -> 
            Logger.error("Failed to start Mnesia: #{inspect(error)}")
            error
        end
    end
  end

  @impl true
  def start(_type, _args) do
    # Setup Mnesia before starting the application
    with :ok <- setup_mnesia() do
      # Initialize Mnesia schema and tables
      :ok = StarweaveCore.Storage.Mnesia.Schema.init()
      
      # Define the children to be supervised
      children = [
        # Mnesia repository
        {StarweaveCore.Storage.Mnesia.Repo, []},
        
        # Existing services
        StarweaveCore.PatternStore,
        {StarweaveCore.Distributed.Supervisor, []},
        {StarweaveCore.Intelligence.Supervisor, []}
      ]

      # Start the supervisor
      opts = [strategy: :one_for_one, name: StarweaveCore.Supervisor]
      Supervisor.start_link(children, opts)
    else
      error ->
        Logger.error("Failed to start application due to Mnesia error: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Initializes Mnesia tables.
  """
  def init_mnesia_tables do
    # Ensure Mnesia is started
    :ok = setup_mnesia()
    
    # Initialize tables
    case StarweaveCore.Storage.Mnesia.Schema.init() do
      :ok ->
        Logger.info("Mnesia tables initialized successfully")
        :ok
      error ->
        Logger.error("Failed to initialize Mnesia tables: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Resets all Mnesia tables (for development and testing).
  WARNING: This will delete all data!
  """
  def reset_mnesia_tables! do
    :ok = setup_mnesia()
    StarweaveCore.Storage.Mnesia.Schema.reset!()
  end
end
