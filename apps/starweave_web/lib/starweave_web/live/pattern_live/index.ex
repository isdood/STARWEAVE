defmodule StarweaveWeb.PatternLive.Index do
  @moduledoc """
  LiveView for real-time pattern recognition and learning.
  """
  use StarweaveWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: _live_action}} = socket) do
    # Connect to the pattern channel
    if connected?(socket) do
      case Phoenix.PubSub.subscribe(Starweave.PubSub, "pattern:lobby") do
        :ok -> :ok
        {:error, reason} -> Logger.error("Failed to subscribe to pattern:lobby: #{inspect(reason)}")
      end
    end

    # Initial welcome message
    welcome_message = %{
      id: System.unique_integer([:positive]),
      sender: "ai",
      text: "Welcome to STARWEAVE! I can help you recognize and learn patterns. Try sending me a message or a pattern to get started.",
      timestamp: DateTime.utc_now()
    }

    {:ok,
     socket
     |> assign(:page_title, "STARWEAVE")
     |> assign(:current_uri, %URI{path: "/"})
     |> assign(:messages, [welcome_message])
     |> assign(:is_typing, false)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when byte_size(message) > 0 do
    # Add user message
    user_message = %{
      id: System.unique_integer([:positive]),
      sender: "user",
      text: message,
      timestamp: DateTime.utc_now()
    }

    # Show typing indicator
    send(self(), {:typing_started})

    # Process the message via LLM
    send(self(), {:llm_chat, message})

    {:noreply, assign(socket, messages: socket.assigns.messages ++ [user_message])}
  end

  def handle_event("send_message", _params, socket) do
    # Empty message, do nothing
    {:noreply, socket}
  end
  
  def handle_event("learn", %{"pattern" => _pattern, "label" => _label}, socket) do
    # Push the pattern and label to the channel for learning
    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing_started}, socket) do
    {:noreply, assign(socket, :is_typing, true)}
  end

  def handle_info({:typing_stopped}, socket) do
    {:noreply, assign(socket, :is_typing, false)}
  end

  def handle_info({:llm_chat, message}, socket) do
    reply =
      case StarweaveLlm.OllamaClient.chat(message) do
        {:ok, content} -> content
        {:error, reason} -> "[LLM error] #{inspect(reason)}"
      end

    ai_message = %{
      id: System.unique_integer([:positive]),
      sender: "ai",
      text: reply,
      timestamp: DateTime.utc_now()
    }

    send(self(), {:typing_stopped})
    {:noreply, assign(socket, messages: socket.assigns.messages ++ [ai_message])}
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
      <!-- Header -->
      <header class="hidden bg-darker-grey py-4 px-6 border-b border-light-grey shadow-sm">
        <div class="container mx-auto flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 rounded-full bg-gradient-to-br from-purple-highlight to-pastel-purple flex items-center justify-center text-white text-xl font-bold glow">
              <span aria-hidden="true">★</span>
            </div>
            <h1 class="text-xl font-bold text-white">STARWEAVE</h1>
          </div>
          <div class="flex items-center space-x-4">
            <button class="text-pastel-purple hover:text-purple-highlight transition-colors">
              <span aria-hidden="true">⚙</span>
            </button>
            <button class="text-pastel-purple hover:text-purple-highlight transition-colors">
              <span aria-hidden="true">🌙</span>
            </button>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="flex-1 container mx-auto px-4 py-6 flex flex-col">
        <!-- Welcome Message -->
        <div class="max-w-3xl mx-auto w-full mb-8 text-center">
          <div class="inline-block p-6 rounded-lg bg-dark-grey border border-light-grey animate-float">
            <h2 class="text-xl font-semibold mb-2 text-white">Hello, I'm STARWEAVE</h2>
            <p class="text-gray-300">Your AI companion for pattern recognition and learning. What would you like to explore today?</p>
          </div>
        </div>

        <!-- Chat Container -->
        <div class="flex-1 flex flex-col max-w-3xl w-full mx-auto">
          <!-- Messages -->
          <div class="message-container flex-1 overflow-y-auto mb-4 space-y-4 pr-2">
            <%= for message <- @messages do %>
              <%= if message.sender == "user" do %>
                <!-- User Message -->
                <div class="flex items-start justify-end">
                  <div class="message-bubble user">
                    <p><%= message.text %></p>
                  </div>
                </div>
              <% else %>
                <!-- AI Message -->
                <div class="flex items-start">
                  <div class="w-8 h-8 rounded-full bg-gradient-to-br from-purple-highlight to-pastel-purple flex-shrink-0 flex items-center justify-center text-white text-xs mr-3 mt-1 glow">
                    <span class="font-bold" aria-hidden="true">SW</span>
                  </div>
                  <div class="message-bubble ai">
                    <p><%= message.text %></p>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Typing Indicator -->
          <%= if @is_typing do %>
            <div class="flex items-start mb-4">
              <div class="w-8 h-8 rounded-full bg-gradient-to-br from-purple-highlight to-pastel-purple flex-shrink-0 flex items-center justify-center text-white text-xs mr-3 mt-1 glow">
                <span class="font-bold" aria-hidden="true">SW</span>
              </div>
              <div class="bg-dark-grey rounded-lg p-3">
                <div class="typing-indicator">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Input Area -->
          <div class="bg-darker-grey rounded-lg p-4 border border-light-grey shadow-sm">
            <form phx-submit="send_message" class="flex space-x-3">
              <div class="flex-1 relative">
                <input 
                  id="message-input"
                  type="text"
                  name="message"
                  value=""
                  placeholder="Message STARWEAVE..."
                  class="chat-input"
                  phx-hook="AutoResize"
                  autocomplete="off"
                />
              </div>
              <button 
                type="submit" 
                class="btn-primary w-12 h-12"
              >
                <span aria-hidden="true">➤</span>
              </button>
            </form>
            <p class="text-xs text-gray-400 mt-2 text-center">STARWEAVE may produce inaccurate information about patterns or concepts.</p>
          </div>
        </div>
      </main>

      <!-- Footer -->
      <footer class="hidden bg-darker-grey py-3 px-6 border-t border-light-grey">
        <div class="container mx-auto text-center text-gray-400 text-sm">
          <p> 2023 STARWEAVE AI • <span class="text-pastel-purple">v1.0.0</span></p>
        </div>
      </footer>
    </div>
    """
  end
end
