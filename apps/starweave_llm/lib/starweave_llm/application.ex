defmodule StarweaveLlm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # HTTP client pool for Req
      {Finch, name: Req.Finch}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StarweaveLlm.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
