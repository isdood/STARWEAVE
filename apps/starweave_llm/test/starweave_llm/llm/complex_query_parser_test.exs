defmodule StarweaveLlm.LLM.ComplexQueryParserTest do
  use ExUnit.Case, async: true
  alias StarweaveLlm.LLM.ComplexQueryParser

  describe "parse/1" do
    test "parses simple query" do
      assert {:ok, [%{type: :search, content: "find all functions"}]} == 
               ComplexQueryParser.parse("find all functions")
    end

    test "parses query with multiple intents" do
      query = "find all functions and then explain the pattern matcher"
      
      assert {:ok, [
        %{type: :search, content: "find all functions"},
        %{type: :search, content: "then explain the pattern matcher"}
      ]} = ComplexQueryParser.parse(query)
    end

    test "handles conjunctions" do
      query = "search for database queries and then optimize them"
      
      assert {:ok, [
        %{type: :search, content: "search for database queries"},
        %{type: :search, content: "then optimize them"}
      ]} = ComplexQueryParser.parse(query)
    end

    test "handles then as a separator" do
      query = "find all tests then run them"
      
      assert {:ok, [
        %{type: :search, content: "find all tests"},
        %{type: :execute, content: "run them"}
      ]} = ComplexQueryParser.parse(query)
    end
  end

  describe "parse_intent/1" do
    test "identifies search intent" do
      assert {:search, "find functions"} = 
               ComplexQueryParser.parse_intent("find functions")
    end

    test "identifies explain intent" do
      assert {:explain, " this code"} = 
               ComplexQueryParser.parse_intent("explain this code")
    end

    test "defaults to search intent" do
      assert {:search, "just some text"} = 
               ComplexQueryParser.parse_intent("just some text")
    end
  end
end
