defmodule StarweaveLlm.LLM.QueryIntentTest do
  use ExUnit.Case, async: true
  import Mox
  
  # Define the mock module
  Mox.defmock(StarweaveLlm.LLM.MockLLM, for: StarweaveLlm.LLM.LLMBehaviour)
  
  # Required for Mox
  setup :verify_on_exit!
  setup :set_mox_from_context
  
  alias StarweaveLlm.LLM.QueryIntent
  
  describe "detect/2" do
    test "detects code explanation patterns without LLM calls" do
      # These should be caught by simple pattern matching
      test_cases = [
        {"What does this code do?", :code_explanation},
        {"Can you explain this function?", :code_explanation},
        {"How does this work?", :code_explanation},
        {"Explain this code snippet", :code_explanation}
      ]
      
      for {query, expected_intent} <- test_cases do
        assert {:ok, ^expected_intent, ^query} = QueryIntent.detect(query, use_llm: false)
      end
    end
    
    test "detects documentation patterns without LLM calls" do
      # These should be caught by simple pattern matching
      test_cases = [
        {"Show me the documentation for String.split", :documentation},
        {"How do I use Enum.map?", :documentation},
        {"Example of using GenServer", :documentation},
        {"API for Task.async", :documentation}
      ]
      
      for {query, expected_intent} <- test_cases do
        assert {:ok, ^expected_intent, ^query} = QueryIntent.detect(query, use_llm: false)
      end
    end
    
    test "detects knowledge base patterns without LLM calls" do
      # These should be caught by simple pattern matching
      test_cases = [
        {"What is the capital of France?", :knowledge_base},
        {"Tell me about the history of Elixir", :knowledge_base},
        {"Who created the Phoenix framework?", :knowledge_base},
        {"When was Elixir first released?", :knowledge_base},
        {"Where is the Eiffel Tower?", :knowledge_base},
        {"Why does Elixir use the BEAM?", :knowledge_base}
      ]
      
      for {query, expected_intent} <- test_cases do
        assert {:ok, ^expected_intent, ^query} = QueryIntent.detect(query, use_llm: false)
      end
    end
    
    test "returns knowledge base for non-matching patterns when LLM is disabled" do
      # These don't match any simple patterns, so they should fall back to knowledge base
      queries = [
        "Let's go to the park",
        "The quick brown fox",
        "12345",
        ""
      ]
      
      for query <- queries do
        assert {:ok, :knowledge_base, ^query} = QueryIntent.detect(query, use_llm: false)
      end
    end
    
    test "uses LLM for complex queries when enabled" do
      # Mock the LLM response for a complex query
      StarweaveLlm.LLM.MockLLM
      |> expect(:complete, fn prompt -> 
        assert String.contains?(prompt, "Please analyze this complex code")
        {:ok, "CODE_EXPLANATION"}
      end)
      
      # This query doesn't match any simple patterns, so it should use the LLM
      assert {:ok, :code_explanation, "Please analyze this complex code"} = 
        QueryIntent.detect(
          "Please analyze this complex code", 
          llm_client: StarweaveLlm.LLM.MockLLM,
          use_llm: true
        )
    end
    
    test "falls back to knowledge base on LLM failure" do
      # Mock the LLM to fail
      StarweaveLlm.LLM.MockLLM
      |> expect(:complete, fn _prompt -> 
        {:error, :timeout}
      end)
      
      # Should fall back to knowledge base when LLM fails
      assert {:ok, :knowledge_base, "Some complex query"} = 
        QueryIntent.detect(
          "Some complex query", 
          llm_client: StarweaveLlm.LLM.MockLLM,
          use_llm: true
        )
    end
  end
  
  describe "describe_intent/1" do
    test "returns human-readable intent descriptions" do
      assert QueryIntent.describe_intent(:code_explanation) == "code explanation"
      assert QueryIntent.describe_intent(:documentation) == "documentation lookup"
      assert QueryIntent.describe_intent(:knowledge_base) == "knowledge base query"
      assert QueryIntent.describe_intent(:unknown) == "unknown intent"
    end
  end
end
