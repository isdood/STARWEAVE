defmodule StarweaveLlm.SelfKnowledge.QueryEngine do
  @moduledoc """
  Handles querying the self-knowledge base with natural language.
  """

  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  
  @doc """
  Queries the knowledge base with a natural language question.
  Returns a list of relevant code snippets and their metadata.
  """
  def query(knowledge_base, question) when is_binary(question) do
    # In a real implementation, you would:
    # 1. Generate embeddings for the query
    # 2. Perform vector similarity search
    # 3. Return the most relevant results
    
    # For now, we'll do a simple text search
    case KnowledgeBase.search(knowledge_base, question, limit: 5) do
      {:ok, results} ->
        # Format the results for display
        formatted_results = 
          results
          |> Enum.map(fn %{entry: entry, score: score} ->
            %{
              file_path: entry.file_path,
              content: String.slice(entry.content, 0..200) <> "...",
              score: score,
              last_updated: entry.last_updated
            }
          end)
        
        {:ok, formatted_results}
      
      error ->
        error
    end
  end
  
  @doc """
  Explains a specific piece of code in the context of the codebase.
  """
  def explain_code(knowledge_base, file_path, line_number) do
    with {:ok, entry} <- KnowledgeBase.get(knowledge_base, file_path) do
      # In a real implementation, you would:
      # 1. Parse the file to understand the context around the line
      # 2. Find related code (functions, modules, etc.)
      # 3. Generate a natural language explanation
      
      # For now, we'll just return the surrounding lines
      lines = String.split(entry.content, "\n")
      start_line = max(0, line_number - 5)
      end_line = min(length(lines) - 1, line_number + 5)
      
      context = 
        lines
        |> Enum.slice(start_line..end_line)
        |> Enum.with_index(start_line + 1)
        |> Enum.map(fn {line, idx} -> "#{idx}: #{line}" end)
        |> Enum.join("\n")
      
      {:ok, %{
        file_path: file_path,
        line_number: line_number,
        context: context
      }}
    end
  end
  
  @doc """
  Finds code examples related to a specific concept or function.
  """
  def find_examples(knowledge_base, concept) when is_binary(concept) do
    # In a real implementation, you would:
    # 1. Search for the concept in the knowledge base
    # 2. Find example usages
    # 3. Return the most relevant examples
    
    # For now, we'll just do a simple search
    query(knowledge_base, "example of #{concept}")
  end
  
  @doc """
  Finds all references to a specific function or module.
  """
  def find_references(knowledge_base, module_or_function) when is_binary(module_or_function) do
    # In a real implementation, you would:
    # 1. Parse the code to build a reference graph
    # 2. Find all references to the given module or function
    # 3. Return the locations and context of each reference
    
    # For now, we'll just do a simple search
    query(knowledge_base, "references to #{module_or_function}")
  end
end
