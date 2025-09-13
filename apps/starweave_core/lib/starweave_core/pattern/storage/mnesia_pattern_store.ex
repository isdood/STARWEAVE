defmodule StarweaveCore.Pattern.Storage.MnesiaPatternStore do
  @moduledoc """
  Mnesia-based storage implementation for PatternStore.
  """
  require Logger
  
  alias StarweaveCore.Storage.Mnesia.Repo
  alias StarweaveCore.Pattern
  
  @table :pattern_store
  
  @doc """
  Stores a pattern in the database.
  """
  @spec put(Pattern.t()) :: :ok | {:error, term()}
  def put(%Pattern{} = pattern) do
    now = System.system_time(:millisecond)
    pattern = %{pattern | inserted_at: pattern.inserted_at || now}
    
    # Convert the pattern to a map to ensure it can be stored in Mnesia
    pattern_map = %{
      id: pattern.id,
      pattern: Map.from_struct(pattern),
      inserted_at: pattern.inserted_at
    }
    
    case Repo.write(@table, pattern_map) do
      :ok -> :ok
      error -> 
        Logger.error("Failed to store pattern: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Retrieves a pattern by ID.
  """
  @spec get(String.t()) :: {:ok, Pattern.t()} | :not_found | {:error, term()}
  def get(id) when is_binary(id) do
    case Repo.read(@table, id) do
      {:ok, %{pattern: pattern_map}} -> 
        # Convert the map back to a Pattern struct
        pattern = struct(Pattern, pattern_map)
        {:ok, pattern}
      {:error, :not_found} -> :not_found
      error -> error
    end
  end
  
  @doc """
  Retrieves all patterns.
  """
  @spec all() :: {:ok, [Pattern.t()]} | {:error, term()}
  def all do
    case Repo.all(@table) do
      {:ok, patterns} -> 
        patterns = 
          patterns
          |> Enum.map(fn %{pattern: pattern_map} ->
            # Convert each pattern map back to a Pattern struct
            struct(Pattern, pattern_map)
          end)
          |> Enum.sort_by(& &1.inserted_at, :desc)
          
        {:ok, patterns}
      error -> error
    end
  end
  
  @doc """
  Deletes all patterns.
  """
  @spec clear() :: :ok | {:error, term()}
  def clear do
    case Repo.all(@table) do
      {:ok, patterns} ->
        # Delete each pattern
        patterns
        |> Enum.each(fn %{id: id} -> Repo.delete(@table, id) end)
        
        :ok
        
      error -> 
        Logger.error("Failed to clear patterns: #{inspect(error)}")
        error
    end
  end
end
