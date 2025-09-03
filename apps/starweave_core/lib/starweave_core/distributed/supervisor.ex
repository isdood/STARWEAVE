defmodule StarweaveCore.Distributed.Supervisor do
  @moduledoc """
  Supervisor for distributed components with fault tolerance.
  """
  use Supervisor
  require Logger

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    # Configure supervisor flags for fault tolerance
    supervisor_flags = [
      strategy: :rest_for_one,
      max_restarts: 5,
      max_seconds: 10
    ]

    children = [
      # Core distributed components
      {StarweaveCore.Distributed.NodeDiscovery, [name: StarweaveCore.Distributed.NodeDiscovery]},
      {StarweaveCore.Distributed.TaskSupervisor, [name: StarweaveCore.Distributed.TaskSupervisor]},
      {StarweaveCore.Distributed.TaskDistributor, [name: StarweaveCore.Distributed.TaskDistributor]},
      {StarweaveCore.Distributed.PatternProcessor, [name: StarweaveCore.Distributed.PatternProcessor]}
    ]

    Supervisor.init(children, supervisor_flags)
  end
end
