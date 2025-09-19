defmodule StarweaveLlm.LLM.ChatTemplates do
  @moduledoc """
  Handles chat-specific prompt templates for the LLM.
  Uses the template system for rendering with variables.
  """
  
  alias StarweaveLlm.Prompt.Template
  
  @doc """
  Gets the system prompt for the LLM.
  """
  @spec system_prompt() :: String.t()
  def system_prompt do
    case Template.load_template(:system, :chat) do
      {:ok, template} -> template
      _ -> default_system_prompt()
    end
  end
  
  @doc """
  Generates a prompt for querying the knowledge base.
  """
  @spec knowledge_base_query_prompt(String.t(), list()) :: String.t()
  def knowledge_base_query_prompt(question, conversation_history \ []) do
    variables = %{
      question: question,
      conversation_history: Enum.map(conversation_history, &format_message/1)
    }
    
    case Template.render_template(:knowledge_base_query, :chat, variables) do
      {:ok, prompt} -> prompt
      _ -> default_knowledge_base_query_prompt(question, conversation_history)
    end
  end
  
  defp format_message(%{role: role, content: content}) do
    %{role: to_string(role), content: content}
  end
  
  defp default_system_prompt do
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
  
  defp default_knowledge_base_query_prompt(question, conversation_history) do
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
end
