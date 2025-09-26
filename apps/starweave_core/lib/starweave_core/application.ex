defmodule StarweaveCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  
  alias StarweaveCore.Intelligence.Storage.DetsWorkingMemory
  alias StarweaveCore.Pattern.Storage.DetsPatternStore

  @dets_services [
    DetsWorkingMemory,
    DetsPatternStore
  ]

  @doc """
  Initializes the DETS storage directory.
  """
  def setup_dets do
    # Get DETS directory from config or use default
    dets_dir = Application.get_env(:starweave_core, :dets_dir, "priv/data")
    
    # Create data directory if it doesn't exist
    :ok = File.mkdir_p(dets_dir)
    :ok
  end

  @impl true
  def start(_type, _args) do
    # Setup DETS storage directory
    :ok = setup_dets()
    
    # Define the children to be supervised
    children = [
      # Pattern Store (using DETS)
      StarweaveCore.PatternStore,
      
      # Distributed services
      {StarweaveCore.Distributed.Supervisor, []},
      
      # Intelligence services (includes WorkingMemory)
      {StarweaveCore.Intelligence.Supervisor, []},
      
      # Autonomous systems
      {StarweaveCore.Autonomous.Supervisor, []}
    ]

    # Start the supervisor
    opts = [strategy: :one_for_one, name: StarweaveCore.Supervisor]
    case Supervisor.start_link(children, opts) do
      {:ok, sup} ->
        # Initialize DETS tables after startup
        initialize_dets_tables()
        {:ok, sup}
      error ->
        error
    end
  end
  
  @impl true
  def stop(_state) do
    # Close all DETS tables on application stop
    Enum.each(@dets_services, fn module ->
      if function_exported?(module, :close, 0) do
        case apply(module, :close, []) do
          :ok -> :ok
          error -> 
            Logger.error("Failed to close DETS table for #{inspect(module)}: #{inspect(error)}")
        end
      end
    end)
    :ok
  end
  
  defp initialize_dets_tables do
    Enum.each(@dets_services, fn module ->
      case module.init() do
        :ok -> 
          Logger.info("Successfully initialized #{inspect(module)}")
        error ->
          Logger.error("Failed to initialize #{inspect(module)}: #{inspect(error)}")
      end
    end)
  end
  
  @doc """
  Resets all data (for development and testing).
  WARNING: This will delete all data!
  """
  def reset_data! do
    # Close all DETS tables first
    Enum.each(@dets_services, fn module ->
      if function_exported?(module, :close, 0) do
        apply(module, :close, [])
      end
    end)
    
    # Clean up DETS files
    dets_dir = Application.get_env(:starweave_core, :dets_dir, "priv/data")
    
    # Delete DETS files
    File.rm_rf!(Path.join(dets_dir, Application.get_env(:starweave_core, :working_memory_file, "working_memory.dets")))
    File.rm_rf!(Path.join(dets_dir, Application.get_env(:starweave_core, :pattern_store_file, "patterns.dets")))
    
    :ok
  end
end
