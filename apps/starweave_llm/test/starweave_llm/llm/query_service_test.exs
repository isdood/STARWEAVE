defmodule StarweaveLlm.LLM.QueryServiceTest do
  use ExUnit.Case, async: false
  import Mox
  
  alias StarweaveLlm.LLM.QueryService
  
  # Define the mock modules
  @mock_embedder StarweaveLlm.MockBertEmbedder
  
  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!
  
  # Set Mox in global mode for all tests
  setup :set_mox_global
  
  # Define a simple mock knowledge base server
  defmodule MockKnowledgeBase do
    use GenServer
    
    def start_link(opts) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end
    
    def init(opts) do
      search_result = Keyword.get(opts, :search_result, [])
      {:ok, %{search_result: search_result}}
    end
    
    # Update the search result for testing
    def update_search_result(pid \\ __MODULE__, result) do
      GenServer.call(pid, {:update_search_result, result})
    end
    
    # Handle vector search requests
    def handle_call({:vector_search, _embedding, _opts}, _from, %{search_result: result} = state) do
      {:reply, {:ok, result}, state}
    end
    
    # Handle update search result requests
    def handle_call({:update_search_result, result}, _from, state) do
      {:reply, :ok, %{state | search_result: result}}
    end
    
    # Default handler for other calls
    def handle_call(_request, _from, state) do
      {:reply, :ok, state}
    end
  end
  
  setup do
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
      }
    ]
    
    # Set up common test data
    test_embedding = [0.1, 0.2, 0.3, 0.4, 0.5]
    
    search_result = [
      %{
        id: "test1",
        score: 0.95,
        entry: List.first(test_entries),
        context: %{
          file_path: "lib/starweave_core/pattern_matcher.ex",
          content: "Module that implements pattern matching functionality..."
        }
      }
    ]
    
    # Start the mock knowledge base server with a registered name
    mock_kb_opts = [
      name: :mock_knowledge_base,
      search_result: search_result
    ]
    
    {:ok, _kb_pid} = start_supervised(
      {MockKnowledgeBase, mock_kb_opts}
    )
    
    # Start the query service with the mock knowledge base
    {:ok, query_service} = start_supervised(
      {StarweaveLlm.LLM.QueryService, 
       knowledge_base: :mock_knowledge_base, 
       embedder: @mock_embedder}
    )
    
    %{
      query_service: query_service,
      test_entries: test_entries,
      test_embedding: test_embedding,
      search_result: search_result
    }
  end

  describe "query/3" do
    test "returns relevant code snippets for a natural language query", %{
      query_service: query_service,
      test_entries: [test_entry | _],
      test_embedding: test_embedding,
      search_result: _search_result
    } do
      # Set up Mox expectations for this test
      Mox.expect(@mock_embedder, :embed, fn "How does the pattern matching work?" -> 
        {:ok, test_embedding}
      end)
      
      # Call the query function
      assert {:ok, response} = QueryService.query(query_service, "How does the pattern matching work?")
      
      # Verify the response contains the expected content
      assert is_binary(response)
      assert response != ""
      assert response =~ test_entry.content
      assert response =~ test_entry.file_path
    end
    
    test "handles no results found case", %{
      query_service: query_service,
      test_embedding: test_embedding
    } do
      test_query = "This is a query that won't match anything"
      
      # Set up Mox expectations for this test
      Mox.expect(@mock_embedder, :embed, fn ^test_query -> 
        {:ok, test_embedding}
      end)
      
      # Update the mock knowledge base to return no results for this test
      GenServer.call(:mock_knowledge_base, {:update_search_result, []})
      
      # Call the query function
      assert {:ok, response} = QueryService.query(query_service, test_query)
      
      # Verify the response indicates no results were found
      assert is_binary(response)
      assert response != ""
      assert response =~ test_query
    end
    
    test "includes conversation history in the prompt", %{
      query_service: query_service,
      test_entries: [test_entry | _],
      test_embedding: test_embedding
    } do
      # Create a conversation history
      conversation_history = [
        %{role: "user", content: "How do I use the pattern matcher?"},
        %{role: "assistant", content: "You can use it like this..."},
        %{role: "user", content: "Can you show me an example?"}
      ]
      
      query = "How do I use the pattern matcher?"
      
      # Set up Mox expectations for this test
      Mox.expect(@mock_embedder, :embed, fn ^query -> 
        {:ok, test_embedding}
      end)
      
      # Call the query function with conversation history
      assert {:ok, response} = 
               QueryService.query(
                 query_service,
                 query,
                 conversation_history: conversation_history
               )
      
      # Verify the response contains the expected content
      assert is_binary(response)
      assert response != ""
      assert response =~ test_entry.content
    end
  end
  
  # Note: Private functions are tested through the public API
end
