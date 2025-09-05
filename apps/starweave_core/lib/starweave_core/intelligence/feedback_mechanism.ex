defmodule StarweaveCore.Intelligence.FeedbackMechanism do
  @moduledoc """
  Feedback mechanism system for STARWEAVE.
  
  This module handles different types of feedback (explicit, implicit, and environmental)
  and uses it to improve the system's performance and behavior.
  """
  
  use GenServer
  
  alias StarweaveCore.Intelligence.{WorkingMemory, PatternLearner, ReinforcementLearning}
  
  # Types
  @type feedback_type :: :explicit_rating | :implicit_behavior | :environmental
  @type feedback_value :: number() | boolean() | map()
  @type feedback_source :: :user | :system | :environment
  
  # Default parameters
  @default_feedback_ttl :timer.hours(24) * 30  # 30 days
  @max_feedback_items 10_000
  
  # Client API
  
  @doc """
  Starts the FeedbackMechanism.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Records feedback from any source.
  
  ## Parameters
    - `type`: The type of feedback (:explicit_rating, :implicit_behavior, :environmental)
    - `value`: The feedback value (number, boolean, or map with details)
    - `context`: Context about what the feedback is regarding
    - `source`: Where the feedback came from (:user, :system, :environment)
  """
  @spec record(feedback_type(), feedback_value(), map(), feedback_source()) :: :ok
  def record(type, value, context \\ %{}, source \\ :user) do
    feedback = %{
      id: generate_id(),
      type: type,
      value: value,
      context: context,
      source: source,
      timestamp: NaiveDateTime.utc_now(),
      processed: false
    }
    
    GenServer.cast(__MODULE__, {:record_feedback, feedback})
  end
  
  @doc """
  Gets recent feedback matching the given filters.
  """
  @spec get_feedback(keyword(), pos_integer()) :: [map()]
  def get_feedback(filters \\ [], limit \\ 100) do
    GenServer.call(__MODULE__, {:get_feedback, filters, limit})
  end
  
  @doc """
  Processes pending feedback to update system behavior.
  """
  @spec process_pending_feedback() :: {:ok, integer()}
  def process_pending_feedback do
    GenServer.call(__MODULE__, :process_pending_feedback)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Load feedback from working memory
    feedback_items = 
      case WorkingMemory.retrieve(:feedback, :items) do
        {:ok, saved_feedback} -> saved_feedback
        _ -> []
      end
    
    # Schedule periodic processing
    schedule_feedback_processing()
    
    {:ok, %{feedback_items: feedback_items}}
  end
  
  @impl true
  def handle_cast({:record_feedback, feedback}, state) do
    # Add new feedback and trim old items
    updated_items = 
      [feedback | state.feedback_items]
      |> Enum.take(@max_feedback_items)
      |> Enum.reject(&expired_feedback?/1)
    
    # Persist to working memory
    WorkingMemory.store(:feedback, :items, updated_items)
    
    {:noreply, %{state | feedback_items: updated_items}}
  end
  
  @impl true
  def handle_call({:get_feedback, filters, limit}, _from, state) do
    feedback = 
      state.feedback_items
      |> Enum.filter(fn item -> matches_filters?(item, filters) end)
      |> Enum.take(limit)
    
    {:reply, feedback, state}
  end
  
  @impl true
  def handle_call(:process_pending_feedback, _from, state) do
    # Find unprocessed feedback
    {to_process, processed} = 
      Enum.split_with(state.feedback_items, fn item -> not item.processed end)
    
    # Process each feedback item
    updated_items = 
      to_process
      |> Enum.map(&process_feedback_item/1)
      |> Enum.concat(processed)
      |> Enum.take(@max_feedback_items)
    
    # Persist changes
    WorkingMemory.store(:feedback, :items, updated_items)
    
    {:reply, {:ok, length(to_process)}, %{state | feedback_items: updated_items}}
  end
  
  @impl true
  def handle_info(:process_feedback, state) do
    # Process feedback periodically
    {:ok, _count} = process_pending_feedback()
    
    # Schedule next processing
    schedule_feedback_processing()
    
    {:noreply, state}
  end
  
  # Private functions
  
  defp schedule_feedback_processing do
    # Process feedback every 5 minutes
    Process.send_after(self(), :process_feedback, :timer.minutes(5))
  end
  
  defp expired_feedback?(feedback) do
    # Check if feedback is older than TTL
    age = NaiveDateTime.diff(NaiveDateTime.utc_now(), feedback.timestamp, :millisecond)
    age > @default_feedback_ttl
  end
  
  defp matches_filters?(item, filters) do
    Enum.all?(filters, fn
      {:type, value} -> item.type == value
      {:source, value} -> item.source == value
      {:processed, value} -> item.processed == value
      {:after, timestamp} -> NaiveDateTime.compare(item.timestamp, timestamp) in [:gt, :eq]
      {:before, timestamp} -> NaiveDateTime.compare(item.timestamp, timestamp) in [:lt, :eq]
      _ -> true
    end) && !expired_feedback?(item)
  end
  
  defp process_feedback_item(feedback) do
    # Apply different processing based on feedback type
    case feedback.type do
      :explicit_rating ->
        handle_explicit_rating(feedback)
      
      :implicit_behavior ->
        handle_implicit_behavior(feedback)
      
      :environmental ->
        handle_environmental_feedback(feedback)
      
      _ ->
        # Default processing for unknown types
        mark_processed(feedback)
    end
  end
  
  defp handle_explicit_rating(feedback) do
    # Example: User rated a response on a scale of 1-5
    case feedback.value do
      rating when is_number(rating) and rating >= 4 ->
        # Positive feedback - reinforce successful patterns
        reinforce_success(feedback.context)
      
      rating when is_number(rating) and rating <= 2 ->
        # Negative feedback - learn from mistakes
        learn_from_mistake(feedback.context)
      
      _ ->
        # Neutral or unknown rating
        :ok
    end
    
    mark_processed(feedback)
  end
  
  defp handle_implicit_behavior(feedback) do
    # Example: User ignored a suggestion or took a different action
    case feedback.value do
      :ignored_suggestion ->
        # Learn that this suggestion wasn't helpful in this context
        learn_from_ignored_suggestion(feedback.context)
      
      :took_alternative_action ->
        # Learn about preferred alternatives
        learn_from_alternative_action(feedback.context)
      
      _ ->
        :ok
    end
    
    mark_processed(feedback)
  end
  
  defp handle_environmental_feedback(feedback) do
    # Example: System performance metrics or error rates
    if feedback.value.error do
      # Handle errors or performance issues
      handle_system_error(feedback.value.error, feedback.context)
    end
    
    mark_processed(feedback)
  end
  
  defp reinforce_success(context) do
    # Update reinforcement learning with positive reward
    if context[:action] && context[:state] do
      ReinforcementLearning.learn(
        context.state,
        context.action,
        1.0,  # Positive reward
        context.next_state || context.state
      )
    end
    
    # Update pattern learner with successful pattern
    if context[:pattern] do
      PatternLearner.learn_from_event(Map.put(context, :outcome, :success))
    end
  end
  
  defp learn_from_mistake(context) do
    # Update reinforcement learning with negative reward
    if context[:action] && context[:state] do
      ReinforcementLearning.learn(
        context.state,
        context.action,
        -1.0,  # Negative reward
        context.next_state || context.state
      )
    end
    
    # Update pattern learner with unsuccessful pattern
    if context[:pattern] do
      PatternLearner.learn_from_event(Map.put(context, :outcome, :failure))
    end
  end
  
  defp learn_from_ignored_suggestion(context) do
    # Reduce confidence in this suggestion for similar contexts
    if context[:suggestion_type] && context[:context] do
      # This would be more sophisticated in a real implementation
      # Could update a decay factor or record the context where the suggestion was ignored
      :ok
    end
  end
  
  defp learn_from_alternative_action(context) do
    # Learn that an alternative action was preferred in this context
    if context[:preferred_action] && context[:original_action] do
      # Update the policy to prefer this action in similar contexts
      :ok
    end
  end
  
  defp handle_system_error(error, context) do
    # Log the error and potentially update system behavior
    # Could trigger alerts or automatic adjustments
    :error_logger.error_msg("System error: ~p (Context: ~p)", [error, context])
  end
  
  defp mark_processed(feedback) do
    Map.put(feedback, :processed, true)
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
end
