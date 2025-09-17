defmodule StarweaveLlm.LLM.Supervisor do
  @moduledoc """
  Supervisor for LLM-related processes.
  """
  use Supervisor

  @doc """
  Starts the LLM supervisor.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      # Add other LLM-related workers here
      # e.g., {StarweaveLlm.LLM.QueryService, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
