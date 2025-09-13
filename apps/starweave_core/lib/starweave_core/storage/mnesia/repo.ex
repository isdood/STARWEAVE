defmodule StarweaveCore.Storage.Mnesia.Repo do
  @moduledoc """
  Mnesia repository for Starweave Core.
  Provides a clean interface for working with Mnesia tables.
  """
  require Logger
  
  alias :mnesia, as: Mnesia
  alias StarweaveCore.Storage.Mnesia.Table
  
  @doc """
  Returns a specification to start this module under a supervisor.
  """
  @spec child_spec(term()) :: map()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
  
  @doc """
  Starts the Mnesia repository and ensures tables are created.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts \\ []) do
    # Get the Mnesia directory from the application environment
    mnesia_dir = Application.get_env(:mnesia, :dir) || 
      Path.join([:code.priv_dir(:starweave_core), "data", "mnesia"])
    
    # Ensure the directory exists and is writable
    mnesia_dir_str = List.to_string(mnesia_dir)
    :ok = File.mkdir_p!(mnesia_dir_str)
    
    # Set Mnesia directory and ensure it's a charlist
    mnesia_dir_charlist = 
      case mnesia_dir do
        dir when is_binary(dir) -> String.to_charlist(dir)
        dir -> dir
      end
    
    # Set the Mnesia directory and node type
    :ok = Application.put_env(:mnesia, :dir, mnesia_dir_charlist)
    :ok = Application.put_env(:mnesia, :extra_db_nodes, [])
    
    # Get current node name
    current_node = node()
    node_name = node() |> Atom.to_string()
    
    # Set master nodes to current node
    :ok = Mnesia.set_master_nodes([current_node])
    
    # Start Mnesia and create tables
    with :ok <- ensure_started(),
         :ok <- wait_for_tables(),
         :ok <- ensure_tables() do
      Logger.info("""
      Mnesia repository started successfully
      - Node: #{node_name}
      - Directory: #{inspect(mnesia_dir_charlist)}
      - Tables: #{inspect(Mnesia.system_info(:tables) -- [:schema, :sqlite_sequence])}
      """)
      {:ok, self()}
    else
      error -> 
        Logger.error("Failed to start Mnesia repository: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Returns the configured Mnesia directory.
  """
  @spec mnesia_dir() :: String.t()
  def mnesia_dir do
    case Application.get_env(:mnesia, :dir) do
      dir when is_list(dir) -> List.to_string(dir)
      _ -> 
        default_dir = Path.join([:code.priv_dir(:starweave_core), "data", "mnesia"])
        File.mkdir_p!(default_dir)
        default_dir
    end
  end

  @doc """
  Ensures Mnesia is started and the schema is initialized.
  """
  @spec ensure_started() :: :ok | {:error, term()}
  defp ensure_started do
    # Get the current node
    current_node = node()
    
    # Check if Mnesia is already running
    case :mnesia.system_info(:is_running) do
      :yes -> 
        Logger.debug("Mnesia is already running on node #{inspect(current_node)}")
        :ok
        
      _ ->
        # Get Mnesia directory
        dir = 
          case Application.get_env(:mnesia, :dir) do
            nil -> 
              dir = Path.join([:code.priv_dir(:starweave_core), "data", "mnesia"])
              File.mkdir_p!(dir)
              dir
            d when is_binary(d) -> d
            d -> d
          end
        
        # Convert directory to charlist if it's a binary
        dir_charlist = 
          case dir do
            d when is_binary(d) -> String.to_charlist(d)
            d -> d
          end
        
        # Set Mnesia directory
        :ok = Application.put_env(:mnesia, :dir, dir_charlist)
        
        # Start Mnesia
        case :mnesia.start() do
          :ok -> 
            Logger.debug("Mnesia started successfully on node #{inspect(current_node)}")
            
            # Create schema if needed
            case :mnesia.create_schema([current_node]) do
              :ok -> 
                Logger.info("Created new Mnesia schema on node #{inspect(current_node)}")
                :ok
              {:error, {:already_exists, _}} -> 
                Logger.debug("Mnesia schema already exists on node #{inspect(current_node)}")
                :ok
              error -> 
                Logger.error("Failed to create Mnesia schema: #{inspect(error)}")
                error
            end
            
          {:error, {:already_started, :mnesia}} -> 
            Logger.debug("Mnesia was already started on node #{inspect(current_node)}")
            :ok
            
          error -> 
            Logger.error("Failed to start Mnesia: #{inspect(error)}")
            error
        end
    end
  end

  @doc false
  @spec wait_for_tables() :: :ok | {:error, term()}
  defp wait_for_tables(timeout \\ 5_000) do
    case :mnesia.wait_for_tables([:schema], timeout) do
      :ok -> :ok
      {:timeout, bad_tables} -> 
        Logger.error("Timeout waiting for tables: #{inspect(bad_tables)}")
        {:error, :tables_timeout}
      {:error, reason} -> 
        Logger.error("Error waiting for tables: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc false
  @spec ensure_tables() :: :ok | {:error, term()}
  defp ensure_tables do
    # Check if tables exist and create them if they don't
    tables = [:working_memory, :pattern_store]
    
    results = Enum.map(tables, fn table ->
      case :mnesia.table_info(table, :type) do
        {:aborted, _} -> 
          Logger.info("Creating Mnesia table: #{inspect(table)}")
          create_table(table)
        _ -> 
          Logger.debug("Mnesia table already exists: #{inspect(table)}")
          :ok
      end
    end)
    
    # Check if any table creation failed
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> 
        :ok
      error -> 
        error
    end
  end
  
  @spec create_table(atom()) :: :ok | {:error, term()}
  defp create_table(:working_memory) do
    current_node = node()
    
    case :mnesia.create_table(:working_memory, [
      attributes: [:id, :context, :key, :value, :metadata],
      type: :set,
      disc_copies: [current_node],
      index: [:context, :key],
      record_name: :working_memory
    ]) do
      {:atomic, :ok} -> 
        Logger.info("Created working_memory table")
        :ok
      {:aborted, {:already_exists, :working_memory}} -> 
        Logger.debug("working_memory table already exists")
        :ok
      error -> 
        Logger.error("Failed to create working_memory table: #{inspect(error)}")
        {:error, error}
    end
  end
  
  defp create_table(:pattern_store) do
    current_node = node()
    
    case :mnesia.create_table(:pattern_store, [
      attributes: [:id, :pattern, :inserted_at],
      type: :set,
      disc_copies: [current_node],
      index: [:inserted_at],
      record_name: :pattern_store
    ]) do
      {:atomic, :ok} -> 
        Logger.info("Created pattern_store table")
        :ok
      {:aborted, {:already_exists, :pattern_store}} -> 
        Logger.debug("pattern_store table already exists")
        :ok
      error -> 
        Logger.error("Failed to create pattern_store table: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Writes a record to the specified table.
  """
  @spec write(atom(), map()) :: :ok | {:error, term()}
  def write(table, record) when is_atom(table) and is_map(record) do
    Table.write(table, record)
  end

  @doc """
  Reads a record from the specified table by primary key.
  """
  @spec read(atom(), any()) :: {:ok, map()} | {:error, :not_found | term()}
  def read(table, key) when is_atom(table) do
    Table.read(table, key)
  end

  @doc """
  Deletes a record from the specified table by primary key.
  """
  @spec delete(atom(), any()) :: :ok | {:error, term()}
  def delete(table, key) when is_atom(table) do
    Table.delete(table, key)
  end

  @doc """
  Performs a match operation on the specified table.
  """
  @spec match(atom(), any()) :: {:ok, [map()]} | {:error, term()}
  def match(table, pattern) when is_atom(table) and is_tuple(pattern) do
    Table.match(table, pattern)
  end

  @doc """
  Returns all records in the specified table.
  """
  @spec all(atom()) :: {:ok, [map()]} | {:error, term()}
  def all(table) when is_atom(table) do
    Table.all(table)
  end

  @doc """
  Executes a transaction.
  """
  @spec transaction((-> any())) :: {:atomic, any()} | {:aborted, any()}
  def transaction(fun) when is_function(fun) do
    :mnesia.transaction(fun)
  end

  @doc """
  Creates a dirty context for running operations outside a transaction.
  Use with caution as dirty operations are not atomic.
  """
  @spec dirty(atom(), [atom()], (-> any())) :: any()
  def dirty(module, fun, args) when is_atom(module) and is_atom(fun) and is_list(args) do
    apply(:mnesia, :dirty_apply, [module, fun, args])
  end
end
