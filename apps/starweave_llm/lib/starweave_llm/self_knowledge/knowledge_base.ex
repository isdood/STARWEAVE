defmodule StarweaveLlm.SelfKnowledge.KnowledgeBase do
  @moduledoc """
  Manages the DETS-based storage for the self-knowledge system.
  """

  use GenServer
  require Logger

  alias __MODULE__
  alias StarweaveLlm.Embeddings.Supervisor, as: Embeddings
  
  @type embedding :: [float()]
  @type search_result :: %{
    id: String.t(),
    score: float(),
    entry: map()
  }

  defstruct [
    :table_name,
    :dets_path,
    :dets_ref,
    # Cache for embeddings to avoid redundant calculations
    embedding_cache: %{},
    # Maximum number of results to return in similarity search
    max_search_results: 10
  ]

  # Public API

  @doc """
  Starts the KnowledgeBase GenServer.
  """
  def start_link(opts) do
    table_name = Keyword.fetch!(opts, :table_name)
    dets_path = Keyword.fetch!(opts, :dets_path)
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, {table_name, dets_path}, name: name)
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
  Searches for entries matching the given query using text matching.
  """
  def search(knowledge_base, query, opts \\ []) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 10)
    use_semantic = Keyword.get(opts, :semantic, false)
    
    if use_semantic do
      GenServer.call(knowledge_base, {:semantic_search, query, limit})
    else
      GenServer.call(knowledge_base, {:text_search, query, limit})
    end
  end
  
  @doc """
  Performs a semantic search using vector similarity.
  """
  def semantic_search(knowledge_base, query_embedding, opts \\ []) when is_list(query_embedding) do
    limit = Keyword.get(opts, :limit, 10)
    GenServer.call(knowledge_base, {:vector_search, query_embedding, limit})
  end

  # GenServer Callbacks

  @impl true
  def init({table_name, dets_path}) do
    # Ensure the directory exists
    dir_path = Path.dirname(dets_path)
    
    with :ok <- File.mkdir_p(dir_path),
         {:ok, dets_ref} <- :dets.open_file(table_name, [
           {:file, String.to_charlist(dets_path)},
           {:type, :set},
           {:auto_save, 60_000},  # Auto-save every minute
           {:repair, true}
         ]) do
      Logger.info("Opened DETS table at #{dets_path}")
      {:ok, %KnowledgeBase{
        table_name: table_name,
        dets_path: dets_path,
        dets_ref: dets_ref
      }}
    else
      {:error, reason} ->
        Logger.error("Failed to open DETS table: #{inspect(reason)}")
        {:stop, reason}
      error ->
        Logger.error("Unexpected error initializing DETS table: #{inspect(error)}")
        {:stop, error}
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
    case :dets.insert(dets_ref, {id, entry}) do
      true -> {:reply, :ok, state}
      error -> {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:get, id}, _from, %{dets_ref: dets_ref} = state) do
    case :dets.lookup(dets_ref, id) do
      [{^id, entry}] -> {:reply, {:ok, entry}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:text_search, query, limit}, _from, %{dets_ref: dets_ref} = state) do
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
  def handle_call({:semantic_search, query, limit}, from, %{dets_ref: _dets_ref} = state) do
    # Generate embedding for the query
    case Embeddings.embed_texts([query]) do
      {:ok, [query_embedding]} ->
        handle_call({:vector_search, query_embedding, limit}, from, state)
        
      error ->
        Logger.error("Failed to generate query embedding: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(
    {:vector_search, query_embedding, limit}, 
    _from, 
    %{dets_ref: dets_ref, max_search_results: max_results} = state
  ) do
    results = :dets.foldl(
      fn {id, %{embedding: embedding} = entry}, acc ->
        if is_list(embedding) do
          score = Embeddings.cosine_similarity(query_embedding, embedding)
          [%{id: id, score: score, entry: entry} | acc]
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
      |> Enum.take(limit || max_results)
    
    {:reply, {:ok, sorted_results}, state}
  end

  @impl true
  def terminate(_reason, %{dets_ref: dets_ref}) when is_reference(dets_ref) do
    try do
      :ok = :dets.close(dets_ref)
    rescue
      e ->
        Logger.error("Error closing DETS table: #{inspect(e)}")
        :ok
    end
  end
  
  def terminate(_reason, _state) do
    :ok
  end

  # Private functions

  # No longer using via tuple, using direct name registration instead
end
