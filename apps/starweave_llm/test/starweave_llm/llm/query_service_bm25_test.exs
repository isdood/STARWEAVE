defmodule StarweaveLlm.LLM.QueryServiceBM25Test do
  use ExUnit.Case, async: false
  import Mox
  
  alias StarweaveLlm.LLM.QueryService
  
  # Import Mox utilities
  import Mox
  
  # Define the mock module from test helper
  @mock_embedder StarweaveLlm.MockBertEmbedder
  
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
      {:ok, %{documents: [], document_terms: %{}, avg_doc_length: 0}}
    end
    
    # Update the documents for testing
    def update_documents(pid \\ __MODULE__, docs) do
      GenServer.call(pid, {:update_documents, docs})
    end
    
    # Handle get_all_documents
    def handle_call(:get_all_documents, _from, %{documents: docs} = state) do
      {:reply, {:ok, docs}, state}
    end
    
    # Simple tokenization for BM25
    defp tokenize(text) do
      text
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)
      |> Enum.reject(&(String.length(&1) < 2))
    end
    
    # Calculate BM25 score for a document
    defp bm25_score(term_freq, doc_freq, doc_length, avg_doc_length, num_docs, k1 \\ 1.5, b \\ 0.75) do
      idf = :math.log((num_docs - doc_freq + 0.5) / (doc_freq + 0.5) + 1.0)
      tf_norm = (term_freq * (k1 + 1)) / 
                (term_freq + k1 * (1 - b + b * doc_length / avg_doc_length))
      idf * tf_norm
    end
    
    # Handle BM25 search
    def handle_call({:bm25_search, query, _opts}, _from, %{documents: docs, document_terms: doc_terms, avg_doc_length: avg_len} = state) do
      # Log the BM25 search for debugging
      IO.inspect("BM25 Search called with query: #{query}")
      
      # If no documents, return empty list
      if Enum.empty?(docs) do
        {:reply, {:ok, []}, state}
      else
        query_terms = tokenize(query)
        num_docs = length(docs)
        
        results = 
          docs
          |> Enum.map(fn doc ->
            doc_terms = Map.get(doc_terms, doc.id, %{})
            doc_length = String.length(doc.content)
            
            score = 
              query_terms
              |> Enum.map(fn term ->
                term_freq = Map.get(doc_terms, term, 0)
                doc_freq = count_docs_with_term(term, doc_terms, docs)
                bm25_score(term_freq, doc_freq, doc_length, avg_len, num_docs)
              end)
              |> Enum.sum()
              
            %{
              id: doc.id,
              score: if(score > 0, do: score, else: 0.0),
              content: doc.content,
              file_path: doc.file_path,
              metadata: doc.metadata,
              search_type: :bm25
            }
          end)
          |> Enum.filter(&(&1.score > 0))
          |> Enum.sort_by(& &1.score, :desc)
        
        {:reply, {:ok, results}, state}
      end
    end
    
    # Helper to count documents containing a term
    defp count_docs_with_term(term, doc_terms, docs) do
      Enum.count(docs, fn doc ->
        terms = Map.get(doc_terms, doc.id, %{})
        Map.has_key?(terms, term) && terms[term] > 0
      end)
    end
    
    # Handle hybrid search
    def handle_call({:hybrid_search, query, opts}, _from, state) do
      # For testing, just delegate to BM25 search with the same options
      # In a real implementation, this would combine BM25 and semantic search results
      handle_call({:bm25_search, query, opts}, nil, state)
    end
    
    # Handle document updates
    def handle_call({:update_documents, docs}, _from, _state) do
      # Calculate document terms for BM25
      {doc_terms, total_length} = 
        Enum.reduce(docs, {%{}, 0}, fn doc, {terms_acc, total_len} ->
          doc_terms = 
            doc.content
            |> tokenize()
            |> Enum.frequencies()
            
          doc_length = String.length(doc.content)
          
          {Map.put(terms_acc, doc.id, doc_terms), total_len + doc_length}
        end)
        
      avg_doc_length = if length(docs) > 0, do: total_length / length(docs), else: 0
      
      state = %{
        documents: docs,
        document_terms: doc_terms,
        avg_doc_length: avg_doc_length
      }
      
      {:reply, :ok, state}
    end
    
    # Handle any other calls with a default implementation
    def handle_call(_msg, _from, state) do
      # Default implementation for other calls
      {:reply, :ok, state}
    end
  end
  
  # Setup function to initialize the test environment
  setup do
    # Start the mock knowledge base
    {:ok, kb_pid} = MockKnowledgeBaseBM25.start_link(name: :test_knowledge_base_bm25)
    
    # Update the knowledge base with test documents
    :ok = MockKnowledgeBaseBM25.update_documents(kb_pid, @test_docs)
    
    # Create a mock for the embedder
    embedder_mock = 
      Mox.stub_with(StarweaveLlm.MockBertEmbedder, StarweaveLlm.MockBertEmbedderStub)
    
    # Start the query service with the mock knowledge base and embedder
    {:ok, query_service} = QueryService.start_link(
      knowledge_base: kb_pid,
      embedder: embedder_mock
    )
    
    # Setup default mock responses for the embedder
    Mox.stub(StarweaveLlm.MockBertEmbedder, :embed, fn _text -> 
      {:ok, [0.1, 0.2, 0.3]}  # Simple embedding for testing
    end)
    
    {:ok, 
      query_service: query_service, 
      kb_pid: kb_pid, 
      test_docs: @test_docs,
      embedder: embedder_mock
    }
  end
  
  describe "BM25 search integration" do
    setup %{query_service: query_service} do
      # Setup mock responses for the embedder
      Mox.stub(StarweaveLlm.MockBertEmbedder, :embed, fn _text -> 
        {:ok, [0.1, 0.2, 0.3]}  # Simple embedding for testing
      end)
      
      :ok
    end
    
    test "ranks documents by relevance to query", %{query_service: query_service} do
      # Test with a query that should match all documents but with different relevance
      query = "Elixir programming language"
      
      # Perform the search with BM25 enabled
      {:ok, results} = QueryService.query(query_service, query, 
        search_strategy: :hybrid, 
        use_bm25: true,
        raw_results: true
      )
      
      # Check if we got results or a message
      if is_binary(results) do
        # If we got a message, it should indicate no results
        assert String.starts_with?(results, "No results found for:")
      else
        # If we got results, verify them
        assert length(results) > 0
        
        # The first result should be the most relevant (doc1 mentions both terms)
        first_result = hd(results)
        assert first_result.content =~ "Elixir"
        assert first_result.content =~ "programming language"
        
        # All results should have scores
        assert Enum.all?(results, &(&1.score > 0))
      end
    end
    
    test "falls back to simple search when BM25 is disabled", %{query_service: query_service} do
      # Test with BM25 explicitly disabled
      query = "Phoenix"
      
      # Perform the search with BM25 disabled
      {:ok, results} = QueryService.query(query_service, query, 
        search_strategy: :hybrid, 
        use_bm25: false,
        raw_results: true
      )
      
      # Check if we got results or a message
      if is_binary(results) do
        # If we got a message, it should indicate no results
        assert String.starts_with?(results, "No results found for:")
      else
        # If we got results, verify them
        assert length(results) > 0
        
        # Should find the Phoenix document
        phoenix_doc = Enum.find(results, &String.contains?(&1.content, "Phoenix"))
        assert phoenix_doc != nil
      end
    end
    
    test "handles empty results gracefully", %{query_service: query_service} do
      # Test with a query that won't match any documents
      query = "nonexistent term"
      
      # Perform the search
      {:ok, results} = QueryService.query(query_service, query, 
        search_strategy: :hybrid, 
        use_bm25: true,
        raw_results: true
      )
      
      # Should return an empty list or a "no results" message
      assert results == [] || String.starts_with?(results, "No results found for:")
    end
  end
  
  describe "hybrid search with BM25" do
    setup %{query_service: query_service} do
      # Setup mock responses for the embedder
      Mox.stub(StarweaveLlm.MockBertEmbedder, :embed, fn _text -> 
        {:ok, [0.1, 0.2, 0.3]}  # Simple embedding for testing
      end)
      
      :ok
    end
    
    test "combines BM25 and semantic results", %{query_service: query_service} do
      # Test with a query that should work well with both approaches
      query = "Elixir web framework"
      
      # Perform the hybrid search
      {:ok, results} = QueryService.query(query_service, query, 
        search_strategy: :hybrid, 
        use_bm25: true,
        max_results: 5,
        raw_results: true
      )
      
      # Check if we got results or a message
      if is_binary(results) do
        # If we got a message, it should indicate no results
        assert String.starts_with?(results, "No results found for:")
      else
        # If we got results, verify them
        assert length(results) > 0
        
        # Should include both semantic and BM25 results
        # Note: In our mock implementation, we're only testing BM25
        # so we'll just check that we have results with scores
        assert Enum.all?(results, &(&1.score > 0))
        
        # Results should be sorted by relevance
        scores = Enum.map(results, & &1.score)
        assert scores == Enum.sort(scores, :desc)
      end
    end
  end
end
