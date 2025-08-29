defmodule StarweaveWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Ensure required applications are started
    {:ok, _} = Application.ensure_all_started(:starweave_core)
    
    # Start Finch if not already started
    if !Process.whereis(Req.Finch) do
      {:ok, _} = Finch.start_link(name: Req.Finch)
    end

    # Only include DNSCluster in production by default
    dns_cluster =
      if Application.get_env(:starweave_web, :dns_cluster_enabled, false) do
        [{DNSCluster, query: Application.get_env(:starweave_web, :dns_cluster_query) || :ignore}]
      else
        []
      end

    children =
      [
        # Web application dependencies
        StarweaveWeb.Telemetry,
        {Phoenix.PubSub, name: Starweave.PubSub}
      ] ++
        dns_cluster ++
        [
          # Start the Endpoint (http/https)
          StarweaveWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StarweaveWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StarweaveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
