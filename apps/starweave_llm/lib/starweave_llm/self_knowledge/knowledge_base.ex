defmodule StarweaveLLM.SelfKnowledge.KnowledgeBase do
  @moduledoc """
  Manages the DETS-based storage for the self-knowledge system.
  """

  use GenServer
  require Logger

  alias __MODULE__

  defstruct [
    :table_name,
    :dets_path,
    :dets_ref
  ]

  # Public API

  @doc """
  Starts the KnowledgeBase GenServer.
  """
  def start_link(opts) do
    table_name = Keyword.fetch!(opts, :table_name)
    dets_path = Keyword.fetch!(opts, :dets_path)
    GenServer.start_link(__MODULE__, {table_name, dets_path}, name: via_tuple(table_name))
  end

  @doc """
  Loads the knowledge base from disk.
  """
  def load(knowledge_base) do
    GenServer.call(knowledge_base, :load)
  end

  @doc """
  Persists the knowledge base to disk.
  """
  def persist(knowledge_base) do
    GenServer.call(knowledge_base, :persist)
  end

  @doc """
  Clears all entries from the knowledge base.
  """
  def clear(knowledge_base) do
    GenServer.call(knowledge_base, :clear)
  end

  @doc """
  Inserts or updates an entry in the knowledge base.
  """
  def put(knowledge_base, id, entry) do
    GenServer.call(knowledge_base, {:put, id, entry})
  end

  @doc """
  Retrieves an entry from the knowledge base by ID.
  """
  def get(knowledge_base, id) do
    GenServer.call(knowledge_base, {:get, id})
  end

  @doc """
  Searches for entries matching the given query.
  """
  def search(knowledge_base, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    GenServer.call(knowledge_base, {:search, query, limit})
  end

  # GenServer Callbacks

  @impl true
  def init({table_name, dets_path}) do
    # Ensure the directory exists
    File.mkdir_p(Path.dirname(dets_path))
    
    # Open or create the DETS table
    case :dets.open_file(table_name, [
      {:file, dets_path},
      {:type, :set},
      {:auto_save, 60_000},  # Auto-save every minute
      {:repair, true}
    ]) do
      {:ok, dets_ref} ->
        Logger.info("Opened DETS table at #{dets_path}")
        {:ok, %KnowledgeBase{
          table_name: table_name,
          dets_path: dets_path,
          dets_ref: dets_ref
        }}
      
      {:error, reason} ->
        Logger.error("Failed to open DETS table: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:load, _from, %{dets_ref: dets_ref} = state) do
    # DETS is already loaded when we open it, so we just need to verify
    case :dets.info(dets_ref, :size) do
      :undefined -> 
        Logger.warning("DETS table appears to be empty or corrupted")
        {:reply, {:error, :not_found}, state}
      _ -> 
        Logger.info("DETS table loaded successfully")
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:persist, _from, %{dets_ref: dets_ref} = state) do
    case :dets.sync(dets_ref) do
      :ok -> 
        Logger.info("DETS table persisted to disk")
        {:reply, :ok, state}
      error -> 
        Logger.error("Failed to persist DETS table: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:clear, _from, %{dets_ref: dets_ref} = state) do
    :ok = :dets.delete_all_objects(dets_ref)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:put, id, entry}, _from, %{dets_ref: dets_ref} = state) do
    true = :dets.insert(dets_ref, {id, entry})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, id}, _from, %{dets_ref: dets_ref} = state) do
    case :dets.lookup(dets_ref, id) do
      [{^id, entry}] -> {:reply, {:ok, entry}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:search, query, limit}, _from, %{dets_ref: dets_ref} = state) do
    # This is a simple string match - in a real implementation, you'd want to use
    # vector similarity search or a more sophisticated text search
    results = :dets.foldl(
      fn {id, %{content: content} = entry}, acc ->
        if String.contains?(String.downcase(content), String.downcase(query)) do
          [%{id: id, score: 1.0, entry: entry} | acc]
        else
          acc
        end
      end,
      [],
      dets_ref
    )
    
    # Sort by score (descending) and limit results
    sorted_results = 
      results
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(limit)
    
    {:reply, {:ok, sorted_results}, state}
  end

  @impl true
  def terminate(_reason, %{dets_ref: dets_ref}) do
    :ok = :dets.close(dets_ref)
  end

  # Private functions

  defp via_tuple(name) do
    {:via, Registry, {KnowledgeBase.Registry, name}}
  end
end
