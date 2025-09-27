defmodule StarweaveCore.Autonomous.SystemIntegrator do
  @moduledoc """
  Integrates autonomous systems to create a cohesive self-evolving intelligence.

  This module coordinates between knowledge acquisition, self-modification,
  goal management, and pattern learning to create STARWEAVE's autonomous capabilities.
  """

  use GenServer
  require Logger

  alias StarweaveCore.Autonomous.{
    LearningOrchestrator,
    WebKnowledgeAcquirer,
    SelfModificationAgent
  }
  alias StarweaveCore.Intelligence.{GoalManager, PatternLearner, WorkingMemory}

  defmodule State do
    defstruct [
      integration_active: false,
      system_health: :unknown,
      last_integration_check: nil,
      autonomous_metrics: %{}
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts the integrated autonomous system.
  """
  def start_autonomous_system do
    GenServer.call(__MODULE__, :start_integration)
  end

  @doc """
  Gets the status of the integrated autonomous system.
  """
  def get_system_status do
    GenServer.call(__MODULE__, :get_system_status)
  end

  @doc """
  Triggers a comprehensive autonomous cycle.
  """
  def trigger_autonomous_cycle do
    GenServer.cast(__MODULE__, :trigger_autonomous_cycle)
  end

  # Server Callbacks

  def init(_opts) do
    Logger.info("Starting STARWEAVE Autonomous System Integrator")

    # Check if all required components are available
    components_available = check_component_availability()

    if components_available do
      # Start the integration
      send(self(), :start_integration)
    end

    {:ok, %State{}}
  end

  def handle_call(:start_integration, _from, state) do
    Logger.info("Starting autonomous system integration")

    integration_result = perform_system_integration()

    case integration_result do
      {:ok, _} ->
        updated_state = %{state |
          integration_active: true,
          system_health: :healthy,
          last_integration_check: DateTime.utc_now()
        }
        {:reply, {:ok, "Autonomous system integration started"}, updated_state}

      {:error, reason} ->
        updated_state = %{state |
          system_health: :degraded,
          last_integration_check: DateTime.utc_now()
        }
        {:reply, {:error, reason}, updated_state}
    end
  end

  def handle_call(:get_system_status, _from, state) do
    status = gather_comprehensive_status()
    {:reply, status, state}
  end

  def handle_cast(:trigger_autonomous_cycle, state) do
    Logger.info("Triggering comprehensive autonomous cycle")

    # Perform a full autonomous cycle
    cycle_result = perform_autonomous_cycle()

    # Update metrics
    updated_metrics = Map.merge(state.autonomous_metrics, %{
      last_cycle: DateTime.utc_now(),
      cycle_result: cycle_result
    })

    {:noreply, %{state | autonomous_metrics: updated_metrics}}
  end

  def handle_info(:start_integration, state) do
    case perform_system_integration() do
      {:ok, _} ->
        Logger.info("Autonomous system integration completed successfully")
        {:noreply, %{state | integration_active: true, system_health: :healthy}}

      {:error, reason} ->
        Logger.error("Autonomous system integration failed: #{reason}")
        {:noreply, %{state | system_health: :degraded}}
    end
  end

  def handle_info(:health_check, state) do
    # Perform periodic health checks
    health_status = perform_health_check()

    new_state = %{state |
      system_health: health_status,
      last_integration_check: DateTime.utc_now()
    }

    # Schedule next health check
    Process.send_after(self(), :health_check, :timer.minutes(5))

    # Every health check, also update learning cycle count in working memory
    # This ensures the metric is persisted and available
    try do
      current_cycles = get_learning_cycle_count()
      StarweaveCore.Intelligence.WorkingMemory.store(:autonomy, :learning_cycles, current_cycles)
    catch
      _ -> :ok
    end

    {:noreply, new_state}
  end

  # Private Functions

  defp check_component_availability do
    required_processes = [
      StarweaveCore.Autonomous.LearningOrchestrator,
      StarweaveCore.Autonomous.WebKnowledgeAcquirer,
      StarweaveCore.Autonomous.SelfModificationAgent
    ]

    Enum.all?(required_processes, fn process ->
      Process.whereis(process) != nil
    end)
  end

  defp perform_system_integration do
    try do
      # 1. Start knowledge acquisition
      WebKnowledgeAcquirer.start_link()

      # 2. Start self-modification system
      SelfModificationAgent.start_link()

      # 3. Start learning orchestrator
      LearningOrchestrator.start_link()

      # 4. Set up cross-component communication
      setup_component_communication()

      # 5. Schedule health checks
      Process.send_after(self(), :health_check, :timer.minutes(1))

      {:ok, "All autonomous components integrated successfully"}
    catch
      error ->
        Logger.error("Integration failed: #{inspect(error)}")
        {:error, "Component integration failed"}
    end
  end

  defp setup_component_communication do
    # Set up pub/sub for cross-component communication
    :ok
  end

  defp perform_autonomous_cycle do
    Logger.info("Starting comprehensive autonomous cycle")

    results = %{
      knowledge_acquisition: acquire_and_process_knowledge(),
      goal_analysis: analyze_and_update_goals(),
      self_modification: attempt_self_improvements(),
      pattern_learning: trigger_pattern_evolution(),
      system_optimization: optimize_system_performance()
    }

    # Log cycle completion
    Logger.info("Autonomous cycle completed: #{inspect(results)}")

    results
  end

  defp acquire_and_process_knowledge do
    try do
      # Trigger knowledge acquisition
      WebKnowledgeAcquirer.trigger_scraping()

      # Wait a bit for processing
      Process.sleep(5000)

      # Get results
      WebKnowledgeAcquirer.get_status()
    catch
      error ->
        Logger.error("Knowledge acquisition failed: #{inspect(error)}")
        {:error, "Knowledge acquisition failed"}
    end
  end

  defp analyze_and_update_goals do
    try do
      # Get current goals
      current_goals = GoalManager.list_goals()

      # Analyze goals for new opportunities
      analysis_results = current_goals
      |> Enum.map(fn goal ->
        SelfModificationAgent.analyze_goal(goal.description)
      end)

      # Update goals based on analysis
      updated_goals = update_goals_with_insights(current_goals, analysis_results)

      {:ok, %{
        goals_analyzed: length(current_goals),
        insights_found: count_insights(analysis_results),
        goals_updated: length(updated_goals)
      }}
    catch
      error ->
        Logger.error("Goal analysis failed: #{inspect(error)}")
        {:error, "Goal analysis failed"}
    end
  end

  defp attempt_self_improvements do
    try do
      # Look for improvement opportunities
      improvement_goals = identify_improvement_opportunities()

      # Attempt to create tools for these goals
      results = improvement_goals
      |> Enum.map(fn goal ->
        case SelfModificationAgent.create_tool_for_goal(goal.description) do
          {:ok, result} -> {:success, result}
          {:error, reason} -> {:failed, reason}
        end
      end)

      success_count = results |> Enum.count(fn {status, _} -> status == :success end)

      {:ok, %{
        improvement_goals: length(improvement_goals),
        tools_created: success_count,
        tools_failed: length(improvement_goals) - success_count
      }}
    catch
      error ->
        Logger.error("Self-improvement failed: #{inspect(error)}")
        {:error, "Self-improvement failed"}
    end
  end

  defp trigger_pattern_evolution do
    try do
      # Trigger pattern learning from recent activities
      PatternLearner.learn_from_event(%{
        type: :autonomous_cycle,
        timestamp: DateTime.utc_now(),
        trigger: :system_integration
      })

      # Get pattern statistics
      pattern_stats = get_pattern_statistics()

      {:ok, pattern_stats}
    catch
      error ->
        Logger.error("Pattern evolution failed: #{inspect(error)}")
        {:error, "Pattern evolution failed"}
    end
  end

  defp optimize_system_performance do
    try do
      # Analyze system performance
      performance_metrics = gather_performance_metrics()

      # Identify optimization opportunities
      optimizations = identify_optimizations(performance_metrics)

      # Apply safe optimizations
      applied_optimizations = apply_optimizations(optimizations)

      {:ok, %{
        metrics_analyzed: map_size(performance_metrics),
        optimizations_found: length(optimizations),
        optimizations_applied: length(applied_optimizations)
      }}
    catch
      error ->
        Logger.error("System optimization failed: #{inspect(error)}")
        {:error, "System optimization failed"}
    end
  end

  defp identify_improvement_opportunities do
    # Identify areas where autonomous tools could help
    [
      %{
        id: "memory_optimization",
        description: "Optimize memory usage and consolidation algorithms",
        priority: :medium
      },
      %{
        id: "pattern_efficiency",
        description: "Improve pattern matching and learning efficiency",
        priority: :high
      },
      %{
        id: "knowledge_integration",
        description: "Better integration of web-scraped knowledge with existing patterns",
        priority: :medium
      }
    ]
  end

  defp update_goals_with_insights(current_goals, analysis_results) do
    # Update existing goals based on new insights
    current_goals
  end

  defp count_insights(analysis_results) do
    analysis_results
    |> Enum.count(fn
      {:ok, _} -> true
      _ -> false
    end)
  end

  defp get_pattern_statistics do
    # Get current pattern statistics
    %{
      total_patterns: 0,  # Would get from PatternStore
      recent_patterns: 0,
      pattern_growth: 0
    }
  end

  defp gather_performance_metrics do
    # Gather system performance metrics
    %{
      memory_usage: get_memory_usage(),
      pattern_count: get_pattern_count(),
      goal_count: get_goal_count(),
      learning_cycles: get_learning_cycle_count()
    }
  end

  defp identify_optimizations(performance_metrics) do
    # Identify optimization opportunities based on metrics
    optimizations = []

    # Memory optimization
    if performance_metrics.memory_usage > 100_000_000 do  # 100MB
      optimizations = optimizations ++ ["memory_consolidation"]
    end

    # Pattern efficiency
    if performance_metrics.pattern_count > 1000 do
      optimizations = optimizations ++ ["pattern_indexing"]
    end

    optimizations
  end

  defp apply_optimizations(optimizations) do
    # Apply identified optimizations
    applied = []

    # This would actually apply optimizations
    # For now, just track what would be applied

    applied
  end

  # Helper functions (duplicated from other modules for reference)
  defp get_memory_usage do
    try do
      # Get total memory usage from Erlang VM
      memory = :erlang.memory(:total)
      # Add working memory entries count
      contexts = [:conversation, :environment, :goals, :patterns, :autonomy]
      working_memory_count =
        contexts
        |> Enum.map(fn context ->
          case StarweaveCore.Intelligence.WorkingMemory.get_context(context) do
            entries when is_list(entries) -> length(entries)
            _ -> 0
          end
        end)
        |> Enum.sum()

      # Return memory usage in bytes (VM memory + estimated working memory overhead)
      memory + (working_memory_count * 1000)  # Rough estimate: 1KB per entry
    catch
      _ -> 0
    end
  end

  defp get_pattern_count do
    try do
      case StarweaveCore.PatternStore.all() do
        patterns when is_list(patterns) -> length(patterns)
        _ -> 0
      end
    catch
      _ -> 0
    end
  end

  defp get_goal_count do
    try do
      StarweaveCore.Intelligence.GoalManager.list_goals()
      |> length()
    catch
      _ -> 0
    end
  end

  defp get_learning_cycle_count do
    try do
      # Get learning cycles completed from LearningOrchestrator
      case StarweaveCore.Autonomous.LearningOrchestrator.get_status() do
        %{learning_cycles_completed: count} when is_integer(count) -> count
        _ -> 0
      end
    catch
      _ -> 0
    end
  end

  defp gather_comprehensive_status do
    %{
      integration_active: true,
      system_health: :healthy,
      components: %{
        learning_orchestrator: component_status(LearningOrchestrator),
        web_knowledge_acquirer: component_status(WebKnowledgeAcquirer),
        self_modification_agent: component_status(SelfModificationAgent)
      },
      metrics: gather_performance_metrics(),
      last_cycle: DateTime.utc_now()
    }
  end

  defp component_status(component) do
    try do
      case Process.whereis(component) do
        nil -> :not_running
        _ -> :running
      end
    catch
      _ -> :error
    end
  end

  defp perform_health_check do
    # Perform basic health checks
    components_healthy = [
      component_status(LearningOrchestrator),
      component_status(WebKnowledgeAcquirer),
      component_status(SelfModificationAgent)
    ] |> Enum.all?(fn status -> status == :running end)

    if components_healthy do
      :healthy
    else
      :degraded
    end
  end
end
