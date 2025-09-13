defmodule StarweaveCore.Storage.Mnesia.Table do
  @moduledoc """
  Mnesia table operations for Starweave Core.
  Provides a clean interface for working with Mnesia tables.
  """
  require Logger
  
  alias :mnesia, as: Mnesia
  
  @typedoc """
  Table specification for Mnesia tables.
  
  - `:type` - The type of the table (:set, :ordered_set, :bag, etc.)
  - `:attributes` - List of attribute names (atoms)
  - `:disc_copies` - Nodes where the table should have disc copies
  - `:index` - List of attributes to create secondary indexes for
  - `:storage_properties` - Additional storage properties
  """
  @type table_spec :: [
    type: :set | :ordered_set | :bag,
    attributes: [atom()],
    disc_copies: [node()],
    index: [atom()],
    storage_properties: keyword()
  ]

  @doc """
  Creates a new Mnesia table with the given name and options.
  """
  @spec create(atom(), table_spec()) :: {:ok, atom()} | {:error, term()}
  def create(table_name, table_opts) when is_atom(table_name) and is_list(table_opts) do
    # Prepare table definition with defaults
    table_def = [
      attributes: Keyword.fetch!(table_opts, :attributes),
      disc_copies: table_opts[:disc_copies] || [node()],
      type: table_opts[:type] || :set,
      storage_properties: table_opts[:storage_properties] || []
    ]

    # Create the table in a transaction
    Mnesia.transaction(fn ->
      case Mnesia.create_table(table_name, table_def) do
        {:atomic, :ok} -> 
          # Create secondary indexes if any
          :ok = create_indexes(table_name, table_opts[:index] || [])
          {:ok, table_name}
        error -> 
          Logger.error("Failed to create table #{table_name}: #{inspect(error)}")
          error
      end
    end)
    |> case do
      {:atomic, result} -> result
      error -> error
    end
  end

  @doc """
  Creates secondary indexes for the given table.
  """
  @spec create_indexes(atom(), [atom()]) :: :ok | {:error, term()}
  def create_indexes(_table, []), do: :ok
  
  def create_indexes(table, [index | rest]) do
    Mnesia.transaction(fn ->
      case Mnesia.add_table_index(table, index) do
        {:atomic, :ok} -> 
          Logger.debug("Created index #{inspect(index)} on table #{inspect(table)}")
          create_indexes(table, rest)
        error -> 
          Logger.error("Failed to create index #{inspect(index)} on table #{inspect(table)}: #{inspect(error)}")
          error
      end
    end)
    |> case do
      {:atomic, result} -> result
      error -> error
    end
  end

  @doc """
  Writes a record to the specified table.
  """
  @spec write(atom(), map()) :: :ok | {:error, term()}
  def write(table, record) when is_atom(table) and is_map(record) do
    transaction = fn ->
      case Mnesia.write(table, record, :write) do
        :ok -> :ok
        {:aborted, reason} -> {:error, reason}
      end
    end

    case Mnesia.transaction(transaction) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Reads a record from the specified table by primary key.
  """
  @spec read(atom(), any()) :: {:ok, map()} | {:error, :not_found | term()}
  def read(table, key) when is_atom(table) do
    transaction = fn ->
      case Mnesia.read(table, key) do
        [record] -> {:ok, record}
        [] -> {:error, :not_found}
      end
    end

    case Mnesia.transaction(transaction) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a record from the specified table by primary key.
  """
  @spec delete(atom(), any()) :: :ok | {:error, term()}
  def delete(table, key) when is_atom(table) do
    transaction = fn ->
      case Mnesia.delete({table, key}) do
        :ok -> :ok
        {:aborted, reason} -> {:error, reason}
      end
    end

    case Mnesia.transaction(transaction) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Performs a match operation on the specified table.
  """
  @spec match(atom(), any()) :: {:ok, [map()]} | {:error, term()}
  def match(table, pattern) when is_atom(table) and is_tuple(pattern) do
    transaction = fn ->
      case Mnesia.match_object(table, pattern, :read) do
        {:aborted, reason} -> {:error, reason}
        results -> {:ok, results}
      end
    end

    case Mnesia.transaction(transaction) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns all records in the specified table.
  """
  @spec all(atom()) :: {:ok, [map()]} | {:error, term()}
  def all(table) when is_atom(table) do
    transaction = fn ->
      case Mnesia.match_object(table, Mnesia.table_info(table, :wild_pattern), :read) do
        {:aborted, reason} -> {:error, reason}
        results -> {:ok, results}
      end
    end

    case Mnesia.transaction(transaction) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end
end
