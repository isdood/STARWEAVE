defmodule StarweaveLlm.LLMTestHelper do
  @moduledoc """
  Helper module for testing LLM integration with Ollama.
  """
  
  @doc """
  Tests the LLM query service with a real Ollama instance.
  
  This is a manual test that requires Ollama to be running locally.
  """
  def test_llm_query(knowledge_base, query, opts \\ []) do
    IO.puts("\n=== Testing LLM Query ===")
    IO.puts("Query: #{query}")
    
    # Execute the query
    {time, result} = :timer.tc(fn ->
      StarweaveLlm.LLM.QueryService.query(knowledge_base, query, opts)
    end)
    
    # Print results
    case result do
      {:ok, response} ->
        IO.puts("\nResponse (#{div(time, 1000)} ms):")
        IO.puts("----------------------------------------")
        IO.puts(response)
        IO.puts("----------------------------------------")
        
      {:error, reason} ->
        IO.puts("\nError: #{inspect(reason)}")
    end
    
    result
  end
  
  @doc """
  Interactive test session for LLM queries.
  """
  def interactive_session(knowledge_base) do
    IO.puts("\n=== STARWEAVE LLM Test Session ===")
    IO.puts("Type your queries or 'exit' to quit\n")
    
    # Start the interactive loop
    loop(knowledge_base)
  end
  
  defp loop(knowledge_base) do
    # Get user input
    query = IO.gets("\nQuery: ") |> String.trim()
    
    # Check for exit condition
    if query in ["exit", "quit", "q"] do
      IO.puts("\nExiting test session...")
      :ok
    else
      # Execute the query
      test_llm_query(knowledge_base, query, [])
      
      # Continue the loop
      loop(knowledge_base)
    end
  end
end
