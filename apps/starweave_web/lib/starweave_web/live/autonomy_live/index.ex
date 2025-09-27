defmodule StarweaveWeb.AutonomyLive.Index do
  @moduledoc """
  LiveView for the STARWEAVE autonomy dashboard.

  Shows real-time autonomous system status, metrics, and activities.
  """

  use StarweaveWeb, :live_view
  require Logger
  import Timex, only: [format!: 2]

  alias StarweaveCore.Autonomous.{
    SystemIntegrator,
    LearningOrchestrator,
    WebKnowledgeAcquirer,
    SelfModificationAgent
  }

  def mount(_params, _session, socket) do
    Logger.info("Mounting autonomy dashboard")

    # Ensure WorkingMemory is initialized
    ensure_working_memory_initialized()

    # Start the autonomous system if not already running
    start_autonomous_system_if_needed()

    # Schedule periodic updates
    schedule_update()

    # Get initial data
    system_status = get_system_status()
    autonomy_status = get_autonomy_status()
    recent_activities = get_recent_activities()

    socket = assign(socket,
      system_status: system_status,
      autonomy_status: autonomy_status,
      recent_activities: recent_activities,
      show_details: false,
      last_update: DateTime.utc_now(),
      current_scope: :autonomy,
      page_title: "Autonomy Dashboard",
      current_uri: "/autonomy"  # Add current_uri for navigation highlighting
    )

    {:ok, socket}
  end

  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, show_details: !socket.assigns.show_details)}
  end

  def handle_event("trigger_learning_cycle", _params, socket) do
    LearningOrchestrator.trigger_learning_cycle()
    {:noreply, socket}
  end

  def handle_event("trigger_knowledge_acquisition", _params, socket) do
    WebKnowledgeAcquirer.trigger_scraping()
    {:noreply, socket}
  end

  def handle_event("trigger_autonomous_cycle", _params, socket) do
    SystemIntegrator.trigger_autonomous_cycle()
    {:noreply, socket}
  end

  def handle_info(:update_dashboard, socket) do
    # Schedule next update
    schedule_update()

    # Get fresh data
    system_status = get_system_status()
    autonomy_status = get_autonomy_status()
    recent_activities = get_recent_activities()

    socket = assign(socket,
      system_status: system_status,
      autonomy_status: autonomy_status,
      recent_activities: recent_activities,
      last_update: DateTime.utc_now()
    )

    {:noreply, socket}
  end

  def handle_info(:refresh, socket) do
    # Get fresh data
    system_status = get_system_status()
    autonomy_status = get_autonomy_status()
    recent_activities = get_recent_activities()

    socket = assign(socket,
      system_status: system_status,
      autonomy_status: autonomy_status,
      recent_activities: recent_activities,
      last_update: DateTime.utc_now()
    )

    # Schedule next update
    if connected?(socket) do
      Process.send_after(self(), :refresh, 30_000)  # Refresh every 30 seconds
    end

    {:noreply, socket}
  end

  # Helper Functions

  defp ensure_working_memory_initialized do
    try do
      # Try to start the WorkingMemory if it's not already running
      case Process.whereis(StarweaveCore.Intelligence.WorkingMemory) do
        nil ->
          # WorkingMemory is not running, try to start it
          StarweaveCore.Intelligence.WorkingMemory.start_link()
          Logger.info("Started WorkingMemory for autonomy dashboard")
        _pid ->
          # WorkingMemory is already running
          :ok
      end
    catch
      error ->
        Logger.warning("Could not ensure WorkingMemory is initialized: #{inspect(error)}")
    end
  end

  defp schedule_update do
    Process.send_after(self(), :update_dashboard, 5000)  # Update every 5 seconds
  end

  defp start_autonomous_system_if_needed do
    try do
      # Try to start the system integrator
      case SystemIntegrator.start_autonomous_system() do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.warning("Failed to start autonomous system: #{reason}")
      end
    catch
      error ->
        Logger.warning("Error starting autonomous system: #{inspect(error)}")
    end
  end

  defp get_system_status do
    try do
      SystemIntegrator.get_system_status()
    catch
      _ ->
        %{
          integration_active: false,
          system_health: :unknown,
          components: %{
            learning_orchestrator: :not_running,
            web_knowledge_acquirer: :not_running,
            self_modification_agent: :not_running
          },
          metrics: %{
            memory_usage: 0,
            pattern_count: 0,
            goal_count: 0,
            learning_cycles: 0
          }
        }
    end
  end

  defp get_autonomy_status do
    try do
      orchestrator_status = LearningOrchestrator.get_status()

      %{
        current_goals: [],  # Would get from GoalManager
        next_learning_cycle: remaining_time(orchestrator_status.next_learning_in),
        next_knowledge_acquisition: remaining_time(orchestrator_status.next_knowledge_in),
        next_self_reflection: remaining_time(orchestrator_status.next_reflection_in),
        learning_history: []  # Would get from history
      }
    catch
      _ ->
        %{
          current_goals: [],
          next_learning_cycle: "Unknown",
          next_knowledge_acquisition: "Unknown",
          next_self_reflection: "Unknown",
          learning_history: []
        }
    end
  end

  defp get_recent_activities do
    # Get recent autonomous activities
    # This would be implemented to track and retrieve recent activities
    [
      %{
        type: :autonomous_learning,
        description: "Completed pattern analysis and generated 5 new insights",
        timestamp: DateTime.utc_now() |> DateTime.add(-300),  # 5 minutes ago
        insights_generated: 5,
        patterns_analyzed: 23
      },
      %{
        type: :knowledge_acquisition,
        description: "Integrated 12 new knowledge sources from research papers",
        timestamp: DateTime.utc_now() |> DateTime.add(-1800),  # 30 minutes ago
        sources_processed: 12,
        patterns_created: 8
      },
      %{
        type: :self_reflection,
        description: "Analyzed system performance and identified 3 optimization opportunities",
        timestamp: DateTime.utc_now() |> DateTime.add(-3600),  # 1 hour ago
        optimizations_found: 3
      }
    ]
  end

  # Template Helper Functions

  @doc """
  Formats a timestamp as a relative time string.
  
  ## Examples
      iex> format_timestamp(DateTime.utc_now())
      "just now"
      
      iex> format_timestamp(DateTime.utc_now() |> DateTime.add(-65, :second))
      "1 minute ago"
  """
  def format_timestamp(%DateTime{} = timestamp) do
    try do
      Timex.format!(timestamp, "{relative}", :relative)
    rescue
      _e -> "recently"
    end
  end
  
  def format_timestamp(_), do: "unknown time"

  def format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m #{remaining_seconds}s"
      true -> "#{remaining_seconds}s"
    end
  end

  def format_duration("Unknown"), do: "Unknown"

  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{div(bytes, 1_000_000_000)}GB"
      bytes >= 1_000_000 -> "#{div(bytes, 1_000_000)}MB"
      bytes >= 1_000 -> "#{div(bytes, 1_000)}KB"
      true -> "#{bytes}B"
    end
  end

  def format_bytes(_), do: "0B"

  def get_priority_color(priority) do
    case priority do
      :high -> "bg-red-500/20 text-red-300"
      :medium -> "bg-yellow-500/20 text-yellow-300"
      :low -> "bg-green-500/20 text-green-300"
      _ -> "bg-gray-500/20 text-gray-300"
    end
  end

  def get_status_color(status) do
    case status do
      :active -> "bg-green-500/20 text-green-300"
      :pending -> "bg-yellow-500/20 text-yellow-300"
      :completed -> "bg-blue-500/20 text-blue-300"
      _ -> "bg-gray-500/20 text-gray-300"
    end
  end

  def get_health_color(health) do
    case health do
      :healthy -> "text-green-400"
      :degraded -> "text-yellow-400"
      :unhealthy -> "text-red-400"
      _ -> "text-gray-400"
    end
  end

  def get_component_status_color(status) do
    case status do
      :running -> "text-green-400"
      :not_running -> "text-red-400"
      :error -> "text-yellow-400"
      _ -> "text-gray-400"
    end
  end

  defp remaining_time(seconds) when is_integer(seconds) do
    seconds
  end

  defp remaining_time(_), do: 0
end
