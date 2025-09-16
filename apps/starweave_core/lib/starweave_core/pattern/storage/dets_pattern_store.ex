defmodule StarweaveCore.Pattern.Storage.DetsPatternStore do
  @moduledoc """
  DETS-based storage for patterns.
  
  This module provides a simple key-value store for patterns using DETS.
  Each pattern is stored with a unique ID as the key and the pattern data as the value.
  """
  require Logger
  
  @dets_table :starweave_patterns
  
  @type pattern_id :: String.t()
  @type pattern_data :: map()
  
  @doc """
  Initializes the DETS table.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    # Get configuration
    dets_dir = Application.get_env(:starweave_core, :dets_dir, "priv/data")
    dets_file = Path.join(dets_dir, Application.get_env(:starweave_core, :pattern_store_file, "patterns.dets"))
    
    # Ensure directory exists
    :ok = File.mkdir_p(dets_dir)
    
    # Close the table if it's already open
    _ = :dets.close(@dets_table)
    
    # Try to open the DETS file with retry logic
    open_dets_file(dets_file, 3)
  end
  
  @doc """
  Ensures the DETS table is open. If not, tries to reopen it.
  """
  @spec ensure_open() :: :ok | {:error, term()}
  def ensure_open do
    case :dets.info(@dets_table) do
      :undefined -> 
        init()
      _ -> 
        :ok
    end
  end
  
  defp open_dets_file(dets_file, 0) do
    error = "Failed to open DETS file after multiple attempts: #{dets_file}"
    Logger.error(error)
    {:error, error}
  end
  
  defp open_dets_file(dets_file, attempts) do
    case :dets.open_file(@dets_table, [
      {:file, String.to_charlist(dets_file)},
      {:type, :set},
      {:repair, true},
      {:auto_save, 60_000}  # Auto-save every minute
    ]) do
      {:ok, _} ->
        Logger.info("Pattern DETS table initialized successfully at #{dets_file}")
        :ok
        
      {:error, {:needs_repair, _}} ->
        Logger.warning("DETS file corrupted, attempting repair: #{dets_file}")
        :ok = :dets.close(@dets_table)
        File.rm(dets_file)
        open_dets_file(dets_file, attempts - 1)
        
      error ->
        Logger.error("Failed to initialize Pattern DETS table: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Stores a pattern in the DETS table.
  
  ## Parameters
    - `id`: The unique identifier for the pattern
    - `pattern_data`: The pattern data to store (should be a map)
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec put(pattern_id, pattern_data) :: :ok | {:error, term()}
  def put(id, data) when is_binary(id) and is_map(data) do
    :ok = ensure_open()
    case :dets.insert(@dets_table, {id, data}) do
      :ok -> 
        :ok
      error -> 
        Logger.error("Failed to store pattern #{id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Retrieves a pattern by ID.
  
  Returns `{:ok, pattern_data}` if found, `:not_found` if not found,
  or `{:error, reason}` on failure.
  """
  @spec get(pattern_id) :: {:ok, pattern_data} | :not_found | {:error, term()}
  def get(id) when is_binary(id) do
    :ok = ensure_open()
    case :dets.lookup(@dets_table, id) do
      [{^id, data}] -> 
        {:ok, data}
      [] -> 
        :not_found
      error -> 
        Logger.error("Error looking up pattern #{id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Retrieves all patterns.
  
  Returns `{:ok, patterns}` where patterns is a list of `{id, pattern_data}` tuples,
  or `{:error, reason}` on failure.
  """
  @spec all() :: [{pattern_id, pattern_data}]
  def all do
    :ok = ensure_open()
    case :dets.match_object(@dets_table, :_) do
      {:error, reason} -> 
        Logger.error("Error reading from DETS: #{inspect(reason)}")
        []
      objects -> 
        objects
    end
  end

  @doc """
  Deletes a pattern by ID.
  
  Returns `:ok` on success, `:not_found` if the pattern doesn't exist,
  or `{:error, reason}` on failure.
  """
  @spec delete(pattern_id) :: :ok | {:error, term()}
  def delete(id) when is_binary(id) do
    :ok = ensure_open()
    case :dets.delete(@dets_table, id) do
      :ok -> 
        :ok
      error -> 
        Logger.error("Failed to delete pattern #{id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Deletes all patterns.
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec clear() :: :ok | {:error, term()}
  def clear do
    :ok = ensure_open()
    case :dets.delete_all_objects(@dets_table) do
      :ok -> 
        # Ensure changes are synced to disk
        :ok = :dets.sync(@dets_table)
        :ok
      error ->
        Logger.error("Error clearing patterns: #{inspect(error)}")
        error
    end
  end

  @doc """
  Closes the DETS table.
  
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec close() :: :ok | {:error, term()}
  def close do
    case :dets.info(@dets_table) do
      :undefined -> 
        :ok  # Already closed
      _ ->
        case :dets.close(@dets_table) do
          :ok -> 
            :ok
          {:error, reason} ->
            Logger.error("Error closing DETS table: #{inspect(reason)}")
            {:error, reason}
          error ->
            Logger.error("Unexpected error closing DETS table: #{inspect(error)}")
            {:error, error}
        end
    end
  end
end
