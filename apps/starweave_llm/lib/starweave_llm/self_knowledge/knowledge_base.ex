defmodule StarweaveLlm.SelfKnowledge.KnowledgeBase do
  @moduledoc """
  Manages the DETS-based storage for the self-knowledge system.
  
  This module implements the SelfKnowledge.Behaviour to provide a persistent
  storage backend for code knowledge and embeddings.
  """

  use GenServer
  require Logger
  
  @behaviour StarweaveLlm.SelfKnowledge.Behaviour

  alias __MODULE__
  alias StarweaveLlm.Embeddings.Supervisor, as: Embeddings
  
  @type embedding :: [float()]
  @type search_result :: %{
    id: String.t(),
    score: float(),
    entry: map(),
    # Additional metadata for LLM context
    context: map() | nil
  }

  @type vector :: [float()]
  @type similarity_score :: float()

  defstruct [
    :table_name,
    :dets_path,
    :dets_ref,
    # Cache for embeddings to avoid redundant calculations
    embedding_cache: %{},
    # Maximum number of results to return in similarity search
    max_search_results: 10,
    # Configuration for vector search
    vector_search: %{
      min_similarity: 0.6,  # Minimum similarity score to include in results
      max_results: 5,       # Maximum number of results to return
      include_context: true # Whether to include surrounding context in results
    }
  ]

  # Public API

  @doc """
  Starts the KnowledgeBase GenServer.
  """
  @impl true
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
  Performs a vector similarity search against the knowledge base.
  
  ## Parameters
    * `query_embedding` - The vector embedding of the query
    * `opts` - Options for the search
      * `:min_similarity` - Minimum similarity score (0.0 to 1.0)
      * `:max_results` - Maximum number of results to return
      * `:include_context` - Whether to include surrounding context
  """
  @spec vector_search(pid() | atom(), vector(), keyword()) :: {:ok, [search_result()]} | {:error, any()}
  @impl true
  def vector_search(knowledge_base, query_embedding, opts \\ []) do
    GenServer.call(knowledge_base, {:vector_search, query_embedding, opts})
  end

  @doc """
  Performs a text-based search against the knowledge base.
  
  ## Parameters
    * `query` - The search query string
    * `opts` - Options for the search
      * `:max_results` - Maximum number of results to return
      * `:include_context` - Whether to include surrounding context
      * `:min_score` - Minimum score threshold (0.0 to 1.0)
  """
  @spec text_search(pid() | atom(), String.t(), keyword()) :: {:ok, [search_result()]} | {:error, any()}
  @impl true
  def text_search(knowledge_base, query, opts \\ []) when is_binary(query) do
    GenServer.call(knowledge_base, {:text_search, query, opts})
  end

  @doc """
  Updates the embedding for a specific entry in the knowledge base.
  """
  @spec update_embedding(pid() | atom(), String.t(), vector()) :: :ok | {:error, any()}
  @impl true
  def update_embedding(knowledge_base, id, embedding) do
    GenServer.call(knowledge_base, {:update_embedding, id, embedding})
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
  @impl true
  def put(knowledge_base, id, entry) do
    GenServer.call(knowledge_base, {:put, id, entry})
  end

  @doc """
  Retrieves an entry from the knowledge base by ID.
  """
  @impl true
  def get(knowledge_base, id) do
    GenServer.call(knowledge_base, {:get, id})
  end

  @doc """
  Searches for entries matching the given query using text matching.
  """
  @impl true
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
  
  @doc """
  Retrieves all documents from the knowledge base for full-text search.
  
  ## Returns
    * `{:ok, [document]}` - A list of document maps with at least :id and :content fields
    * `{:error, reason}` - If the operation failed
  """
  @spec get_all_documents(pid() | atom()) :: {:ok, [map()]} | {:error, any()}
  def get_all_documents(knowledge_base) do
    GenServer.call(knowledge_base, :get_all_documents)
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

  # Basic CRUD operations
  @impl true
  def handle_call(:clear, _from, %{dets_ref: dets_ref} = state) do
    :ok = :dets.delete_all_objects(dets_ref)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_all_documents, _from, %{dets_ref: dets_ref} = state) do
    try do
      documents = 
        :dets.match_object(dets_ref, :_)
        |> Enum.map(fn {_id, entry} ->
          %{
            id: entry.id,
            content: entry.content || "",
            file_path: entry.file_path || "",
            metadata: entry.metadata || %{},
            # Include any other relevant fields
            embedding: entry.embedding
          }
        end)
      
      {:reply, {:ok, documents}, state}
    catch
      kind, reason ->
        Logger.error("Failed to fetch all documents: #{inspect({kind, reason})}")
        {:reply, {:error, reason}, state}
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
  def handle_call({:get, id}, _from, %{dets_ref: dets_ref} = state) do
    case :dets.lookup(dets_ref, id) do
      [{^id, entry}] -> {:reply, {:ok, entry}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:put, id, entry}, _from, %{dets_ref: dets_ref} = state) do
    # Log the DETS info before insert for debugging
    dets_info = :dets.info(dets_ref)
    Logger.debug("DETS info before insert: #{inspect(dets_info, pretty: true)}")
    
    # Insert the entry
    case :dets.insert(dets_ref, {id, entry}) do
      :ok ->
        # Verify the insert worked
        case :dets.lookup(dets_ref, id) do
          [{^id, _}] -> 
            Logger.debug("Successfully inserted entry with ID: #{id}")
            {:reply, :ok, state}
          _ -> 
            Logger.error("Failed to verify insert for ID: #{id}")
            {:reply, {:error, :insert_failed}, state}
        end
      error ->
        Logger.error("Failed to insert entry: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:update_embedding, id, embedding}, _from, %{dets_ref: dets_ref} = state) do
    case :dets.lookup(dets_ref, id) do
      [{^id, entry}] ->
        updated_entry = Map.put(entry, :embedding, embedding)
        :ok = :dets.insert(dets_ref, {id, updated_entry})
        {:reply, {:ok, updated_entry}, state}
      [] -> 
        {:reply, {:error, :not_found}, state}
    end
  end

  # Search operations
  def handle_call({:text_search, query, opts}, _from, %{dets_ref: dets_ref} = state) do
    max_results = Keyword.get(opts, :max_results, 5)
    min_score = Keyword.get(opts, :min_score, 0.1)
    include_context = Keyword.get(opts, :include_context, true)
    
    query_terms = String.downcase(query) |> String.split(~r/\s+/, trim: true)
    
    results =
      :dets.foldl(
        fn {id, %{content: content} = entry}, acc ->
          content_lower = String.downcase(content)
          
          # Calculate a simple term frequency score
          score = 
            query_terms
            |> Enum.reduce(0, fn term, acc_score ->
              if String.contains?(content_lower, term) do
                # Higher score for exact matches, partial matches get lower score
                if String.contains?(content_lower, " #{term} ") or 
                   String.starts_with?(content_lower, "#{term} ") or 
                   String.ends_with?(content_lower, " #{term}") do
                  acc_score + 1.0
                else
                  acc_score + 0.5
                end
              else
                acc_score
              end
            end)
            |> Kernel./(max(1, length(query_terms)))  # Normalize by number of terms
          
          if score >= min_score do
            result = %{
              id: id,
              score: score,
              entry: entry,
              context: if(include_context, do: get_context(entry), else: nil)
            }
            [result | acc]
          else
            acc
          end
        end,
        [],
        dets_ref
      )
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(max_results)

    {:reply, {:ok, results}, state}
  end

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

  def handle_call({:vector_search, query_embedding, opts}, _from, %{dets_ref: dets_ref, vector_search: vs_config} = state) do
    # Merge provided options with defaults
    min_similarity = Keyword.get(opts, :min_similarity, vs_config.min_similarity)
    max_results = Keyword.get(opts, :max_results, vs_config.max_results)
    include_context = Keyword.get(opts, :include_context, vs_config.include_context)

    results =
      :dets.foldl(
        fn {id, entry}, acc ->
          case entry do
            %{embedding: embedding} when is_list(embedding) ->
              score = cosine_similarity(query_embedding, embedding)
              if score >= min_similarity do
                result = %{
                  id: id,
                  score: score,
                  entry: entry,
                  context: if(include_context, do: get_context(entry), else: nil)
                }
                [result | acc]
              else
                acc
              end
            _ ->
              acc
          end
        end,
        [],
        dets_ref
      )
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(max_results)

    {:reply, {:ok, results}, state}
  end

  # Calculates the cosine similarity between two vectors
  defp cosine_similarity(vec_a, vec_b) when is_list(vec_a) and is_list(vec_b) do
    dot_product = dot_product(vec_a, vec_b)
    magnitude_a = :math.sqrt(Enum.reduce(vec_a, 0, fn x, acc -> acc + x * x end))
    magnitude_b = :math.sqrt(Enum.reduce(vec_b, 0, fn x, acc -> acc + x * x end))
    
    case magnitude_a * magnitude_b do
      +0.0 -> +0.0
      -0.0 -> +0.0
      magnitude -> dot_product / magnitude
    end
  end

  # Calculates the dot product of two vectors
  defp dot_product(vec_a, vec_b) do
    Enum.zip_with(vec_a, vec_b, fn a, b -> a * b end)
    |> Enum.sum()
  end

  # Gets surrounding context for an entry
  defp get_context(%{file_path: file_path, line_number: line_number}) when is_integer(line_number) do
    # TODO: Implement context retrieval from source files
    # This could include surrounding lines of code, function docs, etc.
    %{
      file_path: file_path,
      line_number: line_number,
      snippet: "..."  # Placeholder for actual context
    }
  end
  defp get_context(_), do: nil

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
