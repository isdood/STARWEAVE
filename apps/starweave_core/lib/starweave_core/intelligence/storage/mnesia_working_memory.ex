defmodule StarweaveCore.Intelligence.Storage.MnesiaWorkingMemory do
  @moduledoc """
  Mnesia-based storage implementation for WorkingMemory.
  """
  
  alias StarweaveCore.Storage.Mnesia.Repo
  require Logger
  
  @table :working_memory
  
  @doc """
  Stores a value in working memory.
  """
  @spec store(atom(), any(), any(), keyword()) :: :ok | {:error, term()}
  def store(context, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, :infinity)
    importance = Keyword.get(opts, :importance, 0.5)
    now = System.system_time(:millisecond)
    
    record = %{
      id: {context, key},
      context: context,
      key: key,
      value: value,
      metadata: %{
        ttl: ttl,
        importance: importance,
        inserted_at: now,
        updated_at: now
      }
    }
    
    case Repo.write(@table, record) do
      :ok -> :ok
      error -> 
        Logger.error("Failed to store in Mnesia: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Retrieves a value from working memory.
  """
  @spec retrieve(atom(), any()) :: {:ok, any()} | :not_found | {:error, term()}
  def retrieve(context, key) do
    case Repo.read(@table, {context, key}) do
      {:ok, record} -> 
        if expired?(record) do
          # Clean up expired record
          Repo.delete(@table, {context, key})
          :not_found
        else
          {:ok, record.value}
        end
      {:error, :not_found} -> 
        :not_found
      error -> 
        Logger.error("Failed to retrieve from Mnesia: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Retrieves all entries for a context.
  """
  @spec get_context(atom()) :: {:ok, [map()]} | {:error, term()}
  def get_context(context) do
    case Repo.match(@table, {@table, {context, :_}, :_, :_, :_, :_, :_}) do
      {:ok, records} ->
        # Filter out expired records
        {valid, expired} = Enum.split_with(records, &(!expired?(&1)))
        
        # Clean up expired records
        for record <- expired do
          Repo.delete(@table, record.id)
        end
        
        # Format the results
        results = 
          valid
          |> Enum.map(fn record ->
            %{
              key: record.key,
              value: record.value,
              metadata: record.metadata
            }
          end)
          
        {:ok, results}
      
      error ->
        Logger.error("Failed to get context from Mnesia: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Deletes an entry from working memory.
  """
  @spec delete(atom(), any()) :: :ok | {:error, term()}
  def delete(context, key) do
    Repo.delete(@table, {context, key})
  end
  
  @doc """
  Performs a search across all entries.
  """
  @spec search(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search(query, _opts \\ []) do
    # This is a simple implementation - you might want to use a proper search index
    case Repo.all(@table) do
      {:ok, records} ->
        query = String.downcase(query)
        
        results =
          records
          |> Enum.filter(fn record ->
            # Simple string matching - consider using a proper search solution
            value_str = inspect(record.value) |> String.downcase()
            String.contains?(value_str, query) && !expired?(record)
          end)
          |> Enum.map(fn record ->
            %{
              context: record.context,
              key: record.key,
              value: record.value,
              metadata: record.metadata
            }
          end)
          
        {:ok, results}
        
      error ->
        Logger.error("Failed to search Mnesia: #{inspect(error)}")
        error
    end
  end
  
  # Private functions
  
  defp expired?(%{metadata: %{ttl: :infinity}}), do: false
  defp expired?(%{metadata: %{ttl: ttl, inserted_at: inserted_at}}) do
    now = System.system_time(:millisecond)
    (now - inserted_at) > ttl
  end
  defp expired?(_), do: false
end
