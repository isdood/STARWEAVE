defmodule StarweaveLlm.LLM.PromptTemplates do
  @moduledoc """
  Defines prompt templates for the LLM to interact with the knowledge base.
  These templates help the LLM understand when and how to query the knowledge base.
  """

  @doc """
  System prompt that defines the LLM's behavior for knowledge base queries.
  """
  def system_prompt do
    """
    You are STARWEAVE, an AI assistant with deep knowledge of your own codebase.
    Your purpose is to help users understand how you work by providing accurate,
    context-aware explanations of your implementation.

    When a user asks a question about how you work or about specific features:
    1. First determine if the question requires knowledge of the codebase
    2. If so, use the provided knowledge base search to find relevant code
    3. Analyze the code and provide a clear, concise explanation
    4. Include relevant code snippets with proper syntax highlighting
    5. Always cite your sources by file path and line numbers

    Be technical but clear in your explanations. If you're not sure about something,
    say so rather than making assumptions.
    """
  end

  @doc """
  Generates a prompt for querying the knowledge base based on the user's question.
  """
  def knowledge_base_query_prompt(question, conversation_history \\ []) do
    history_text = 
      if Enum.empty?(conversation_history) do
        ""
      else
        """
        ## Conversation History:
        #{Enum.map_join(conversation_history, "\n", &format_message/1)}
        """
      end

    """
    #{history_text}

    ## User's Question:
    #{question}

    Based on the conversation history and user's question, determine if you need to search the knowledge base.
    If yes, generate a search query that would help find the most relevant information.
    If not, respond with "NO_SEARCH_NEEDED".
    """
  end

  @doc """
  Formats a response using knowledge base search results.
  """
  def format_knowledge_response(question, search_results) do
    context = 
      search_results
      |> Enum.map(fn result ->
        """
        ## File: #{result.file_path}
        ```elixir
        #{result.content}
        ```
        """
      end)
      |> Enum.join("\n")

    """
    Here's what I found about: #{question}

    #{context}

    Let me know if you'd like me to explain any part of this in more detail!
    """
  end

  defp format_message({:user, content}), do: "User: #{content}"
  defp format_message({:assistant, content}), do: "Assistant: #{content}"
end
