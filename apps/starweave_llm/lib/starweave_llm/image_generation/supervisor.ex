defmodule StarweaveLlm.ImageGeneration.Supervisor do
  @moduledoc """
  Supervisor for the Image Generation client.
  """
  use Supervisor
  
  alias StarweaveLlm.ImageGeneration.Client
  
  @doc """
  Starts the image generation supervisor.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Child spec for the supervisor.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
  
  @impl true
  def init(_opts) do
    cfg = Application.get_env(:starweave_llm, :image_generation, [])
    children = [
      {Client, [
        host: Keyword.get(cfg, :host, "localhost"),
        port: Keyword.get(cfg, :port, 50051),
        enabled: Keyword.get(cfg, :enabled, true)
      ]}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
