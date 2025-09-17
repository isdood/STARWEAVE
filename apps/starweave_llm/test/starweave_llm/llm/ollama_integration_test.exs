defmodule StarweaveLlm.LLM.OllamaIntegrationTest do
  use ExUnit.Case, async: false
  alias StarweaveLlm.LLM.QueryService
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  
  @moduletag :integration
  @tag :skip # Skip by default, only run explicitly
  
  @test_db_path "/tmp/starweave_ollama_test.dets"
  
  setup do
    # Skip if OLLAMA_HOST is not set
    unless System.get_env("OLLAMA_HOST") do
      IO.puts("Skipping Ollama integration test - OLLAMA_HOST not set")
      :skip
    else
      # Start the knowledge base for testing
      {:ok, kb_pid} = KnowledgeBase.start_link(
        table_name: :test_ollama_knowledge_base,
        dets_path: @test_db_path
      )
      
      # Add test data with known embeddings
      test_entries = [
        %{
          id: "pattern_matcher_1",
          content: """
          Pattern matcher module that handles different matching strategies:
          - exact: Matches strings exactly
          - contains: Matches if the string contains the query
          - jaccard: Uses Jaccard similarity for fuzzy matching
          
          Example usage:
          ```elixir
          # Find patterns that contain 'error'
          patterns = StarweaveCore.PatternMatcher.match(patterns, "error", strategy: :contains)
          ```
          """,
          file_path: "lib/starweave_core/pattern_matcher.ex",
          module: "StarweaveCore.PatternMatcher",
          function: "match/3",
          last_updated: DateTime.utc_now()
        },
        %{
          id: "application_1",
          content: """
          Main application entry point that starts the supervision tree.
          
          This module is responsible for starting all the main application
          supervisors and workers in the correct order.
          """,
          file_path: "lib/starweave/application.ex",
          module: "Starweave.Application",
          function: "start/2",
          last_updated: DateTime.utc_now()
        }
      ]
      
      # Insert test data
      for entry <- test_entries do
        # Generate embeddings for the content
        {:ok, embedding} = StarweaveLlm.Embeddings.BertEmbedder.embed(entry.content)
        entry = Map.put(entry, :embedding, embedding)
        :ok = KnowledgeBase.put(kb_pid, entry.id, entry)
      end
      
      on_exit(fn ->
        # Clean up test database
        File.rm(@test_db_path)
      end)
      
      {:ok, knowledge_base: kb_pid}
    end
  end
  
  @tag :ollama
  test "queries knowledge base with Ollama integration", %{knowledge_base: kb} do
    # Skip if OLLAMA_HOST is not set
    unless System.get_env("OLLAMA_HOST") do
      :skip
    else
      # Test query that should match our pattern matcher entry
      test_query = "How do I use the pattern matcher to find error patterns?"
      
      # Execute the query with a reasonable timeout
      case QueryService.query(kb, test_query, [
        min_similarity: 0.5,
        max_results: 3
      ]) do
        {:ok, response} ->
          IO.puts("\n=== LLM Response ===")
          IO.puts(response)
          IO.puts("===================")
          
          # Basic validation of the response
          assert is_binary(response)
          assert String.length(response) > 0
          
          # The response should contain information about the pattern matcher
          assert String.downcase(response) =~ ~r/pattern.*match/i
          
        {:error, reason} ->
          flunk("Query failed: #{inspect(reason)}")
      end
    end
  end
  
  @tag :ollama
  test "handles queries with no relevant results", %{knowledge_base: kb} do
    # Skip if OLLAMA_HOST is not set
    unless System.get_env("OLLAMA_HOST") do
      :skip
    else
      # Test query that won't match any entries
      test_query = "This is a query that won't match anything in the knowledge base"
      
      # Execute the query with a high similarity threshold
      case QueryService.query(kb, test_query, [
        min_similarity: 0.9,
        max_results: 3
      ]) do
        {:ok, response} ->
          IO.puts("\n=== LLM Response (No Results) ===")
          IO.puts(response)
          IO.puts("==============================")
          
          # Basic validation of the response
          assert is_binary(response)
          assert String.length(response) > 0
          
          # The response should indicate no results were found
          assert String.downcase(response) =~ ~r/(no.*result|not.*find|no.*information)/i
          
        {:error, reason} ->
          flunk("Query failed: #{inspect(reason)}")
      end
    end
  end
end
