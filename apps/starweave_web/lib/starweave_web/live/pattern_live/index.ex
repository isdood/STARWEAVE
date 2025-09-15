# lib/starweave_web/live/pattern/index.ex

defmodule StarweaveWeb.PatternLive.Index do
  @moduledoc """
  LiveView for real-time pattern recognition and learning.
  """
  use StarweaveWeb, :live_view
  require Logger

  alias StarweaveLLM.ContextManager
  alias StarweaveCore.Intelligence.WorkingMemory
  import StarweaveWeb.MarkdownHelper, only: [render_markdown: 1]

  @pattern_topic "pattern:lobby"
  @default_model "gpt-oss:20b"

  defp llm_model, do: System.get_env("OLLAMA_MODEL", @default_model)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      case Phoenix.PubSub.subscribe(Starweave.PubSub, @pattern_topic) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to subscribe to #{@pattern_topic}: #{inspect(reason)}")
      end
    end

    welcome_message = %{
      id: System.unique_integer([:positive]),
      sender: "ai",
      text: "Welcome to STARWEAVE! I can help you recognize and learn patterns. Try sending me a message or a pattern to get started.",
      timestamp: DateTime.utc_now()
    }

    {:ok,
     socket
     |> assign(
       page_title: "STARWEAVE",
       current_uri: %URI{path: "/"},
       messages: [welcome_message],
       is_typing: false,
       context_manager: ContextManager.new()
     )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when byte_size(message) > 0 do
    now = DateTime.utc_now()
    user_message = %{
      id: System.unique_integer([:positive]),
      sender: "user",
      text: message,
      timestamp: now
    }

    # Extract and store personal information
    case extract_personal_info(message) do
      {:name, name} ->
        # 30 days in milliseconds (1000 * 60 * 60 * 24 * 30)
        ttl = 2_592_000_000
        WorkingMemory.store(:user, :name, name, importance: 0.9, ttl: ttl)
        Logger.info("Stored user name in working memory: #{name}")
      _ ->
        :noop
    end

    # Store the message in working memory (24 hours in milliseconds)
    WorkingMemory.store(:conversation, "message_#{user_message.id}", user_message, 
      importance: 0.7, 
      ttl: 86_400_000
    )

    send(self(), {:typing_started})
    send(self(), {:llm_chat, message, socket.assigns.context_manager})

    {:noreply, update(socket, :messages, &(&1 ++ [user_message]))}
  end

  def handle_event("send_message", _, socket) do
    {:noreply, socket}
  end

  def handle_event("learn", %{"pattern" => _pattern, "label" => _label}, socket) do
    # Business logic for learning a pattern would go here.
    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing_started}, socket) do
    {:noreply, assign(socket, :is_typing, true)}
  end

  def handle_info({:typing_stopped}, socket) do
    {:noreply, assign(socket, :is_typing, false)}
  end

  def handle_info({:llm_chat, message, _context_manager}, socket) do
    case StarweaveLlm.OllamaClient.chat_with_context(
           message,
           nil,
           model: llm_model(),
           use_memory: true
         ) do
      {:ok, response} ->
        {:noreply, assign(socket, :llm_response, response)}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Error getting response: #{inspect(error)}")}
    end
  end

  defp extract_personal_info(message) do
    cond do
      # Match patterns like "my name is Caleb" or "I'm Caleb"
      name = Regex.named_captures(~r/(?:my name is|i[\s\']m|i am)\s+(?<name>[A-Za-z]+(?:\s+[A-Za-z]+)*)/i, message) |> get_in(["name"]) ->
        {:name, String.trim(name)}
      true ->
        :no_match
    end
  end

  def handle_info({:llm_chat, message, context_manager}, socket) do
    case StarweaveLlm.OllamaClient.chat_with_context(
           message,
           context_manager,
           model: llm_model(),
           use_memory: true
         ) do
      {:ok, reply, updated_context} ->
        now = DateTime.utc_now()
        ai_message = %{
          id: System.unique_integer([:positive]),
          sender: "ai",
          text: reply,
          timestamp: now
        }

        # Store AI response in working memory (24 hours in milliseconds)
        WorkingMemory.store(:conversation, "message_#{ai_message.id}", ai_message, 
          importance: 0.7, 
          ttl: 86_400_000
        )

        send(self(), {:typing_stopped})

        {:noreply,
         socket
         |> assign(messages: socket.assigns.messages ++ [ai_message])
         |> assign(:context_manager, updated_context)}

      {:error, _reason} ->
        error_message = %{
          id: System.unique_integer([:positive]),
          sender: "ai",
          text: "I'm having trouble connecting to my language model right now. This might be due to system resource limitations. You can still interact with me for pattern recognition features!",
          timestamp: DateTime.utc_now()
        }

        send(self(), {:typing_stopped})
        {:noreply, update(socket, :messages, &(&1 ++ [error_message]))}
    end
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply, update(socket, :messages, &(&1 ++ [message]))}
  end

  def handle_info(%{event: "pattern_recognized", payload: _payload}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{event: "pattern_learned", payload: _payload}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-darker-grey">
      <header class="hidden bg-darker-grey py-4 px-6 border-b border-light-grey shadow-sm">
        <!-- Header content from original file remains here -->
      </header>

      <main class="flex-1 container mx-auto px-4 py-6 flex flex-col">
        <div class="max-w-3xl mx-auto w-full mb-8 text-center">
          <div class="inline-block p-6 rounded-lg bg-dark-grey border border-light-grey animate-float">
            <h2 class="text-xl font-semibold mb-2 text-white">Hello, I'm STARWEAVE</h2>
            <p class="text-gray-300">
              Your AI companion for pattern recognition and learning. What would you like to explore today?
            </p>
          </div>
        </div>

        <div class="flex-1 flex flex-col max-w-3xl w-full mx-auto">
          <div id="message-container" class="message-container flex-1 overflow-y-auto mb-4 space-y-4 pr-2">
            <%= for message <- @messages do %>
              <div class={if message.sender == "user", do: "message-wrapper user", else: "message-wrapper ai"}>
                <%= if message.sender == "ai" do %>
                  <div class="avatar">
                    <img src="/images/wand.png" alt="Starweave" class="w-10 h-10" />
                  </div>
                <% end %>
                <div class="message-bubble">
                  <div class="prose prose-invert max-w-none">
                    {render_markdown(message.text)}
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @is_typing do %>
            <div class="message-wrapper ai">
              <div class="avatar">
                <img src="/images/wand.png" alt="Starweave" class="w-8 h-8" />
              </div>
              <div class="typing-indicator-bubble">
                <div class="typing-indicator">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            </div>
          <% end %>

          <div class="chat-input-area">
            <form phx-submit="send_message" class="chat-form">
              <div class="chat-input-container">
                <textarea
                  id="message-input"
                  name="message"
                  placeholder="Message STARWEAVE..."
                  class="chat-input"
                  phx-hook="AutoResize"
                  autocomplete="off"
                  rows="1"
                ></textarea>
                <button type="submit" class="send-button" aria-label="Send message">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M10.293 5.293a1 1 0 011.414 0l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414-1.414L12.586 11H5a1 1 0 110-2h7.586l-2.293-2.293a1 1 0 010-1.414z" clip-rule="evenodd" />
                  </svg>
                </button>
              </div>
            </form>
            <p class="disclaimer">
              STARWEAVE may produce inaccurate information about patterns or concepts.
            </p>
          </div>
        </div>
      </main>

      <footer class="hidden bg-darker-grey py-3 px-6 border-t border-light-grey">
        <!-- Footer content from original file remains here -->
      </footer>
    </div>
    """
  end
end
