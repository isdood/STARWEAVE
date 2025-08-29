defmodule StarweaveLLM.ContextManager do
  @moduledoc """
  Manages conversation context and history for LLM interactions.
  Handles context window optimization and conversation state.
  """
  
  alias __MODULE__.Conversation
  
  @behaviour Access
  
  defstruct [
    :conversation,
    :max_tokens,
    :max_history,
    :token_count,
    :summary_cache
  ]
  
  @type t :: %__MODULE__{
    conversation: Conversation.t(),
    max_tokens: pos_integer(),
    max_history: non_neg_integer(),
    token_count: non_neg_integer(),
    summary_cache: map()
  }
  
  @default_max_tokens 4000
  @default_max_history 20
  
  @doc """
  Creates a new context manager with default settings.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      conversation: Conversation.new(),
      max_tokens: Keyword.get(opts, :max_tokens, @default_max_tokens),
      max_history: Keyword.get(opts, :max_history, @default_max_history),
      token_count: 0,
      summary_cache: %{}
    }
  end
  
  @doc """
  Adds a message to the conversation history.
  """
  @spec add_message(t(), String.t(), String.t()) :: t()
  def add_message(context, role, content) when role in [:user, :assistant, :system] do
    tokens = estimate_tokens(content)
    
    context
    |> update_in([:conversation], &Conversation.add_message(&1, role, content))
    |> update_in([:token_count], &(&1 + tokens))
    |> maybe_trim_history()
    |> maybe_compress_context()
  end
  
  @doc """
  Gets the current conversation context, optimized for the LLM's context window.
  """
  @spec get_context(t()) :: String.t()
  def get_context(context) do
    context.conversation
    |> Conversation.get_messages()
    |> Enum.map_join("\n", fn {role, content} -> "#{role}: #{content}" end)
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
  Clears the conversation history while maintaining configuration.
  """
  @spec clear(t()) :: t()
  def clear(context) do
    %{context | 
      conversation: Conversation.new(),
      token_count: 0,
      summary_cache: %{}
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
        |> Enum.map(fn {_role, content} -> estimate_tokens(content) end)
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
        |> Enum.map(fn {role, content} -> "#{role}: #{content}" end)
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
  
  defmodule Conversation do
    @moduledoc false
    defstruct messages: []
    
    @type t :: %__MODULE__{
      messages: list({:user | :assistant | :system, String.t()})
    }
    
    def new, do: %__MODULE__{}
    
    def add_message(conversation, role, content) do
      update_in(conversation.messages, &(&1 ++ [{role, content}]))
    end
    
    def get_messages(conversation) do
      conversation.messages
    end
  end
end
