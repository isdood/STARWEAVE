defmodule StarweaveCore.Intelligence.ReinforcementLearning do
  @moduledoc """
  Reinforcement Learning integration for STARWEAVE.
  
  This module provides Q-learning capabilities to enable the system to learn
  from interactions and improve its decision-making over time.
  """
  
  use GenServer
  
  alias StarweaveCore.Intelligence.WorkingMemory
  
  # Default Q-learning parameters
  @default_learning_rate 0.1
  @default_discount_factor 0.9
  @default_exploration_rate 0.3
  @default_exploration_decay 0.999
  @min_exploration_rate 0.01
  
  # Client API
  
  @doc """
  Starts the Reinforcement Learning agent.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Chooses an action based on the current state using an ε-greedy policy.
  """
  @spec choose_action(String.t(), [String.t()]) :: String.t()
  def choose_action(state, possible_actions) do
    GenServer.call(__MODULE__, {:choose_action, state, possible_actions})
  end
  
  @doc """
  Updates the Q-values based on the observed reward.
  """
  @spec learn(String.t(), String.t(), float(), String.t()) :: :ok
  def learn(state, action, reward, next_state) do
    GenServer.cast(__MODULE__, {:learn, state, action, reward, next_state})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Load Q-values from working memory or initialize empty
    q_values = 
      case WorkingMemory.retrieve(:rl, :q_values) do
        {:ok, saved_q} -> saved_q
        _ -> %{}
      end
    
    # Load or initialize exploration rate
    exploration_rate = 
      case WorkingMemory.retrieve(:rl, :exploration_rate) do
        {:ok, rate} -> rate
        _ -> @default_exploration_rate
      end
    
    {:ok, %{q_values: q_values, exploration_rate: exploration_rate}}
  end
  
  @impl true
  def handle_call({:choose_action, state, possible_actions}, _from, state_data) do
    %{q_values: q_values, exploration_rate: exploration_rate} = state_data
    
    # Exploration vs Exploitation
    action = 
      if :rand.uniform() < exploration_rate do
        # Explore: choose random action
        Enum.random(possible_actions)
      else
        # Exploit: choose best known action
        get_best_action(state, possible_actions, q_values)
      end
    
    {:reply, action, state_data}
  end
  
  @impl true
  def handle_cast({:learn, state, action, reward, next_state}, state_data) do
    %{q_values: q_values, exploration_rate: exploration_rate} = state_data
    
    # Get current Q-value for (state, action) pair
    current_q = get_in(q_values, [state, action]) || 0.0
    
    # Get maximum Q-value for next state
    max_next_q = 
      case q_values[next_state] do
        nil -> 0.0
        actions -> actions |> Map.values() |> Enum.max(fn -> 0.0 end)
      end
    
    # Q-learning formula
    new_q = current_q + @default_learning_rate * 
            (reward + @default_discount_factor * max_next_q - current_q)
    
    # Update Q-values
    updated_q_values = 
      q_values
      |> Map.put_new(state, %{})
      |> put_in([state, action], new_q)
    
    # Decay exploration rate
    new_exploration_rate = 
      max(@min_exploration_rate, exploration_rate * @default_exploration_decay)
    
    # Persist to working memory
    WorkingMemory.store(:rl, :q_values, updated_q_values)
    WorkingMemory.store(:rl, :exploration_rate, new_exploration_rate)
    
    {:noreply, %{q_values: updated_q_values, exploration_rate: new_exploration_rate}}
  end
  
  # Private functions
  
  defp get_best_action(state, possible_actions, q_values) do
    case q_values[state] do
      nil ->
        # If state is unknown, choose randomly
        Enum.random(possible_actions)
        
      actions_for_state ->
        # Find the action with the highest Q-value
        possible_actions
        |> Enum.map(fn action -> 
          {action, Map.get(actions_for_state, action, 0.0)}
        end)
        |> Enum.max_by(fn {_action, q_value} -> q_value end, fn -> 
          # If no Q-values for any action, choose randomly
          {Enum.random(possible_actions), 0.0}
        end)
        |> elem(0)
    end
  end
end
