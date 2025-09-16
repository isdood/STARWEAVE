defmodule StarweaveLlm.ContextManager.Conversation do
  @moduledoc """
  Manages the conversation state and message history.
  """
  
  @type t :: %__MODULE__{
    messages: list({:user | :assistant | :system, String.t()})
  }
  
  defstruct messages: []
  
  @doc """
  Creates a new conversation.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}
  
  @doc """
  Adds a message to the conversation.
  """
  @spec add_message(t(), :user | :assistant | :system, String.t()) :: t()
  def add_message(conversation, role, content) when role in [:user, :assistant, :system] do
    update_in(conversation.messages, &(&1 ++ [{role, content}]))
  end
  
  @doc """
  Gets all messages in the conversation.
  """
  @spec get_messages(t()) :: list({:user | :assistant | :system, String.t()})
  def get_messages(conversation) do
    conversation.messages
  end
  
  @doc """
  Gets the last N messages from the conversation.
  """
  @spec get_last_messages(t(), non_neg_integer()) :: list({:user | :assistant | :system, String.t()})
  def get_last_messages(conversation, n) do
    conversation.messages
    |> Enum.take(-n)
  end
  
  @doc """
  Clears all messages from the conversation.
  """
  @spec clear(t()) :: t()
  def clear(conversation) do
    %{conversation | messages: []}
  end
end
