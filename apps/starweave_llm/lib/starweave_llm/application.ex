defmodule StarweaveLlm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Finch is started by starweave_web application
      
      # Start the Self-Knowledge system
      {StarweaveLLM.SelfKnowledge.Supervisor, []}
    ]

    # Start the Telemetry supervisor
    StarweaveLlm.Telemetry.setup()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StarweaveLlm.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
