defmodule StarweaveLlm.LLM.QueryIntent do
  @moduledoc """
  Handles detection of user intent from natural language queries.
  
  This module is responsible for determining the user's intent when making a query,
  such as  code explanation, documentation, or general
  information. This helps route the query to the appropriate handler and provide
  more relevant responses.
  """
  
  @type intent :: :code_explanation | :documentation | :knowledge_base | :unknown
  @type intent_result :: {:ok, intent(), String.t()} | {:error, any()}
  
  @doc """
  Detects the intent of a user query.
  
  ## Parameters
    * `query` - The user's query string
    * `opts` - Additional options
      * `:llm_client` - The LLM client module to use (must implement LLMBehaviour)
      * `:conversation_history` - List of previous messages in the conversation
  
  ## Returns
    * `{:ok, intent, processed_query}` - The detected intent and potentially modified query
    * `{:error, reason}` - If intent detection fails
  """
  @spec detect(String.t(), keyword()) :: intent_result()
  def detect(query, opts \\ []) when is_binary(query) do
    # First, check for simple patterns that don't require LLM
    case detect_simple_intent(query) do
      {:ok, intent} ->
        {:ok, intent, query}
      :unknown ->
        # If simple detection fails, check if we should use LLM
        if Keyword.get(opts, :use_llm, true) do
          llm_client = Keyword.get(opts, :llm_client, StarweaveLlm.LLM.Ollama)
          detect_with_llm(query, llm_client, opts)
        else
          # Default to knowledge base if LLM is disabled
          {:ok, :knowledge_base, query}
        end
    end
  end
  
  @doc """
  Extracts a filename from a query asking to explain code.
  
  ## Examples
      iex> extract_filename("explain lib/foo/bar.ex from your codebase")
      "lib/foo/bar.ex"
      
      iex> extract_filename("no match here")
      nil
  """
  @spec extract_filename(String.t()) :: String.t() | nil
  def extract_filename(query) when is_binary(query) do
    case Regex.run(~r/explain\s+([\w\._\/]+)\s+from\s+your\s+codebase/i, query) do
      [_, filename] -> filename
      _ -> nil
    end
  end
  
  defp detect_simple_intent(query) when is_binary(query) do
    query = String.downcase(query)
    
    cond do
      # Code explanation patterns - more comprehensive matching
      String.contains?(query, [
        "what does this code do", 
        "explain this code", 
        "how does this work",
        "can you explain",
        "what does this function",
        "how does this function"
      ]) ->
        {:ok, :code_explanation}
        
      # Documentation patterns - more comprehensive matching
      String.contains?(query, [
        "documentation for", 
        "how do i use", 
        "example of",
        "show me the docs",
        "reference for",
        "api for",
        "manual for"
      ]) or String.starts_with?(query, ["how to "]) ->
        {:ok, :documentation}
        
      # Knowledge base patterns - more comprehensive matching
      String.contains?(query, [
        "what is", 
        "who is", 
        "tell me about",
        "when was",
        "where is",
        "why does",
        "how to"
      ]) or 
      Regex.match?(~r/^(what|who|when|where|why|how)\s+[a-z\s]+\?*$/i, query) ->
        {:ok, :knowledge_base}
        
      true ->
        :unknown
    end
  end
  
  @spec detect_with_llm(String.t(), module(), keyword()) :: intent_result()
  defp detect_with_llm(query, llm_client, _opts) do
    prompt = build_intent_detection_prompt(query)
    
    with {:ok, response} <- llm_client.query(prompt),
         {:ok, intent, _} = result <- parse_intent_response(response, query) do
      result
    else
      _ ->
        # Fall back to knowledge base if LLM fails
        {:ok, :knowledge_base, query}
    end
  end
  
  defp build_intent_detection_prompt(query) do
    """
    Analyze the following user query and determine the most appropriate intent category:

    Query: #{query}

    Available intents:
    - CODE_EXPLANATION: If the user is asking to explain or understand code
    - DOCUMENTATION: If the user is looking for documentation or examples
    - KNOWLEDGE_BASE: If the user is asking a general knowledge question

    Respond with only the intent name (e.g., CODE_EXPLANATION).
    """
  end
  
  defp parse_intent_response(response, original_query) do
    response = String.trim(response)
    
    intent = case response do
      "CODE_EXPLANATION" -> :code_explanation
      "DOCUMENTATION" -> :documentation
      _ -> :knowledge_base
    end
    
    {:ok, intent, original_query}
  end
  
  @doc """
  Returns a human-readable description of an intent atom.
  
  ## Examples
      iex> describe_intent(:code_explanation)
      "code explanation"
  """
  @spec describe_intent(atom()) :: String.t()
  def describe_intent(:code_explanation), do: "code explanation"
  def describe_intent(:documentation), do: "documentation lookup"
  def describe_intent(:knowledge_base), do: "general knowledge"
  def describe_intent(:unknown), do: "unknown intent"
  def describe_intent(_), do: "unknown intent"
end
