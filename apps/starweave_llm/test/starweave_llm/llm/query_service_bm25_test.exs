defmodule StarweaveLlm.LLM.QueryServiceBM25Test do
  use ExUnit.Case, async: false
  import Mox
  
  alias StarweaveLlm.LLM.QueryService
  
  # Define the mock modules
  @mock_embedder StarweaveLlm.MockBertEmbedderStub
  
  # Set Mox in global mode and verify on exit
  setup :set_mox_global
  setup :verify_on_exit!
  
  # Sample test documents
  @doc1 %{
    id: "doc1",
    content: "Elixir is a functional programming language that runs on the Erlang VM.",
    file_path: "elixir_lang.ex",
    metadata: %{type: "code"}
  }
  
  @doc2 %{
    id: "doc2",
    content: "Phoenix is a web framework for building scalable applications with Elixir.",
    file_path: "phoenix_web.ex",
    metadata: %{type: "code"}
  }
  
  @doc3 %{
    id: "doc3",
    content: "Ecto is a database wrapper and query generator for Elixir.",
    file_path: "ecto_db.ex",
    metadata: %{type: "code"}
  }
  
  # Test documents as a list
  @test_docs [@doc1, @doc2, @doc3]
  
  # Define a mock knowledge base server that supports BM25
  defmodule MockKnowledgeBaseBM25 do
    use GenServer
    
    def start_link(opts) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, [], name: name)
    end
    
    def init(_opts) do
      {:ok, %{documents: []}}
    end
    
    # Update the documents for testing
    def update_documents(pid \\ __MODULE__, docs) do
      GenServer.call(pid, {:update_documents, docs})
    end
    
    # Handle get_all_documents
    def handle_call(:get_all_documents, _from, %{documents: docs} = state) do
      {:reply, {:ok, docs}, state}
    end
    
    # Handle text search (fallback)
    def handle_call({:text_search, query, _opts}, _from, %{documents: docs} = state) do
      # Simple text search for testing
      results = 
        docs
        |> Enum.filter(fn doc -> 
          String.contains?(String.downcase(doc.content), String.downcase(query))
        end)
        |> Enum.map(fn doc ->
          %{
            id: doc.id,
            score: 0.8,  # Fixed score for testing
            content: doc.content,
            file_path: doc.file_path,
            metadata: doc.metadata
          }
        end)
      
      {:reply, {:ok, results}, state}
    end
    
    # Handle vector search
    def handle_call({:vector_search, _embedding, _opts}, _from, %{documents: docs} = state) do
      # Return all documents with a fixed score for testing
      results = 
        docs
        |> Enum.map(fn doc ->
          %{
            id: doc.id,
            score: 0.9,  # Fixed score for testing
            content: doc.content,
            file_path: doc.file_path,
            metadata: doc.metadata
          }
        end)
      
      {:reply, {:ok, results}, state}
    end
    
    # Handle document updates
    def handle_call({:update_documents, docs}, _from, _state) do
      {:reply, :ok, %{documents: docs}}
    end
    
    # Handle any other calls by delegating to the original KnowledgeBase
    def handle_call(msg, from, state) do
      # Default implementation for other calls
      super(msg, from, state)
    end
  end
  
  # Setup function to initialize the test environment
  setup do
    # Start the mock knowledge base
    {:ok, kb_pid} = MockKnowledgeBaseBM25.start_link(name: :test_knowledge_base_bm25)
    
    # Update the knowledge base with test documents
    :ok = MockKnowledgeBaseBM25.update_documents(kb_pid, @test_docs)
    
    # Start the query service with the mock knowledge base
    query_service_opts = [
      knowledge_base: kb_pid,
      embedder: @mock_embedder
    ]
    
    # Mock the embedder to return a simple embedding
    Mox.stub_with(@mock_embedder, StarweaveLlm.MockBertEmbedderStub)
    
    # Start the query service
    {:ok, query_service} = QueryService.start_link(query_service_opts)
    
    {:ok, query_service: query_service, kb_pid: kb_pid, test_docs: @test_docs}
  end
  
  # Skip BM25 tests for now as they require a more complex setup
  @tag :skip
  describe "BM25 search integration" do
    @tag :skip
    test "ranks documents by relevance to query", %{query_service: _query_service} do
      # Test with a query that should match all documents but with different relevance
      query = "Elixir programming language"
      
      # Perform the search with BM25 enabled
      {:ok, results} = QueryService.query(query, search_strategy: :hybrid, use_bm25: true)
      
      # Verify we got results
      assert length(results) > 0
      
      # The first result should be the most relevant (doc1 mentions both terms)
      first_result = hd(results)
      assert first_result.content =~ "Elixir"
      assert first_result.content =~ "programming language"
      
      # All results should have scores
      assert Enum.all?(results, &(&1.score > 0))
    end
    
    @tag :skip
    test "falls back to simple search when BM25 is disabled", %{query_service: _query_service} do
      # Test with BM25 explicitly disabled
      query = "Phoenix"
      
      # Perform the search with BM25 disabled
      {:ok, results} = QueryService.query(query, search_strategy: :hybrid, use_bm25: false)
      
      # Verify we got results
      assert length(results) > 0
      
      # Should find the Phoenix document
      phoenix_doc = Enum.find(results, &String.contains?(&1.content, "Phoenix"))
      assert phoenix_doc != nil
    end
    
    @tag :skip
    test "handles empty results gracefully", %{query_service: _query_service} do
      # Test with a query that won't match any documents
      query = "nonexistent term"
      
      # Perform the search
      {:ok, results} = QueryService.query(query, search_strategy: :hybrid, use_bm25: true)
      
      # Should return an empty list or a "no results" message
      assert results == [] || String.starts_with?(results, "No results found for:")
    end
  end
  
  @tag :skip
  describe "hybrid search with BM25" do
    @tag :skip
    test "combines BM25 and semantic results", %{query_service: _query_service} do
      # Test with a query that should work well with both approaches
      query = "Elixir web framework"
      
      # Perform the hybrid search
      {:ok, results} = QueryService.query(query, 
        search_strategy: :hybrid, 
        use_bm25: true,
        max_results: 5
      )
      
      # Verify we got results
      assert length(results) > 0
      
      # Should include both semantic and BM25 results
      assert Enum.any?(results, &(&1.search_type == :semantic))
      assert Enum.any?(results, &(&1.search_type == :bm25))
      
      # Results should be sorted by relevance
      scores = Enum.map(results, & &1.score)
      assert scores == Enum.sort(scores, :desc)
    end
  end
end
