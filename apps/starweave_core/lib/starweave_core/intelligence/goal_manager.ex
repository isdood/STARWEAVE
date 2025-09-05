defmodule StarweaveCore.Intelligence.GoalManager do
  @moduledoc """
  Goal management system for STARWEAVE.
  
  Manages goals, their priorities, and tracks progress.
  """
  
  use GenServer
  require Logger
  
  alias StarweaveCore.Intelligence.WorkingMemory
  
  @type goal_id :: String.t()
  @type status :: :pending | :in_progress | :completed | :failed | :abandoned
  @type priority :: :low | :medium | :high
  
  defmodule Goal do
    @moduledoc """
    Goal structure.
    """
    @type t :: %__MODULE__{
            id: goal_id(),
            description: String.t(),
            status: status(),
            priority: priority(),
            created_at: DateTime.t(),
            updated_at: DateTime.t(),
            metadata: map(),
            parent_goal_id: goal_id() | nil,
            subgoals: [goal_id()]
          }
    
    defstruct [
      :id,
      :description,
      :status,
      :priority,
      :created_at,
      :updated_at,
      :metadata,
      :parent_goal_id,
      subgoals: []
    ]
  end

  # Client API
  
  @doc """
  Starts the GoalManager.
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Creates a new goal.
  
  ## Parameters
    - `description`: Description of the goal
    - `opts`: Additional options
      - `:priority` - Priority of the goal (:low, :medium, :high)
      - `:metadata` - Additional metadata for the goal
      - `:parent_goal_id` - ID of the parent goal, if any
  """
  @spec create_goal(String.t(), keyword()) :: {:ok, Goal.t()} | {:error, String.t()}
  def create_goal(description, opts \\ []) when is_binary(description) do
    priority = Keyword.get(opts, :priority, :medium)
    metadata = Keyword.get(opts, :metadata, %{})
    parent_goal_id = Keyword.get(opts, :parent_goal_id)
    
    GenServer.call(__MODULE__, {:create_goal, description, priority, metadata, parent_goal_id})
  end
  
  @doc """
  Updates an existing goal's status.
  """
  @spec update_goal_status(goal_id(), status()) :: :ok | {:error, String.t()}
  def update_goal_status(goal_id, status) when status in [:pending, :in_progress, :completed, :failed, :abandoned] do
    GenServer.call(__MODULE__, {:update_goal_status, goal_id, status})
  end
  
  @doc """
  Retrieves a goal by ID.
  """
  @spec get_goal(goal_id()) :: {:ok, Goal.t()} | :not_found
  def get_goal(goal_id) do
    GenServer.call(__MODULE__, {:get_goal, goal_id})
  end
  
  @doc """
  Lists all goals, optionally filtered by status.
  """
  @spec list_goals(status() | nil) :: [Goal.t()]
  def list_goals(status \\ nil) do
    GenServer.call(__MODULE__, {:list_goals, status})
  end
  
  @doc """
  Gets the current highest priority goal that is not completed or failed.
  """
  @spec get_current_goal() :: {:ok, Goal.t()} | :no_goals
  def get_current_goal do
    GenServer.call(__MODULE__, :get_current_goal)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    # Load goals from working memory on startup
    goals = 
      case WorkingMemory.retrieve(:goals, :all) do
        {:ok, saved_goals} -> saved_goals
        _ -> %{}
      end
    
    {:ok, %{goals: goals}}
  end
  
  @impl true
  def handle_call({:create_goal, description, priority, metadata, parent_goal_id}, _from, state) do
    goal_id = generate_id()
    now = DateTime.utc_now()
    
    goal = %Goal{
      id: goal_id,
      description: description,
      status: :pending,
      priority: priority,
      created_at: now,
      updated_at: now,
      metadata: metadata,
      parent_goal_id: parent_goal_id
    }
    
    # If this is a subgoal, add it to the parent's subgoals
    updated_goals = 
      if parent_goal_id do
        case Map.get(state.goals, parent_goal_id) do
          nil -> 
            # Parent not found, create as top-level goal
            Map.put(state.goals, goal_id, goal)
            
          parent_goal ->
            # Add to parent's subgoals
            updated_parent = %{parent_goal | 
              subgoals: [goal_id | parent_goal.subgoals],
              updated_at: now
            }
            
            state.goals
            |> Map.put(goal_id, goal)
            |> Map.put(parent_goal_id, updated_parent)
        end
      else
        Map.put(state.goals, goal_id, goal)
      end
    
    # Persist to working memory
    WorkingMemory.store(:goals, :all, updated_goals)
    
    {:reply, {:ok, goal}, %{state | goals: updated_goals}}
  end
  
  def handle_call({:update_goal_status, goal_id, new_status}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil ->
        {:reply, {:error, "Goal not found"}, state}
        
      goal ->
        now = DateTime.utc_now()
        updated_goal = %{goal | status: new_status, updated_at: now}
        updated_goals = Map.put(state.goals, goal_id, updated_goal)
        
        # Persist to working memory
        WorkingMemory.store(:goals, :all, updated_goals)
        
        {:reply, :ok, %{state | goals: updated_goals}}
    end
  end
  
  def handle_call({:get_goal, goal_id}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil -> {:reply, :not_found, state}
      goal -> {:reply, {:ok, goal}, state}
    end
  end
  
  def handle_call({:list_goals, status}, _from, state) do
    goals = 
      state.goals
      |> Map.values()
      |> Enum.filter(fn 
        goal when is_nil(status) -> true
        goal -> goal.status == status
      end)
      
    {:reply, goals, state}
  end
  
  def handle_call(:get_current_goal, _from, state) do
    current_goal = 
      state.goals
      |> Map.values()
      |> Enum.filter(fn goal -> 
        goal.status in [:pending, :in_progress] 
      end)
      |> Enum.sort_by(fn goal ->
        # Sort by priority and then by creation time
        priority_score = case goal.priority do
          :high -> 3
          :medium -> 2
          :low -> 1
        end
        
        {priority_score, -DateTime.to_unix(goal.created_at)}
      end, :desc)
      |> List.first()
      
    if current_goal do
      {:reply, {:ok, current_goal}, state}
    else
      {:reply, :no_goals, state}
    end
  end
  
  # Private functions
  
  defp generate_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
