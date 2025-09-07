defmodule StarweaveCore.Intelligence.MemoryPersistence do
  @moduledoc """
  Handles persistence of working memory to disk to survive application restarts.
  Uses the application's data directory to store memory dumps.
  """
  
  require Logger
  
  @data_dir "priv/data/memories"
  
  @doc """
  Saves the current state of the working memory to disk.
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec save_memories(term()) :: :ok | {:error, term()}
  def save_memories(entries) when is_list(entries) do
    data_dir = data_dir()
    file_path = Path.join(data_dir, "working_memory.etf")
    
    # Ensure the directory exists
    File.mkdir_p!(data_dir)
    
    # Convert entries to a format suitable for storage
    serializable_entries = 
      Enum.map(entries, fn {{context, key}, %{value: value, timestamp: ts, ttl: ttl, importance: imp, expires_at: exp}} ->
        {{context, key}, %{
          value: value,
          timestamp: ts,
          ttl: ttl,
          importance: imp,
          expires_at: exp
        }}
      end)
    
    # Write to a temporary file first, then rename atomically
    temp_path = file_path <> ".tmp"
    
    case :file.write_file(temp_path, :erlang.term_to_binary(serializable_entries)) do
      :ok ->
        case File.rename(temp_path, file_path) do
          :ok -> 
            Logger.info("Successfully saved #{length(entries)} memories to disk")
            :ok
          {:error, reason} ->
            File.rm(temp_path)
            Logger.error("Failed to rename temp memory file: #{inspect(reason)}")
            {:error, reason}
        end
      error ->
        Logger.error("Failed to write memory file: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Loads previously saved memories from disk.
  Returns a list of memory entries or an empty list if no saved memories exist.
  """
  @spec load_memories() :: [{{atom(), term()}, map()}]
  def load_memories do
    file_path = Path.join(data_dir(), "working_memory.etf")
    
    case File.read(file_path) do
      {:ok, binary} ->
        try do
          :erlang.binary_to_term(binary)
        rescue
          e ->
            Logger.error("Failed to deserialize memory file: #{inspect(e)}")
            []
        end
      {:error, :enoent} ->
        Logger.info("No existing memory file found at #{file_path}")
        []
      {:error, reason} ->
        Logger.error("Failed to read memory file: #{inspect(reason)}")
        []
    end
  end
  
  @doc """
  Clears all persisted memories from disk.
  """
  @spec clear_persisted_memories() :: :ok | {:error, term()}
  def clear_persisted_memories do
    file_path = Path.join(data_dir(), "working_memory.etf")
    
    case File.rm(file_path) do
      :ok -> 
        Logger.info("Successfully cleared persisted memories")
        :ok
      {:error, :enoent} -> 
        Logger.info("No memory file to delete")
        :ok
      error -> 
        Logger.error("Failed to delete memory file: #{inspect(error)}")
        error
    end
  end
  
  # Private functions
  
  defp data_dir do
    Application.app_dir(:starweave_core, @data_dir)
  end
end
