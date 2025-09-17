defmodule StarweaveLlm.SelfKnowledge.VectorSearchTest do
  use ExUnit.Case, async: false
  
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  
  setup context do
    # Generate unique names for each test run
    test_db_path = "/tmp/starweave_test_knowledge_base_#{:erlang.unique_integer([:positive])}.dets"
    table_name = :"test_knowledge_base_#{:erlang.unique_integer([:positive])}"
    
    # Clean up any existing test files
    File.rm_rf(test_db_path)
    
    # Start the knowledge base for testing with a unique name
    case KnowledgeBase.start_link(
      table_name: table_name,
      dets_path: test_db_path,
      name: table_name  # Use the table name as the registered name
    ) do
      {:ok, pid} ->
        # Add test data
        test_entries = [
          %{
            id: "test1",
            content: "Pattern matcher module that handles different matching strategies",
            file_path: "lib/starweave_core/pattern_matcher.ex",
            module: "StarweaveCore.PatternMatcher",
            function: "match/3",
            embedding: [0.1, 0.2, 0.3, 0.4, 0.5],
            last_updated: DateTime.utc_now()
          },
          %{
            id: "test2",
            content: "Main application entry point that starts the supervision tree",
            file_path: "lib/starweave/application.ex",
            module: "Starweave.Application",
            function: "start/2",
            embedding: [0.5, 0.4, 0.3, 0.2, 0.1],
            last_updated: DateTime.utc_now()
          }
        ]
        
        # Add test data to the knowledge base
        Enum.each(test_entries, fn entry ->
          :ok = KnowledgeBase.put(pid, entry.id, entry)
        end)
        
        # Return test context
        {:ok, Map.merge(context, %{
          knowledge_base: pid,
          test_entries: test_entries,
          test_db_path: test_db_path,
          table_name: table_name
        })}
        
      other ->
        # If we get here, there was an error starting the knowledge base
        # Clean up and fail the test
        File.rm_rf(test_db_path)
        flunk("Failed to start knowledge base: #{inspect(other)}")
    end
  end
  
  # Clean up after each test
  defp cleanup_knowledge_base(pid, test_db_path) do
    # Stop the knowledge base process
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal, 5000)
    end
    
    # Clean up the test file
    File.rm_rf(test_db_path)
  end

  test "finds similar entries using vector search", %{knowledge_base: kb, test_entries: [entry | _], test_db_path: test_db_path} do
    # Search with a query that should match our test entry
    query_embedding = [0.1, 0.2, 0.3, 0.4, 0.5]
    
    # Search with a high similarity threshold
    assert {:ok, [%{entry: found_entry, score: score}]} = 
      KnowledgeBase.vector_search(kb, query_embedding, min_similarity: 0.9)
    
    # Verify we found the expected entry
    assert found_entry.id == entry.id
    assert score >= 0.9
    
    # Clean up
    cleanup_knowledge_base(kb, test_db_path)
  end
  
  test "respects max_results parameter", %{knowledge_base: kb, test_db_path: test_db_path} do
    # Add a few more test entries
    extra_entries = [
      %{
        id: "test3",
        content: "Another test entry",
        file_path: "lib/test3.ex",
        module: "Test.Module3",
        embedding: [0.15, 0.25, 0.35, 0.45, 0.55],
        last_updated: DateTime.utc_now()
      },
      %{
        id: "test4",
        content: "Yet another test entry",
        file_path: "lib/test4.ex",
        module: "Test.Module4",
        embedding: [0.12, 0.22, 0.32, 0.42, 0.52],
        last_updated: DateTime.utc_now()
      }
    ]
    
    # Add the extra entries to the knowledge base
    Enum.each(extra_entries, fn entry ->
      :ok = KnowledgeBase.put(kb, entry.id, entry)
    end)
    
    query_embedding = [0.3, 0.3, 0.3, 0.3, 0.3]
    
    # Search with a low threshold but limit to 1 result
    assert {:ok, results} = KnowledgeBase.vector_search(
      kb, 
      query_embedding, 
      min_similarity: 0.1,
      max_results: 1
    )
    
    # Should only return 1 result even though more are similar enough
    assert length(results) == 1
    
    # Clean up
    cleanup_knowledge_base(kb, test_db_path)
  end
  
  test "returns empty list when no matches found", %{knowledge_base: kb, test_db_path: test_db_path} do
    # Search with a very different embedding
    query_embedding = [0.9, 0.8, 0.7, 0.6, 0.5]
    
    # Search with a high similarity threshold
    assert {:ok, []} = KnowledgeBase.vector_search(kb, query_embedding, min_similarity: 0.99)
    
    # Clean up
    cleanup_knowledge_base(kb, test_db_path)
  end
end
