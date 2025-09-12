defmodule StarweaveDev.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Add any workers or supervisors here
    ]

    opts = [strategy: :one_for_one, name: StarweaveDev.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
