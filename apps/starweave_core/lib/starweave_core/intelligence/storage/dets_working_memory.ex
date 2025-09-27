defmodule StarweaveCore.Intelligence.Storage.DetsWorkingMemory do
  @moduledoc """
  DETS-based storage implementation for WorkingMemory.
  Provides persistence for the working memory using DETS tables.
  """
  require Logger
  
  @dets_table :starweave_working_memory
  
  @doc """
  Initializes the DETS table.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    # Get configuration
    dets_dir = Application.get_env(:starweave_core, :dets_dir, "priv/data")
    dets_file = Path.join(dets_dir, Application.get_env(:starweave_core, :working_memory_file, "working_memory.dets"))
    
    # Ensure directory exists
    :ok = File.mkdir_p(dets_dir)
    
    # Try to open the DETS file with retry logic
    open_dets_file(dets_file, 3)
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
        Logger.info("DETS table initialized successfully at #{dets_file}")
        :ok
        
      {:error, {:needs_repair, _}} ->
        Logger.warning("DETS file corrupted, attempting repair: #{dets_file}")
        :ok = :dets.close(@dets_table)
        File.rm(dets_file)
        open_dets_file(dets_file, attempts - 1)
        
      error ->
        Logger.error("Failed to initialize DETS table: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Stores a value in the DETS table.
  """
  @spec store(atom(), term(), term(), integer(), float()) :: :ok | {:error, term()}
  def store(context, key, value, ttl, importance) do
    timestamp = DateTime.utc_now()
    entry = {context, key, value, timestamp, ttl, importance}
    
    case :dets.insert(@dets_table, {{context, key}, entry}) do
      :ok -> 
        :ok
      error ->
        Logger.error("Failed to store in DETS: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Retrieves a value from the DETS table.
  """
  @spec retrieve(atom(), term()) :: {:ok, term()} | :not_found | {:error, term()}
  def retrieve(context, key) do
    case :dets.lookup(@dets_table, {context, key}) do
      [{{^context, ^key}, {^context, ^key, value, _timestamp, ttl, _importance}}] ->
        if is_expired?(ttl) do
          :dets.delete(@dets_table, {context, key})
          :not_found
        else
          {:ok, value}
        end
      [] -> 
        :not_found
      error ->
        Logger.error("Failed to retrieve from DETS: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Retrieves all entries for a given context.
  """
  @spec get_context(atom()) :: [{term(), term(), map()}]
  def get_context(context) do
    case :dets.match_object(@dets_table, {{context, :_}, :_}) do
      {:error, reason} ->
        Logger.error("Failed to get context #{inspect(context)} from DETS: #{inspect(reason)}")
        []

      matches ->
        matches
        |> Enum.map(fn {{^context, key}, {^context, _key, value, timestamp, ttl, importance}} ->
          if is_expired?(ttl) do
            :dets.delete(@dets_table, {context, key})
            nil
          else
            metadata = %{
              timestamp: timestamp,
              ttl: ttl,
              importance: importance
            }
            {key, value, metadata}
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(
          fn {_key, _value, %{timestamp: ts, importance: imp}} ->
            {DateTime.to_unix(ts), imp}
          end,
          &>=/2
        )
    end
  end
  
  @doc """
  Deletes an entry from the DETS table.
  """
  @spec delete(atom(), term()) :: :ok | {:error, term()}
  def delete(context, key) do
    case :dets.delete(@dets_table, {context, key}) do
      :ok -> :ok
      error ->
        Logger.error("Failed to delete from DETS: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Clears all entries for a given context.
  """
  @spec clear_context(atom()) :: :ok | {:error, term()}
  def clear_context(context) do
    case :dets.match_delete(@dets_table, {{context, :_}, :_}) do
      :ok -> :ok
      error ->
        Logger.error("Failed to clear context #{inspect(context)} from DETS: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Performs a search across all entries.
  """
  @spec search(String.t()) :: [{term(), term(), map()}]
  def search(query) when is_binary(query) do
    query = String.downcase(query)

    case :dets.foldl(
      fn
        {{context, key}, {_, _, value, timestamp, ttl, importance} = _entry}, acc ->
          if is_expired?(ttl) do
            :dets.delete(@dets_table, {context, key})
            acc
          else
            if contains_term?(value, query) do
              metadata = %{
                timestamp: timestamp,
                ttl: ttl,
                importance: importance
              }
              [{key, value, metadata} | acc]
            else
              acc
            end
          end
      end,
      [],
      @dets_table
    ) do
      {:error, reason} ->
        Logger.error("Failed to search DETS table: #{inspect(reason)}")
        []
      results ->
        results
    end
  end
  
  # Helper function to check if a value contains a search term
  defp contains_term?(value, term) when is_binary(value) do
    String.contains?(String.downcase(value), term)
  end
  defp contains_term?(value, term) when is_atom(value) do
    String.contains?(String.downcase(Atom.to_string(value)), term)
  end
  defp contains_term?(_value, _term), do: false
  
  # Helper function to check if an entry is expired
  defp is_expired?(:infinity), do: false
  defp is_expired?(ttl) when is_integer(ttl) do
    if ttl > 0 do
      expiration_time = DateTime.utc_now() |> DateTime.add(ttl, :millisecond)
      case DateTime.compare(expiration_time, DateTime.utc_now()) do
        :lt -> true  # Expired
        _ -> false   # Not expired
      end
    else
      false
    end
  end
  
  @doc """
  Closes the DETS table.
  """
  @spec close() :: :ok | {:error, term()}
  def close do
    :dets.close(@dets_table)
  end
end
