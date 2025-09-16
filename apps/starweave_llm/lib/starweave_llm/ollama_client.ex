defmodule StarweaveLlm.OllamaClient do
  @moduledoc """
  Enhanced Ollama HTTP client with context management, memory integration, and template support.
  """
  require Logger

  alias StarweaveLlm.ContextManager
  alias StarweaveLlm.MemoryIntegration
  alias StarweaveLlm.Prompt.Template

  @type opts :: [
    model: String.t(), 
    host: String.t(),
    template: String.t(),
    use_memory: boolean(),
    memory_limit: non_neg_integer(),
    context_manager: ContextManager.t()
  ]

  @spec chat(String.t(), opts()) :: {:ok, String.t()} | {:error, term()}
  def chat(prompt, opts \\ []) when is_binary(prompt) do
    host = Keyword.get(opts, :host, System.get_env("OLLAMA_HOST") || "http://localhost:11434")
    model = Keyword.get(opts, :model, System.get_env("OLLAMA_MODEL") || "llama3.1")
    template_name = Keyword.get(opts, :template, :default)
    use_memory = Keyword.get(opts, :use_memory, true)
    memory_limit = Keyword.get(opts, :memory_limit, 5)
    context_manager = Keyword.get(opts, :context_manager)

    # Prepare context and memory
    context = prepare_context(context_manager, prompt)
    memories = if use_memory, do: retrieve_relevant_memories(prompt, memory_limit), else: []
    
    # Render template with context and memories
    template_vars = %{
      user_message: prompt,
      context: context,
      memories: memories,
      patterns: []  # Placeholder for pattern data
    }
    
    case Template.render_template(template_name, template_vars) do
      {:ok, rendered_prompt} ->
        send_to_ollama(rendered_prompt, model, host)
      
      {:error, reason} ->
        Logger.error("Template rendering failed: #{reason}")
        # Fallback to simple prompt
        send_to_ollama(prompt, model, host)
    end
  end

  @doc """
  Chat with context management and automatic memory storage.
  """
  @spec chat_with_context(String.t(), ContextManager.t(), opts()) :: 
          {:ok, String.t(), ContextManager.t()} | {:error, term()}
  def chat_with_context(prompt, context_manager, opts \\ []) do
    # Add user message to context
    context_manager = ContextManager.add_message(context_manager, :user, prompt)
    
    # Get chat response
    case chat(prompt, Keyword.put(opts, :context_manager, context_manager)) do
      {:ok, response} ->
        # Add assistant response to context
        context_manager = ContextManager.add_message(context_manager, :assistant, response)
        
        # Store the interaction as memory
        store_interaction_memory(prompt, response)
        
        {:ok, response, context_manager}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Performs pattern analysis using the pattern engine and LLM.
  """
  @spec analyze_patterns(String.t(), [map()], opts()) :: {:ok, String.t()} | {:error, term()}
  def analyze_patterns(query, patterns, opts \\ []) do
    template_vars = %{
      user_message: query,
      patterns: patterns,
      context: "",
      memories: []
    }
    
    case Template.render_template(:pattern_analysis, template_vars) do
      {:ok, rendered_prompt} ->
        send_to_ollama(rendered_prompt, Keyword.get(opts, :model, "llama3.1"), 
                      Keyword.get(opts, :host, "http://localhost:11434"))
      
      {:error, reason} ->
        {:error, "Template rendering failed: #{reason}"}
    end
  end

  @doc """
  Retrieves and consolidates memories for a query.
  """
  @spec retrieve_memories(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def retrieve_memories(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_relevance = Keyword.get(opts, :min_relevance, 0.3)
    
    memory_query = %{
      query: query,
      limit: limit,
      min_relevance: min_relevance
    }
    
    memories = MemoryIntegration.retrieve_memories(memory_query)
    consolidated = MemoryIntegration.consolidate_memories(memories)
    
    {:ok, consolidated}
  end

  # Private functions

  defp prepare_context(context_manager, _prompt) do
    if context_manager do
      ContextManager.get_compressed_context(context_manager)
    else
      ""
    end
  end

  defp retrieve_relevant_memories(prompt, limit) do
    memory_query = %{
      query: prompt,
      limit: limit,
      min_relevance: 0.3
    }
    
    MemoryIntegration.retrieve_memories(memory_query)
  end

  defp store_interaction_memory(prompt, response) do
    interaction_content = "User: #{prompt}\nAssistant: #{response}"
    metadata = %{
      type: "conversation",
      timestamp: DateTime.utc_now(),
      interaction: true
    }
    
    MemoryIntegration.store_memory(interaction_content, metadata)
  end

  defp send_to_ollama(prompt, model, host) do
    url = host |> URI.parse() |> URI.merge("/api/chat") |> URI.to_string()

    body = %{
      model: model,
      messages: [
        %{role: "user", content: prompt}
      ],
      stream: false
    }

    case Req.post(url: url, json: body, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Ollama API error: #{status} - #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Ollama request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
