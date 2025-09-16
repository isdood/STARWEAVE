defmodule StarweaveLlm.Telemetry do
  @moduledoc """
  Telemetry integration for the Starweave LLM application.
  
  This module handles telemetry events for monitoring and observability,
  including embedding generation, model loading, and system performance metrics.
  """
  
  require Logger
  
  @doc """
  Sets up the telemetry handlers for the application.
  """
  def setup do
    # Attach individual handlers instead of using attach_many
    :telemetry.attach(
      "starweave-model-load",
      [:model, :load],
      &handle_event/4,
      nil
    )
    
    :telemetry.attach(
      "starweave-model-load-error",
      [:model, :load_error],
      &handle_event/4,
      nil
    )
    
    :telemetry.attach(
      "starweave-embed",
      [:embed],
      &handle_event/4,
      nil
    )
    
    :telemetry.attach(
      "starweave-embed-complete",
      [:embed_complete],
      &handle_event/4,
      nil
    )
    
    :telemetry.attach(
      "starweave-embed-error",
      [:embed_error],
      &handle_event/4,
      nil
    )
    
    :ok
  end
  
  defp handle_event([:model, :load], %{count: _}, %{model: model}, _config) do
    Logger.info("Loading BERT model: #{model}")
  end
  
  defp handle_event([:model, :load_error], %{count: _}, %{model: model, reason: reason}, _config) do
    Logger.error("Failed to load BERT model #{model}: #{inspect(reason)}")
  end
  
  defp handle_event([:embed], %{count: count}, %{model: model, batch_size: batch_size}, _config) do
    Logger.debug("Generating embeddings for #{count} texts (batch size: #{batch_size}, model: #{model})")
  end
  
  defp handle_event(
    [:embed_complete],
    %{duration: duration, count: count},
    %{model: model},
    _config
  ) do
    duration_ms = div(duration, 1000)
    Logger.debug("Generated #{count} embeddings in #{duration_ms}ms (model: #{model})")
  end
  
  defp handle_event(
    [:embed_error],
    %{count: _},
    %{model: model, reason: reason},
    _config
  ) do
    Logger.error("Error generating embeddings (model: #{model}): #{inspect(reason)}")
  end
  
  # Catch-all handler for any other events
  defp handle_event(event, _measurements, _metadata, _config) do
    Logger.debug("Received telemetry event: #{inspect(event)}")
  end
  
  # Fallback for unhandled events
  defp handle_event(event, measurements, metadata, _config) do
    Logger.debug("Unhandled telemetry event: #{inspect(event)} - #{inspect(measurements)} - #{inspect(metadata)}")
  end
end
