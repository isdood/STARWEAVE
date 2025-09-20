defmodule StarweaveLlm.LLM.QueryServiceTest do
  use ExUnit.Case, async: false
  import Mox
  
  alias StarweaveLlm.LLM.QueryService
  
  # Define the mock modules
  @mock_embedder StarweaveLlm.MockBertEmbedder
  
  # Define a mock LLM client
  Mox.defmock(StarweaveLlm.MockLLM, for: StarweaveLlm.LLM.LLMBehaviour)
  
  # Set Mox in global mode and verify on exit
  setup :set_mox_global
  setup :verify_on_exit!
  
  # Define a mock LLM client stub
  defmodule MockLLMStub do
    @behaviour StarweaveLlm.LLM.LLMBehaviour
    
    @impl true
    def complete(_prompt) do
      # Default implementation that can be overridden in tests
      {:ok, "KNOWLEDGE_BASE"}
    end
    
    @impl true
    def stream_complete(_prompt) do
      # Default implementation for streaming
      {:error, :not_implemented}
    end
  end
  
  # Define a simple mock knowledge base server
  defmodule MockKnowledgeBase do
    use GenServer
    
    def start_link(opts) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end
    
    def init(opts) do
      semantic_result = Keyword.get(opts, :semantic_result, [])
      text_result = Keyword.get(opts, :text_result, [])
      
      {:ok, %{
        semantic_result: semantic_result,
        text_result: text_result
      }}
    end
    
    # Update the search results for testing
    def update_search_results(pid \\ __MODULE__, semantic_result, text_result) do
      GenServer.call(pid, {:update_search_results, semantic_result, text_result})
    end
    
    # Handle vector search requests (semantic search)
    def handle_call({:vector_search, _embedding, _opts}, _from, %{semantic_result: result} = state) do
      {:reply, {:ok, result}, state}
    end
    
    # Handle text search requests (keyword search)
    def handle_call({:text_search, _query, _opts}, _from, %{text_result: result} = state) do
      {:reply, {:ok, result}, state}
    end
    
    # Handle update search results requests
    def handle_call(
      {:update_search_results, semantic_result, text_result}, 
      _from, 
      state
    ) do
      {:reply, :ok, %{state | semantic_result: semantic_result, text_result: text_result}}
    end
  end
  
  setup do
    # Set up Mox expectations for the mock embedder
    Mox.stub(StarweaveLlm.MockBertEmbedder, :embed, fn _text -> 
      {:ok, [0.1, 0.2, 0.3, 0.4, 0.5]}
    end)
    
    # Set up the mock LLM client
    Mox.stub_with(StarweaveLlm.MockLLM, MockLLMStub)
    
    # Start a mock knowledge base
    {:ok, kb_pid} = MockKnowledgeBase.start_link(
      semantic_result: [],
      text_result: []
    )
    
    # Define test entries
    test_entries = [
      %{
        id: "test1",
        content: "Pattern matcher module that handles different matching strategies including exact, contains, and Jaccard similarity",
        file_path: "lib/starweave_core/pattern_matcher.ex",
        metadata: %{
          module: "PatternMatcher",
          function: "match/2",
          doc: "Module that implements pattern matching functionality..."
        }
      },
      %{
        id: "test2",
        content: "Query service that processes natural language queries using semantic search and LLM integration",
        file_path: "lib/starweave_llm/llm/query_service.ex",
        metadata: %{
          module: "QueryService",
          function: "query/3",
          doc: "Processes natural language queries using semantic search and LLM integration"
        }
      }
    ]
    
    # Semantic search results (vector similarity)
    semantic_result = [
      %{
        id: "test1",
        score: 0.95,
        entry: Enum.at(test_entries, 0),
        context: %{
          file_path: "lib/starweave_core/pattern_matcher.ex",
          content: "Module that implements pattern matching functionality..."
        }
      }
    ]
    
    # Text search results (keyword matching)
    text_result = [
      %{
        id: "test2",
        score: 0.85,
        entry: Enum.at(test_entries, 1),
        context: %{
          file_path: "lib/starweave_llm/llm/query_service.ex",
          content: "Processes natural language queries using semantic search..."
        }
      }
    ]
    
    # Update the mock knowledge base with test data
    :ok = MockKnowledgeBase.update_search_results(kb_pid, semantic_result, text_result)
    
    # Combine results for search_result context
    search_result = %{
      semantic: semantic_result,
      keyword: text_result,
      combined: Enum.uniq_by(semantic_result ++ text_result, & &1.id)
    }
    
    # Define the test embedding
    test_embedding = [0.1, 0.2, 0.3, 0.4, 0.5]
    
    # Start the query service with test configuration
    query_service_opts = [
      knowledge_base: kb_pid,
      embedder: @mock_embedder,
      llm_client: StarweaveLlm.MockLLM,
      # Disable LLM for tests by default
      use_llm: false
    ]
    
    # Return the test context with all required values
    %{
      kb_pid: kb_pid,
      test_entries: test_entries,
      test_embedding: test_embedding,
      semantic_result: semantic_result,
      text_result: text_result,
      search_result: search_result,
      query_service_opts: query_service_opts
    }
  end

  describe "hybrid search functionality" do
    test "combines semantic and keyword search results", %{
      query_service_opts: query_service_opts,
      kb_pid: kb_pid,
      test_entries: [entry1, entry2 | _]
    } do
      # Start the QueryService with a unique name for this test
      {:ok, query_service} = QueryService.start_link(
        Keyword.put(query_service_opts, :name, :query_service_test_hybrid)
      )
      
      # Set up mock responses for both search types
      semantic_result = [
        %{
          id: "test1",
          score: 0.95,
          entry: entry1,
          context: %{file_path: entry1.file_path, content: "Semantic match"},
          file_path: entry1.file_path,
          content: entry1.content,
          metadata: entry1.metadata,
          search_type: :semantic
        }
      ]
      
      text_result = [
        %{
          id: "test2",
          score: 0.85,
          entry: entry2,
          context: %{file_path: entry2.file_path, content: "Keyword match"},
          file_path: entry2.file_path,
          content: entry2.content,
          metadata: entry2.metadata,
          search_type: :keyword
        }
      ]
      
      # Update the mock knowledge base with test data
      :ok = MockKnowledgeBase.update_search_results(kb_pid, semantic_result, text_result)
      
      # Test hybrid search with raw results
      assert {:ok, results} = QueryService.query(
        query_service, 
        "pattern matching", 
        raw_results: true,
        search_strategy: :hybrid,
        max_results: 10
      )
      
      # Verify we got a list of results
      assert is_list(results)
      
      # Verify each result has the expected structure
      Enum.each(results, fn result ->
        assert is_binary(result.id)
        assert is_float(result.score)
        assert result.score >= 0.0 and result.score <= 1.0
        assert result.search_type in [:semantic, :keyword, :both]
        assert is_map(result.entry)
        assert is_map(result.context) || is_nil(result.context)
      end)
      
      # We should have results from at least one search type
      search_types = Enum.map(results, & &1.search_type)
      assert length(search_types) > 0
      assert Enum.any?(search_types, &(&1 in [:semantic, :both, :keyword]))
    end
  end

  describe "query/3" do
    test "returns relevant code snippets for a natural language query", %{
      query_service_opts: query_service_opts,
      test_entries: [test_entry | _],
      test_embedding: test_embedding,
      kb_pid: kb_pid
    } do
      
      # Start the QueryService with a unique name for this test
      {:ok, query_service} = QueryService.start_link(
        Keyword.put(query_service_opts, :name, :query_service_test_basic)
      )
      
      # Set up Mox expectations for this test
      Mox.expect(StarweaveLlm.MockBertEmbedder, :embed, fn "How does the pattern matching work?" -> 
        {:ok, test_embedding}
      end)
      
      # Update the mock knowledge base with test data
      :ok = MockKnowledgeBase.update_search_results(
        kb_pid, 
        [
          %{
            id: "test1",
            score: 0.95,
            entry: test_entry,
            context: %{
              file_path: test_entry.file_path,
              content: test_entry.content
            }
          }
        ],
        []
      )
      
      # Call the query function with raw_results: true to get structured response
      assert {:ok, results} = QueryService.query(
        query_service, 
        "How does the pattern matching work?", 
        raw_results: true
      )
      
      # Verify the response contains the expected result
      assert is_list(results)
      assert length(results) > 0
      assert hd(results).id == "test1"
    end
    
    test "handles empty search results gracefully", %{
      query_service_opts: query_service_opts,
      kb_pid: kb_pid
    } do
      # Start the QueryService with a unique name for this test
      {:ok, query_service} = QueryService.start_link(
        Keyword.put(query_service_opts, :name, :query_service_test_empty)
      )
      
      # Set up Mox expectations for this test
      Mox.expect(StarweaveLlm.MockBertEmbedder, :embed, fn "unknown query" -> 
        {:ok, [0.0, 0.0, 0.0, 0.0, 0.0]}
      end)
      
      # Update the mock knowledge base to return no results for this test
      :ok = MockKnowledgeBase.update_search_results(kb_pid, [], [])
      
      # Test with raw_results: true
      assert {:ok, results} = QueryService.query(
        query_service, 
        "unknown query",
        raw_results: true
      )
      
      # Should return an empty list for raw results
      assert is_list(results)
      assert Enum.empty?(results)
      
      # Reset Mox expectations for the next test
      Mox.stub(StarweaveLlm.MockBertEmbedder, :embed, fn "unknown query" ->
        {:ok, [0.0, 0.0, 0.0, 0.0, 0.0]}
      end)
      
      # Test without raw_results to check the formatted message
      assert {:ok, response} = QueryService.query(
        query_service,
        "unknown query"
      )
      
      # Should return an empty string when no results are found
      assert response == ""
    end
  end
  
  describe "query/3 with conversation history" do
    test "includes conversation history in the prompt", %{
      query_service_opts: query_service_opts,
      test_entries: [test_entry | _],
      test_embedding: test_embedding,
      kb_pid: kb_pid
    } do
      
      # Start the QueryService with a unique name for this test
      {:ok, query_service} = QueryService.start_link(
        Keyword.put(query_service_opts, :name, :query_service_test_history)
      )
      
      # Create a conversation history
      conversation_history = [
        %{role: "user", content: "How do I use the pattern matcher?"},
        %{role: "assistant", content: "You can use it like this..."},
        %{role: "user", content: "Can you show me an example?"}
      ]
      
      query = "How do I use the pattern matcher?"
      
      # Set up Mox expectations for this test
      Mox.expect(StarweaveLlm.MockBertEmbedder, :embed, fn ^query -> 
        {:ok, test_embedding}
      end)
      
      # Allow multiple calls to the embedder for conversation history
      Mox.stub(StarweaveLlm.MockBertEmbedder, :embed, fn _ -> 
        {:ok, [0.0, 0.0, 0.0, 0.0, 0.0]} 
      end)
      
      # Stub the LLM for the first call (with conversation history)
      Mox.stub(StarweaveLlm.MockLLM, :complete, fn prompt ->
        # Verify the prompt includes the conversation history
        assert prompt =~ ~r/How do I use the pattern matcher\?/
        assert prompt =~ ~r/You can use it like this\.\.\./
        assert prompt =~ ~r/Can you show me an example\?/
        
        # Return a simple response for testing
        {:ok, "Here's how you can use the pattern matcher..."}
      end)
      
      # Update the mock knowledge base with test data
      :ok = MockKnowledgeBase.update_search_results(
        kb_pid, 
        [%{
          id: "test1",
          score: 0.95,
          entry: test_entry,
          context: %{file_path: test_entry.file_path, content: "Example content"},
          file_path: test_entry.file_path,
          content: test_entry.content,
          metadata: test_entry.metadata,
          search_type: :semantic
        }],
        []
      )
      
      # Call the query function with conversation history
      assert {:ok, response} = QueryService.query(
        query_service,
        query,
        conversation_history: conversation_history,
        raw_results: false
      )
      
      # Verify the response is a string (formatted response)
      assert is_binary(response)
      
      # Test with raw_results: true - should not use LLM
      assert {:ok, results} = QueryService.query(
        query_service,
        query,
        conversation_history: conversation_history,
        raw_results: true
      )
      
      # Should return the raw results
      assert is_list(results)
      assert length(results) > 0
    end
  end
end
