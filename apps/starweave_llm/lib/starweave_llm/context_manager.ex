defmodule StarweaveLlm.ContextManager do
  @moduledoc """
  Manages the conversation context and history for LLM interactions.
  Handles token counting, context window management, and conversation state.
  """
  
  alias __MODULE__.Conversation
  alias StarweaveLlm.Context.PersistentContext
  
  @behaviour Access
  
  defstruct [
    :conversation,
    :max_tokens,
    :max_history,
    :token_count,
    :summary_cache,
    :sources,
    :user_id
  ]
  
  @type t :: %__MODULE__{
    conversation: Conversation.t(),
    max_tokens: pos_integer(),
    max_history: non_neg_integer(),
    token_count: non_neg_integer(),
    summary_cache: map(),
    sources: %{optional(String.t()) => [map()]},
    user_id: String.t() | nil
  }
  
  @default_max_tokens 4000
  @default_max_history 20
  
  @doc """
  Creates a new context with the given options.

  Options:
  - :max_tokens - Maximum tokens for the context window (default: 4000)
  - :max_history - Maximum number of messages to keep in history (default: 20)
  - :user_id - User ID for persistent storage (optional)
  """
  def new(opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    
    context = %__MODULE__{
      conversation: Conversation.new(),
      max_tokens: Keyword.get(opts, :max_tokens, @default_max_tokens),
      max_history: Keyword.get(opts, :max_history, @default_max_history),
      token_count: 0,
      summary_cache: %{},
      sources: %{},
      user_id: user_id
    }
    
    # If user_id is provided, try to load existing context
    if user_id do
      case PersistentContext.load_context(user_id) do
        {:ok, saved_context} -> 
          %{saved_context | user_id: user_id}
        _ -> 
          context
      end
    else
      context
    end
  end
  
  @doc """
  Adds a message to the conversation history.
  """
  @spec add_message(t(), atom(), String.t(), list() | nil) :: t()
  def add_message(context, role, content, sources \\ nil) do
    updated_context = 
      case role do
        role when role in [:user, :system] ->
          tokens = estimate_tokens(content)
          {updated_conv, _message_id} = Conversation.add_message(context.conversation, role, content)
          
          context
          |> Map.put(:conversation, updated_conv)
          |> update_in([:token_count], &(&1 + tokens))
          
        :assistant ->
          tokens = estimate_tokens(content)
          {updated_conv, message_id} = Conversation.add_message(context.conversation, :assistant, content, sources)
          
          context
          |> Map.put(:conversation, updated_conv)
          |> update_in([:token_count], &(&1 + tokens))
          |> update_in([:sources], &Map.put(&1, message_id, sources || []))
      end
      |> maybe_trim_history()
      |> maybe_compress_context()
    
    # Persist the context if user_id is set
    if updated_context.user_id do
      :ok = PersistentContext.save_context(updated_context, updated_context.user_id)
    end
    
    updated_context
  end
  
  @doc """
  Gets the current conversation context, optimized for the LLM's context window.
  """
  @spec get_context(t()) :: String.t()
  def get_context(context) do
    context.conversation
    |> Conversation.get_messages()
    |> Enum.map_join("\n", fn {role, content, message_id} -> 
      case role do
        :assistant -> 
          sources = Map.get(context.sources, message_id, [])
          source_text = if sources != [], do: "\nSources:\n" <> format_sources(sources), else: ""
          "#{role}: #{content}#{source_text}"
        _ -> 
          "#{role}: #{content}"
      end
    end)
  end
  
  @doc """
  Gets the sources for a specific assistant message.
  """
  @spec get_sources(t(), String.t()) :: [map()]
  def get_sources(context, message_id) when is_binary(message_id) do
    Map.get(context.sources, message_id, [])
  end
  
  @spec get_sources_by_content(t(), String.t()) :: [map()]
  def get_sources_by_content(context, content) do
    case Enum.find(context.conversation.messages, fn {_role, msg_content, _id} -> msg_content == content end) do
      {_role, _content, message_id} -> get_sources(context, message_id)
      nil -> []
    end
  end
  
  defp format_sources(sources) do
    sources
    |> Enum.map(fn source ->
      "- #{source[:title] || source[:url] || "Unknown source"}" <> 
        if(source[:snippet], do: ": #{source[:snippet]}", else: "")
    end)
    |> Enum.join("\n")
  end
  
  @doc """
  Gets the current token count.
  """
  @spec get_token_count(t()) :: non_neg_integer()
  def get_token_count(context) do
    context.token_count
  end
  
  @doc """
  Gets a compressed version of the context if it exceeds token limits.
  """
  @spec get_compressed_context(t()) :: String.t()
  def get_compressed_context(context) do
    if context.token_count > context.max_tokens do
      get_summarized_context(context)
    else
      get_context(context)
    end
  end
  
  @doc """
  Clears the conversation history and resets the context.
  If the context has a user_id, also clears the persistent storage.
  """
  @spec clear(t()) :: t()
  def clear(%{user_id: user_id} = context) when is_binary(user_id) do
    :ok = PersistentContext.clear_context(user_id)
    do_clear(context)
  end
  
  def clear(context), do: do_clear(context)
  
  defp do_clear(context) do
    %{
      context |
      conversation: Conversation.new(),
      token_count: 0,
      summary_cache: %{},
      sources: %{}
    }
  end
  
  @doc """
  Estimates the number of tokens in a text string.
  This is a rough approximation based on word count and character count.
  """
  @spec estimate_tokens(String.t()) :: non_neg_integer()
  def estimate_tokens(text) when is_binary(text) do
    # Rough approximation: 1 token ≈ 4 characters or 0.75 words
    char_count = String.length(text)
    word_count = text |> String.split(~r/\s+/) |> length()
    
    char_tokens = div(char_count, 4)
    word_tokens = div(word_count * 3, 4)
    
    max(char_tokens, word_tokens)
  end
  
  defp maybe_trim_history(context) do
    if length(context.conversation.messages) > context.max_history do
      # Remove oldest messages and recalculate token count
      trimmed_messages = Enum.take(context.conversation.messages, -context.max_history)
      new_token_count = 
        trimmed_messages
        |> Enum.map(fn 
          {_role, content, _id} -> estimate_tokens(content)  # Handle {role, content, id} format
          {_role, content} -> estimate_tokens(content)        # Handle {role, content} format
        end)
        |> Enum.sum()
      
      %{context | 
        conversation: %{context.conversation | messages: trimmed_messages},
        token_count: new_token_count
      }
    else
      context
    end
  end
  
  defp maybe_compress_context(context) do
    if context.token_count > context.max_tokens do
      # Mark context for compression
      context
    else
      context
    end
  end
  
  defp get_summarized_context(context) do
    # Create a summary of the conversation history
    messages = context.conversation.messages
    
    summary = 
      messages
      |> Enum.chunk_every(3)
      |> Enum.map_join("\n", fn chunk ->
        chunk
        |> Enum.map(fn 
          {role, content, _id} -> "#{role}: #{content}"  # Handle {role, content, id} format
          {role, content} -> "#{role}: #{content}"        # Handle {role, content} format
        end)
        |> Enum.join("\n")
      end)
    
    # Add a note about summarization
    "Conversation Summary (compressed due to length):\n#{summary}\n\n[Previous conversation has been summarized for context window limits]"
  end
  
  # Access behaviour implementation
  @impl Access
  def fetch(context, key) when is_atom(key) do
    case key do
      :conversation -> {:ok, context.conversation}
      :max_tokens -> {:ok, context.max_tokens}
      :max_history -> {:ok, context.max_history}
      :token_count -> {:ok, context.token_count}
      :summary_cache -> {:ok, context.summary_cache}
      _ -> :error
    end
  end
  
  @impl Access
  def get_and_update(context, key, fun) when is_atom(key) do
    case key do
      :conversation -> 
        {old_value, new_conversation} = fun.(context.conversation)
        {old_value, %{context | conversation: new_conversation}}
      :max_tokens -> 
        {old_value, new_max_tokens} = fun.(context.max_tokens)
        {old_value, %{context | max_tokens: new_max_tokens}}
      :max_history -> 
        {old_value, new_max_history} = fun.(context.max_history)
        {old_value, %{context | max_history: new_max_history}}
      :token_count -> 
        {old_value, new_token_count} = fun.(context.token_count)
        {old_value, %{context | token_count: new_token_count}}
      :summary_cache -> 
        {old_value, new_summary_cache} = fun.(context.summary_cache)
        {old_value, %{context | summary_cache: new_summary_cache}}
      _ -> 
        {nil, context}
    end
  end
  
  @impl Access
  def pop(context, key) when is_atom(key) do
    case key do
      :conversation -> {context.conversation, %{context | conversation: Conversation.new()}}
      :max_tokens -> {context.max_tokens, %{context | max_tokens: @default_max_tokens}}
      :max_history -> {context.max_history, %{context | max_history: @default_max_history}}
      :token_count -> {context.token_count, %{context | token_count: 0}}
      :summary_cache -> {context.summary_cache, %{context | summary_cache: %{}}}
      _ -> {nil, context}
    end
  end
  
end
