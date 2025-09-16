defmodule StarweaveLlm.Telemetry do
  @moduledoc """
  Telemetry integration for the Starweave LLM application.
  """
  
  require Logger
  
  @doc """
  Sets up the telemetry handlers.
  """
  def setup do
    :ok = :telemetry.attach(
      "starweave-llm-handler",
      [:starweave_llm, :event],
      &handle_event/4,
      nil
    )
    
    :ok
  end
  
  defp handle_event([:starweave_llm, :event], measurements, metadata, _config) do
    # For now, just log the event
    Logger.debug("Telemetry event: #{inspect(measurements)} - #{inspect(metadata)}")
  end
end
