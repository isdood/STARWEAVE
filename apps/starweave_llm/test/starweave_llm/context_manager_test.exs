defmodule StarweaveLLM.ContextManagerTest do
  use ExUnit.Case, async: true
  alias StarweaveLLM.ContextManager

  describe "new/1" do
    test "creates context manager with default settings" do
      context = ContextManager.new()
      
      assert context.max_tokens == 4000
      assert context.max_history == 20
      assert context.token_count == 0
      assert context.summary_cache == %{}
    end

    test "creates context manager with custom settings" do
      context = ContextManager.new(max_tokens: 2000, max_history: 10)
      
      assert context.max_tokens == 2000
      assert context.max_history == 10
      assert context.token_count == 0
    end
  end

  describe "add_message/3" do
    test "adds user message and updates token count" do
      context = ContextManager.new()
      message = "Hello, this is a test message with multiple words."
      
      updated_context = ContextManager.add_message(context, :user, message)
      
      assert length(updated_context.conversation.messages) == 1
      assert hd(updated_context.conversation.messages) == {:user, message}
      assert updated_context.token_count > 0
    end

    test "adds multiple messages and tracks token count" do
      context = ContextManager.new()
      
      context = context
        |> ContextManager.add_message(:user, "Hello")
        |> ContextManager.add_message(:assistant, "Hi there!")
        |> ContextManager.add_message(:user, "How are you?")
      
      assert length(context.conversation.messages) == 3
      assert context.token_count > 0
    end

    test "trims history when exceeding max_history" do
      context = ContextManager.new(max_history: 2)
      
      context = context
        |> ContextManager.add_message(:user, "Message 1")
        |> ContextManager.add_message(:assistant, "Response 1")
        |> ContextManager.add_message(:user, "Message 2")
        |> ContextManager.add_message(:assistant, "Response 2")
        |> ContextManager.add_message(:user, "Message 3")
      
      assert length(context.conversation.messages) == 2
      assert hd(context.conversation.messages) == {:assistant, "Response 2"}
    end
  end

  describe "get_context/1" do
    test "returns formatted conversation context" do
      context = ContextManager.new()
        |> ContextManager.add_message(:user, "Hello")
        |> ContextManager.add_message(:assistant, "Hi there!")
      
      context_str = ContextManager.get_context(context)
      
      assert context_str =~ "user: Hello"
      assert context_str =~ "assistant: Hi there!"
    end
  end

  describe "get_token_count/1" do
    test "returns current token count" do
      context = ContextManager.new()
        |> ContextManager.add_message(:user, "Hello world")
      
      token_count = ContextManager.get_token_count(context)
      assert token_count > 0
    end
  end

  describe "get_compressed_context/1" do
    test "returns normal context when under token limit" do
      context = ContextManager.new(max_tokens: 1000)
        |> ContextManager.add_message(:user, "Short message")
      
      compressed = ContextManager.get_compressed_context(context)
      normal = ContextManager.get_context(context)
      
      assert compressed == normal
    end

    test "returns compressed context when over token limit" do
      # Create a context with a very low token limit
      context = ContextManager.new(max_tokens: 10)
        |> ContextManager.add_message(:user, "This is a very long message that should exceed the token limit")
      
      compressed = ContextManager.get_compressed_context(context)
      
      assert compressed =~ "Conversation Summary"
      assert compressed =~ "compressed due to length"
    end
  end

  describe "estimate_tokens/1" do
    test "estimates tokens for short text" do
      tokens = ContextManager.estimate_tokens("Hello")
      assert tokens > 0
    end

    test "estimates tokens for long text" do
      long_text = String.duplicate("This is a test message. ", 100)
      tokens = ContextManager.estimate_tokens(long_text)
      assert tokens > 0
    end

    test "handles empty string" do
      tokens = ContextManager.estimate_tokens("")
      assert tokens == 0
    end
  end

  describe "clear/1" do
    test "clears conversation while preserving settings" do
      context = ContextManager.new(max_tokens: 2000, max_history: 10)
        |> ContextManager.add_message(:user, "Hello")
        |> ContextManager.add_message(:assistant, "Hi")
      
      cleared = ContextManager.clear(context)
      
      assert cleared.max_tokens == 2000
      assert cleared.max_history == 10
      assert length(cleared.conversation.messages) == 0
      assert cleared.token_count == 0
      assert cleared.summary_cache == %{}
    end
  end
end
