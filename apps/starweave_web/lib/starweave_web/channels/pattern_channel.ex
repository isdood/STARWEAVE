defmodule StarweaveWeb.PatternChannel do
  use Phoenix.Channel
  require Logger

  @moduledoc """
  Handles real-time pattern recognition and processing via WebSockets.
  """

  @impl true
  def join("pattern:lobby", _payload, socket) do
    Logger.info("User joined pattern lobby")
    {:ok, socket}
  end

  @impl true
  def handle_in("recognize", %{"pattern" => pattern}, socket) do
    Logger.debug("Received pattern recognition request: #{inspect(pattern)}")
    
    # Simulate processing (will be replaced with actual pattern matching)
    response = %{
      pattern: pattern,
      confidence: :rand.uniform(),
      metadata: %{
        timestamp: DateTime.utc_now(),
        source: :starweave_web
      }
    }

    # Broadcast the response to all subscribers
    broadcast(socket, "pattern_recognized", response)
    
    # Send immediate response to the requester
    {:reply, {:ok, response}, socket}
  end

  @doc """
  Handles incoming pattern learning requests.
  """
  @impl true
  def handle_in("learn", %{"pattern" => pattern, "label" => label}, socket) do
    Logger.debug("Learning pattern: #{label} - #{inspect(pattern)}")
    
    # Simulate learning (will be replaced with actual learning logic)
    response = %{
      status: :learned,
      pattern: pattern,
      label: label,
      timestamp: DateTime.utc_now()
    }

    # Broadcast the learned pattern to all subscribers
    broadcast(socket, "pattern_learned", response)
    
    {:reply, {:ok, response}, socket}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("Unhandled event: #{event} with payload: #{inspect(payload, pretty: true)}")
    {:noreply, socket}
  end
end
