defmodule StarweaveLlm.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Finch is started by starweave_web application

      # Start the Memory system
      {StarweaveLlm.Memory.Supervisor, []},

      # Start the Embeddings service
      {StarweaveLlm.Embeddings.Supervisor, []},

      # Start the Self-Knowledge system
      {StarweaveLlm.SelfKnowledge.Supervisor, []},
      
      # Start the LLM services
      {StarweaveLlm.LLM.Supervisor, []},
      
      # Start the Image Generation service
      {StarweaveLlm.ImageGeneration.Supervisor, []}
    ]

    # Start the Telemetry supervisor
    :ok = StarweaveLlm.Telemetry.setup()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StarweaveLlm.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _} = result ->
        Logger.info("StarweaveLlm application started successfully")
        result
      {:error, {:shutdown, {:failed_to_start_child, _, error}}} ->
        Logger.error("Failed to start StarweaveLlm application: #{inspect(error)}")
        {:error, error}
      error ->
        Logger.error("Failed to start StarweaveLlm application: #{inspect(error)}")
        error
    end
  end
end
