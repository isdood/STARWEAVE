defmodule StarweaveCore.Intelligence.ReasoningEngine do
  @moduledoc """
  Basic reasoning capabilities for STARWEAVE.
  Integrates with working memory and goal systems.
  """
  
  use GenServer
  
  alias StarweaveCore.Intelligence.WorkingMemory
  
  # Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @spec decide(any(), [any()]) :: {:ok, any()} | {:error, String.t()}
  def decide(context, options) do
    GenServer.call(__MODULE__, {:decide, context, options})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    {:ok, %{knowledge: %{}}}
  end
  
  @impl true
  def handle_call({:decide, _context, []}, _from, state) do
    {:reply, {:error, "No options"}, state}
  end
  
  def handle_call({:decide, context, options}, _from, state) do
    # Simple decision making based on first principles
    result = 
      options
      |> Enum.map(&{&1, score_option(&1, context, state)})
      |> Enum.max_by(fn {_opt, score} -> score end, fn -> nil end)
      
    case result do
      nil -> {:reply, {:error, "Decision failed"}, state}
      {chosen, _score} -> {:reply, {:ok, chosen}, state}
    end
  end
  
  # Private functions
  
  defp score_option(option, context, _state) do
    # Simple scoring based on option length and context match
    base_score = String.length(to_string(option)) / 100
    context_score = if String.contains?(to_string(context), to_string(option)), do: 0.5, else: 0
    base_score + context_score
  end
end
