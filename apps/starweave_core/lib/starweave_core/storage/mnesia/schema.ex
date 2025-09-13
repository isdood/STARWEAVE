defmodule StarweaveCore.Storage.Mnesia.Schema do
  @moduledoc """
  Mnesia schema management for Starweave Core.
  Handles table creation, schema updates, and database initialization.
  """
  require Logger
  
  alias :mnesia, as: Mnesia
  alias StarweaveCore.Storage.Mnesia.Table
  
  @doc """
  Initializes the Mnesia schema and creates all required tables.
  This should be called during application startup.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    :ok = ensure_schema()
    :ok = create_tables()
  end

  @doc """
  Ensures the Mnesia schema exists and is ready for use.
  Creates the schema if it doesn't exist.
  """
  @spec ensure_schema() :: :ok | {:error, term()}
  def ensure_schema do
    # Check if Mnesia is running, start it if not
    case :mnesia.system_info(:is_running) do
      :yes -> 
        Logger.debug("Mnesia is already running")
        :ok
      _ ->
        Logger.info("Starting Mnesia...")
        :mnesia.start()
    end
    
    # Create schema if it doesn't exist
    case :mnesia.create_schema([node()]) do
      :ok -> 
        Logger.info("Created new Mnesia schema")
        :ok
      {:error, {_node, {:already_exists, _}}} -> 
        Logger.debug("Mnesia schema already exists")
        :ok
      error -> 
        Logger.error("Failed to create Mnesia schema: #{inspect(error)}")
        error
    end
  end

  @doc """
  Creates all configured Mnesia tables.
  """
  @spec create_tables() :: :ok | {:error, term()}
  def create_tables do
    # Get the current node
    current_node = node()
    
    # Start Mnesia if not already started
    case :mnesia.system_info(:is_running) do
      :no -> :mnesia.start()
      _ -> :ok
    end
    
    # Ensure the schema is ready
    :mnesia.wait_for_tables([:schema], 5_000)
    
    # Define table schemas with Mnesia table definitions
    tables = [
      # Working memory table - stores agent's working memory
      {
        :working_memory,                                  # Table name
        [
          {:attributes, [:id, :context, :key, :value, :metadata]},  # Attributes
          {:type, :set},                                 # Table type
          {:disc_copies, [current_node]},                # Storage type on current node
          {:index, [:context, :key]}                     # Indexes
        ]
      },
      # Pattern store table - stores learned patterns
      {
        :pattern_store,
        [
          {:attributes, [:id, :pattern, :inserted_at]},
          {:type, :set},
          {:disc_copies, [current_node]},
          {:index, [:inserted_at]}
        ]
      }
    ]

    # Create each table with its configuration
    results = Enum.map(tables, fn {table_name, table_opts} ->
      case Mnesia.create_table(table_name, table_opts) do
        {:atomic, :ok} -> 
          Logger.info("Created Mnesia table: #{inspect(table_name)}")
          :ok
        {:aborted, {:already_exists, ^table_name}} -> 
          Logger.debug("Mnesia table already exists: #{inspect(table_name)}")
          :ok
        {:aborted, error} ->
          error_msg = "Failed to create Mnesia table #{inspect(table_name)}: #{inspect(error)}"
          Logger.error(error_msg)
          {:error, {table_name, error}}
      end
    end)
    
    # Check if any table creation failed
    case Enum.find(results, &(match?({:error, _}, &1))) do
      nil -> :ok
      error -> error
    end
    
    :ok
  end

  @doc """
  Drops all Mnesia tables and recreates them.
  WARNING: This will delete all data!
  """
  @spec reset!() :: :ok | {:error, term()}
  def reset! do
    Mnesia.stop()
    Mnesia.delete_schema([node()])
    Mnesia.start()
    init()
  end
end
