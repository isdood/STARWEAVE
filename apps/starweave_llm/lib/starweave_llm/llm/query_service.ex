defmodule StarweaveLlm.LLM.QueryService do
  @moduledoc """
  Handles LLM queries with semantic search integration.
  
  This module provides an interface for querying the knowledge base using
  natural language and generating responses with the help of LLMs.
  """

  use GenServer
  require Logger
  
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  alias StarweaveLlm.Embeddings.BertEmbedder
  alias StarweaveLlm.TextAnalysis
  
  @type state :: %{
    knowledge_base: pid() | atom(),
    embedder: module()
  }

  @doc """
  Starts the QueryService process.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end
  
  @doc """
  Processes a natural language query using semantic search and LLM integration.
  
  ## Parameters
    * `query` - The natural language query
    * `opts` - Additional options
      * `:conversation_history` - Previous messages in the conversation
      * `:min_similarity` - Minimum similarity score (0.0 to 1.0)
      * `:max_results` - Maximum number of results to return
  """
  @spec query(pid() | atom(), String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def query(pid \\ __MODULE__, query, opts \\ []) when is_binary(query) do
    GenServer.call(pid, {:query, query, opts})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    knowledge_base = Keyword.fetch!(opts, :knowledge_base)
    embedder = Keyword.get(opts, :embedder, BertEmbedder)
    
    state = %{
      knowledge_base: knowledge_base,
      embedder: embedder
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:query, query, opts}, _from, %{knowledge_base: knowledge_base} = state) do
    result = case embed_query(query, state.embedder) do
      {:ok, embedding} ->
        case search_knowledge_base(knowledge_base, embedding, opts) do
          {:ok, []} ->
            # Return a message when no results are found
            {:ok, "No results found for: #{query}"}
          {:ok, results} ->
            if Keyword.get(opts, :raw_results, false) do
              # Return raw results if raw_results option is true
              {:ok, results}
            else
              # Generate a formatted response by default
              generate_response(query, results, opts)
            end
          error ->
            error
        end
      error -> 
        error
    end
    
    {:reply, result, state}
  end

  defp embed_query(text, embedder) when is_binary(text) do
    case embedder.embed(text) do
      {:ok, embedding} -> {:ok, embedding}
      error -> error
    end
  end

  defp search_knowledge_base(knowledge_base, query_embedding, opts) do
    strategy = Keyword.get(opts, :search_strategy, :hybrid)
    max_results = Keyword.get(opts, :max_results, 5)
    
    base_opts = [
      min_similarity: Keyword.get(opts, :min_similarity, 0.6),
      max_results: max_results * 2,  # Get more results to combine
      include_context: Keyword.get(opts, :include_context, true)
    ]
    
    case strategy do
      :hybrid ->
        semantic_results = case semantic_search(knowledge_base, query_embedding, base_opts) do
          {:ok, results} -> results
          _ -> []
        end
        
        keyword_results = case keyword_search(knowledge_base, query_embedding, base_opts) do
          {:ok, results} -> results
          _ -> []
        end
        
        combined = combine_results(semantic_results, keyword_results, max_results)
        {:ok, combined}
        
      :semantic ->
        case semantic_search(knowledge_base, query_embedding, base_opts) do
          {:ok, results} -> 
            # Ensure results have the expected structure
            processed = Enum.map(results, &ensure_result_structure/1)
            {:ok, processed}
          error -> 
            error
        end
        
      :keyword ->
        case keyword_search(knowledge_base, query_embedding, base_opts) do
          {:ok, results} -> 
            # Ensure results have the expected structure
            processed = Enum.map(results, &ensure_result_structure/1)
            {:ok, processed}
          error -> 
            error
        end
      
      _ ->
        {:error, "Unsupported search strategy: #{inspect(strategy)}"}
    end
  end
  
  defp semantic_search(knowledge_base, query_embedding, opts) do
    case KnowledgeBase.vector_search(knowledge_base, query_embedding, opts) do
      {:ok, []} -> 
        Logger.info("No semantic results found for query")
        {:ok, []}
      result -> 
        result
    end
  end
  
  defp keyword_search(knowledge_base, query_embedding, opts) do
    # Extract query text from the first element of the embedding (if available)
    query_text = 
      case query_embedding do
        [first | _] when is_binary(first) -> first
        _ -> ""
      end
    
    if String.length(query_text) > 0 do
      # First try BM25 search if we have access to the full corpus
      case Keyword.get(opts, :use_bm25, true) do
        true ->
          case KnowledgeBase.get_all_documents(knowledge_base) do
            {:ok, documents} when is_list(documents) and length(documents) > 0 ->
              # Use BM25 to rank documents
              ranked_docs = 
                documents
                |> Enum.map(&Map.put(&1, :content, &1.content || ""))
                |> TextAnalysis.rank_documents(query_text, opts)
                
              # Convert to the expected format
              results = 
                ranked_docs
                |> Enum.map(fn {doc, score} ->
                  %{
                    id: doc.id,
                    score: score,
                    content: doc.content,
                    file_path: doc.file_path || "",
                    metadata: doc.metadata || %{},
                    search_type: :bm25
                  }
                end)
                
              {:ok, results}
              
            _ ->
              # Fall back to simple text search if we can't get all documents
              KnowledgeBase.text_search(knowledge_base, query_text, opts)
          end
          
        false ->
          # Use the original text search if BM25 is disabled
          KnowledgeBase.text_search(knowledge_base, query_text, opts)
      end
    else
      {:ok, []}
    end
  end
  
  defp combine_results(semantic_results, keyword_results, max_results) do
    # Normalize scores to 0-1 range if needed
    normalized_semantic = normalize_scores(semantic_results)
    normalized_keyword = normalize_scores(keyword_results)
    
    # Create a map of ID to result for easy lookup
    semantic_map = 
      normalized_semantic
      |> Enum.map(&Map.put(&1, :search_type, :semantic))
      |> Map.new(&{&1.id, &1})
      
    keyword_map = 
      normalized_keyword
      |> Enum.map(fn result ->
        # If this result came from BM25, it already has a score we want to keep
        result = if Map.get(result, :search_type) == :bm25 do
          result
        else
          Map.put(result, :search_type, :keyword)
        end
        {result.id, result}
      end)
      |> Enum.into(%{})
    
    # Combine results with weighted scores
    combined = 
      Map.merge(semantic_map, keyword_map, fn _id, sem, kw ->
        # Ensure we have the entry and context fields
        sem = ensure_result_structure(sem)
        kw = ensure_result_structure(kw)
        
        # Calculate combined score with weights
        combined_score = case {sem.search_type, kw.search_type} do
          {:semantic, :keyword} -> (sem.score * 0.7) + (kw.score * 0.3)
          {_, _} -> max(sem.score, kw.score)
        end
        
        # Merge the results, preferring semantic fields when available
        result = Map.merge(kw, sem)
        
        # Create a new result map with all required fields
        %{
          id: result.id,
          score: result.score,
          combined_score: combined_score,
          search_type: :both,
          entry: result.entry || %{},
          context: result.context || %{},
          metadata: result.entry[:metadata] || %{},
          # Ensure we have all required fields from the test data
          file_path: result.file_path || "",
          content: result.content || ""
        }
      end)
      |> Map.values()
    
    # Ensure all results have the required structure
    combined = Enum.map(combined, &ensure_result_structure/1)
    
    # Sort by combined score and limit results
    combined
    |> Enum.sort_by(fn result -> 
      -Map.get(result, :combined_score, 0.0) 
    end)
    |> Enum.take(max_results)
  end
  
  defp ensure_result_structure(result) do
    result = case result do
      %{entry: %{} = entry} -> 
        # If entry exists, ensure it has all required fields
        entry = Map.merge(%{id: result.id, file_path: "", content: "", metadata: %{}}, entry)
        Map.put(result, :entry, entry)
      %{context: %{} = context} -> 
        # If no entry but has context, use context as entry
        entry = Map.merge(%{id: result.id, file_path: "", content: "", metadata: %{}}, context)
        Map.put(result, :entry, entry)
      _ -> 
        # If neither, create a basic entry
        Map.put(result, :entry, %{id: result.id, file_path: "", content: "", metadata: %{}})
    end
    
    # Ensure all required fields exist with defaults
    Map.merge(
      %{
        id: nil,
        score: 0.0,
        search_type: :unknown,
        context: %{},
        entry: %{id: nil, file_path: "", content: "", metadata: %{}}
      },
      result
    )
  end
  
  defp normalize_scores(results) when is_list(results) do
    max_score = results |> Enum.map(& &1.score) |> Enum.max(fn -> 1.0 end)
    
    if max_score > 0 do
      Enum.map(results, fn result ->
        %{result | score: result.score / max_score}
      end)
    else
      results
    end
  end

  @doc """
  Generates a natural language response based on search results.
  """
  @spec generate_response(String.t(), [map()], keyword()) :: {:ok, String.t()} | {:error, any()}
  def generate_response(query, results, _opts) do
    # Format the context from search results
    context = format_search_results(results)
    
    # In a real implementation, we would generate a prompt and call an LLM service (e.g., Ollama)
    # For now, we'll return a simple response with the query and context
    {:ok, "Here's what I found related to your query: #{query}\n\n" <> context}
  end

  defp format_search_results(results) do
    results
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {%{entry: entry, score: score}, idx} ->
      """
      #{idx}. File: #{entry.file_path || "Unknown"}
         Score: #{:erlang.float_to_binary(score, decimals: 3)}
         Content: #{String.slice(entry.content || "", 0..200)}...
      """
    end)
  end
end
