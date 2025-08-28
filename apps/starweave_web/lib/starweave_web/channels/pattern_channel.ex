defmodule StarweaveWeb.PatternChannel do
  use Phoenix.Channel
  require Logger
  alias StarweaveWeb.GRPC.PatternClient
  alias Starweave.PatternResponse

  @moduledoc """
  Handles real-time pattern recognition and processing via WebSockets.
  Integrates with the gRPC Pattern Recognition Service.
  """

  @impl true
  def join("pattern:lobby", _payload, socket) do
    Logger.info("User joined pattern lobby")
    
    # Verify gRPC server connection on join
    case PatternClient.get_status() do
      {:ok, %Starweave.StatusResponse{status: "SERVING"}} ->
        Logger.info("gRPC server is ready")
        {:ok, socket}
      {:ok, %Starweave.StatusResponse{status: other}} ->
        Logger.error("gRPC server not ready, status: #{inspect(other)}")
        {:error, %{reason: "gRPC service unavailable"}}
      error ->
        Logger.error("Failed to connect to gRPC server: #{inspect(error)}")
        {:error, %{reason: "gRPC service unavailable"}}
    end
  end

  @doc """
  Handles pattern recognition requests by forwarding them to the gRPC service.
  """
  @impl true
  def handle_in("recognize", %{"pattern" => pattern} = payload, socket) do
    Logger.debug("Received pattern recognition request: #{inspect(pattern)}")
    
    # Prepare the pattern data for the gRPC request
    pattern_data = %{
      id: payload["id"] || "",
      data: pattern,
      metadata: Map.get(payload, "metadata", %{})
    }
    
    # Call the gRPC service
    case PatternClient.recognize_pattern(pattern_data) do
      {:ok, %PatternResponse{confidences: confidences, labels: labels, metadata: metadata, request_id: request_id}} ->
        # Convert gRPC response to a map for JSON serialization
        response_data = %{
          request_id: request_id,
          pattern: pattern,
          labels: labels,
          confidences: confidences,
          metadata: metadata
        }
        
        # Broadcast the response to all subscribers
        broadcast(socket, "pattern_recognized", response_data)
        
        # Send response to the requester
        {:reply, {:ok, response_data}, socket}
        
      {:error, reason} ->
        Logger.error("Pattern recognition failed: #{inspect(reason)}")
        {:reply, {:error, %{reason: "Pattern recognition failed: #{inspect(reason)}"}}, socket}
    end
  end

  @impl true
  def handle_in("learn", %{"pattern" => pattern, "label" => label} = payload, socket) do
    Logger.debug("Learning pattern: #{label} - #{inspect(pattern)}")
    
    # Prepare the pattern data for the gRPC request
    pattern_data = %{
      id: payload["id"] || "",
      data: pattern,
      label: label,
      metadata: Map.get(payload, "metadata", %{})
    }
    
    # Placeholder: reuse recognize call until LearnPattern RPC is added
    case PatternClient.recognize_pattern(pattern_data) do
      {:ok, %PatternResponse{request_id: request_id, metadata: metadata}} ->
        # Convert response to a map for JSON serialization
        response_data = %{
          status: :learned,
          request_id: request_id,
          pattern: pattern,
          label: label,
          timestamp: DateTime.utc_now(),
          metadata: metadata
        }
        
        # Broadcast the learned pattern to all subscribers
        broadcast(socket, "pattern_learned", response_data)
        
        # Send response to the requester
        {:reply, {:ok, response_data}, socket}
        
      {:error, reason} ->
        Logger.error("Pattern learning failed: #{inspect(reason)}")
        {:reply, {:error, %{reason: "Pattern learning failed: #{inspect(reason)}"}}, socket}
    end
  end

  @impl true
  def handle_in("ping", payload, socket) do
    reply = %{
      message: "pong",
      echo: payload,
      server_time_ms: System.system_time(:millisecond)
    }
    {:reply, {:ok, reply}, socket}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("Unhandled event: #{event} with payload: #{inspect(payload, pretty: true)}")
    {:noreply, socket}
  end
end
