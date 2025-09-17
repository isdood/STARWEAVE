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
          {:ok, results} -> generate_response(query, results, opts)
          error -> error
        end
      error -> error
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
    search_opts = [
      min_similarity: Keyword.get(opts, :min_similarity, 0.6),
      max_results: Keyword.get(opts, :max_results, 5),
      include_context: true
    ]

    case KnowledgeBase.vector_search(knowledge_base, query_embedding, search_opts) do
      {:ok, []} -> 
        Logger.info("No relevant results found for query")
        {:ok, []}
      {:ok, results} -> 
        {:ok, results}
      error -> 
        error
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
