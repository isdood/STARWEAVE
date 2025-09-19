defmodule StarweaveLlm.ContextManager.Conversation do
  @moduledoc """
  Manages the conversation state and message history.
  """
  
  @type role :: :user | :assistant | :system
  @type message_id :: String.t()
  @type message :: {role(), String.t(), message_id() | nil}
  
  @type t :: %__MODULE__{
    messages: list(message())
  }
  
  defstruct messages: []
  
  @doc """
  Generates a unique message ID.
  """
  @spec generate_message_id() :: message_id()
  def generate_message_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Creates a new conversation.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}
  
  @doc """
  Adds a message to the conversation.
  """
  @spec add_message(t(), role(), String.t(), message_id() | nil) :: {t(), message_id()}
  def add_message(conversation, role, content, message_id \\ nil) when role in [:user, :assistant, :system] do
    message_id = message_id || generate_message_id()
    updated = update_in(conversation.messages, &(&1 ++ [{role, content, message_id}]))
    {updated, message_id}
  end
  
  @doc """
  Gets all messages in the conversation.
  """
  @spec get_messages(t()) :: list(message())
  def get_messages(conversation) do
    conversation.messages
  end
  
  @doc """
  Gets the last N messages from the conversation.
  """
  @spec get_last_messages(t(), non_neg_integer()) :: list(message())
  def get_last_messages(conversation, n) do
    conversation.messages
    |> Enum.take(-n)
  end
  
  @doc """
  Gets a message by its ID.
  """
  @spec get_message(t(), message_id()) :: message() | nil
  def get_message(conversation, message_id) when is_binary(message_id) do
    Enum.find(conversation.messages, fn {_role, _content, id} -> id == message_id end)
  end
  
  @doc """
  Clears all messages from the conversation.
  """
  @spec clear(t()) :: t()
  def clear(conversation) do
    %{conversation | messages: []}
  end
end
