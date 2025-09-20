defmodule StarweaveLlm.Context.PersistentContext do
  @moduledoc """
  Manages persistent conversation context using WorkingMemory.
  This module handles saving and loading conversation state to/from persistent storage.
  """
  
  alias StarweaveCore.Intelligence.WorkingMemory
  alias StarweaveLlm.ContextManager
  alias StarweaveLlm.ContextManager.Conversation
  
  @context_key :conversation_context
  @sources_key :conversation_sources
  
  @doc """
  Saves the current conversation context to persistent storage.
  """
  @spec save_context(ContextManager.t(), String.t()) :: :ok | {:error, any()}
  def save_context(context, user_id) when is_binary(user_id) do
    with :ok <- save_conversation(context.conversation, user_id),
         :ok <- save_sources(context.sources, user_id) do
      :ok
    end
  end
  
  @doc """
  Loads a previously saved conversation context from persistent storage.
  """
  @spec load_context(String.t()) :: {:ok, ContextManager.t()} | {:error, any()}
  def load_context(user_id) when is_binary(user_id) do
    with {:ok, conversation} <- load_conversation(user_id),
         {:ok, sources} <- load_sources(user_id) do
      
      # Create a new context with the loaded data
      context = 
        ContextManager.new()
        |> Map.put(:conversation, conversation)
        |> Map.put(:sources, sources || %{})
        
      # Recalculate token count
      token_count = 
        conversation
        |> Conversation.get_messages()
        |> Enum.reduce(0, fn {_role, content, _id}, acc ->
          acc + ContextManager.estimate_tokens(content)
        end)
        
      {:ok, %{context | token_count: token_count}}
    end
  end
  
  @doc """
  Clears the persistent conversation context for a user.
  """
  @spec clear_context(String.t()) :: :ok | {:error, any()}
  def clear_context(user_id) when is_binary(user_id) do
    with :ok <- WorkingMemory.clear_context(@context_key),
         :ok <- WorkingMemory.clear_context(@sources_key) do
      :ok
    end
  end
  
  # Private functions
  
  defp save_conversation(conversation, user_id) do
    WorkingMemory.store(@context_key, user_id, conversation)
  end
  
  defp load_conversation(user_id) do
    case WorkingMemory.retrieve(@context_key, user_id) do
      :not_found -> {:ok, Conversation.new()}
      {:ok, conversation} -> {:ok, conversation}
      error -> error
    end
  end
  
  defp save_sources(sources, user_id) do
    WorkingMemory.store(@sources_key, user_id, sources)
  end
  
  defp load_sources(user_id) do
    case WorkingMemory.retrieve(@sources_key, user_id) do
      :not_found -> {:ok, %{}}
      {:ok, sources} -> {:ok, sources}
      error -> error
    end
  end
end
