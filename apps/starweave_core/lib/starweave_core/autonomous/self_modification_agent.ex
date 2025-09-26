defmodule StarweaveCore.Autonomous.SelfModificationAgent do
  @moduledoc """
  Autonomous self-modification system for STARWEAVE.

  This agent can analyze goals, create tools to achieve them, and safely modify
  the codebase while maintaining system integrity and safety.
  """

  use GenServer
  require Logger

  alias StarweaveCore.Autonomous.Toolbox.{FileSystem, CodeSearch, TestRunner, LLM}
  alias StarweCore.Intelligence.GoalManager

  defmodule State do
    defstruct [
      active_tasks: [],
      completed_tasks: [],
      failed_tasks: [],
      safety_backups: [],
      modification_history: []
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a tool to help achieve a specific goal.
  """
  def create_tool_for_goal(goal_description, requirements \\ []) do
    GenServer.call(__MODULE__, {:create_tool, goal_description, requirements})
  end

  @doc """
  Analyzes a goal and determines what tools are needed.
  """
  def analyze_goal(goal_description) do
    GenServer.call(__MODULE__, {:analyze_goal, goal_description})
  end

  @doc """
  Gets the status of the self-modification system.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  def init(_opts) do
    Logger.info("Starting STARWEAVE Self-Modification Agent")

    {:ok, %State{}}
  end

  def handle_call({:create_tool, goal_description, requirements}, _from, state) do
    Logger.info("Creating tool for goal: #{goal_description}")

    result = execute_safe_modification(goal_description, requirements)

    case result do
      {:ok, task_result} ->
        updated_state = %{state |
          active_tasks: state.active_tasks ++ [task_result],
          modification_history: [task_result | state.modification_history] |> Enum.take(50)
        }
        {:reply, {:ok, task_result}, updated_state}

      {:error, reason} ->
        error_task = %{
          id: generate_task_id(),
          goal: goal_description,
          status: :failed,
          error: reason,
          timestamp: DateTime.utc_now()
        }

        updated_state = %{state |
          failed_tasks: [error_task | state.failed_tasks] |> Enum.take(20)
        }
        {:reply, {:error, reason}, updated_state}
    end
  end

  def handle_call({:analyze_goal, goal_description}, _from, state) do
    analysis = perform_goal_analysis(goal_description)
    {:reply, {:ok, analysis}, state}
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      active_tasks: length(state.active_tasks),
      completed_tasks: length(state.completed_tasks),
      failed_tasks: length(state.failed_tasks),
      recent_modifications: state.modification_history |> Enum.take(5)
    }
    {:reply, status, state}
  end

  # Private Functions

  defp execute_safe_modification(goal_description, requirements) do
    task_id = generate_task_id()

    # Step 1: Analyze the goal and determine what needs to be built
    with {:ok, analysis} <- perform_goal_analysis(goal_description),
         {:ok, tool_spec} <- generate_tool_specification(analysis, requirements),
         {:ok, code} <- generate_tool_code(tool_spec),
         {:ok, validation} <- validate_tool_code(code, tool_spec),
         {:ok, backup_path} <- create_safety_backup(tool_spec.target_file),
         {:ok, _} <- write_tool_code(tool_spec.target_file, code),
         {:ok, test_results} <- run_safety_tests(tool_spec),
         {:ok, _} <- verify_system_integrity() do

      # Success - record the completed task
      completed_task = %{
        id: task_id,
        goal: goal_description,
        tool_created: tool_spec.tool_name,
        file_modified: tool_spec.target_file,
        backup_path: backup_path,
        test_results: test_results,
        timestamp: DateTime.utc_now()
      }

      {:ok, completed_task}

    else
      {:error, reason} ->
        Logger.error("Self-modification failed: #{reason}")
        {:error, reason}
    end
  end

  defp perform_goal_analysis(goal_description) do
    # Use LLM to analyze what kind of tool is needed
    prompt = """
    Analyze this goal and determine what kind of autonomous tool or modification is needed:

    GOAL: #{goal_description}

    Consider:
    1. What specific functionality is needed?
    2. What type of module or tool would best achieve this?
    3. What existing STARWEAVE components could be leveraged?
    4. What new capabilities need to be created?

    Provide a structured analysis.
    """

    case StarweaveLlm.OllamaClient.generate_completion(prompt) do
      {:ok, response} ->
        analysis = parse_goal_analysis(response)
        {:ok, analysis}
      {:error, reason} ->
        {:error, "Goal analysis failed: #{reason}"}
    end
  end

  defp generate_tool_specification(analysis, requirements) do
    # Generate a specification for the tool to be created
    tool_name = generate_tool_name(analysis.functionality)
    target_file = determine_target_file(tool_name)

    spec = %{
      tool_name: tool_name,
      target_file: target_file,
      functionality: analysis.functionality,
      requirements: requirements,
      dependencies: analysis.dependencies,
      integration_points: analysis.integration_points
    }

    {:ok, spec}
  end

  defp generate_tool_code(tool_spec) do
    # Use LLM to generate the actual code
    description = """
    Create an autonomous tool for: #{tool_spec.functionality}

    This tool should integrate with STARWEAVE's existing architecture and help achieve:
    #{tool_spec.requirements |> Enum.join(", ")}

    The tool should be safe, well-tested, and follow Elixir best practices.
    """

    context = %{
      existing_modules: find_similar_modules(tool_spec.functionality),
      dependencies: tool_spec.dependencies,
      integration_requirements: tool_spec.integration_points
    }

    LLM.generate_code(description, tool_spec.requirements, context)
  end

  defp validate_tool_code(code, tool_spec) do
    # Validate the generated code
    validation = LLM.validate_generated_code(code, tool_spec.requirements)

    case validation do
      %{meets_requirements: true, security_concerns: false} ->
        # Also run static analysis
        static_check = perform_static_analysis(code)

        if static_check == :ok do
          {:ok, validation}
        else
          {:error, "Static analysis failed: #{static_check}"}
        end

      _ ->
        {:error, "Code validation failed: #{validation.details}"}
    end
  end

  defp create_safety_backup(target_file) do
    FileSystem.create_backup(target_file)
  end

  defp write_tool_code(target_file, code) do
    FileSystem.write_file(target_file, code)
  end

  defp run_safety_tests(tool_spec) do
    # Run tests to ensure the new tool doesn't break anything
    TestRunner.validate_changes()
  end

  defp verify_system_integrity do
    # Final check that the system is still working
    try do
      # Try to compile and run basic checks
      TestRunner.validate_compilation()
    catch
      _ -> {:error, "System integrity check failed"}
    end
  end

  # Helper Functions

  defp generate_task_id do
    "task_#{DateTime.utc_now() |> DateTime.to_unix()}_#{:rand.uniform(1000)}"
  end

  defp generate_tool_name(functionality) do
    # Generate a reasonable module name from functionality description
    functionality
    |> String.downcase()
    |> String.replace(~r/[^a-z\s]/, "")
    |> String.split()
    |> Enum.take(3)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
    |> then(fn name -> "StarweaveCore.Autonomous.Tools.#{name}" end)
  end

  defp determine_target_file(tool_name) do
    # Determine where to place the new tool
    module_parts = String.split(tool_name, ".")
    file_name = List.last(module_parts) <> ".ex"
    path_parts = ["apps", "starweave_core", "lib" | module_parts] ++ [file_name]

    Path.join(path_parts)
  end

  defp find_similar_modules(functionality) do
    # Find existing modules that might be similar
    keywords = extract_keywords(functionality)

    # This would search the codebase for similar functionality
    # For now, return some common STARWEAVE modules
    [
      "StarweaveCore.Intelligence.WorkingMemory",
      "StarweaveCore.Intelligence.PatternLearner",
      "StarweaveLlm.ContextManager"
    ]
  end

  defp extract_keywords(description) do
    description
    |> String.downcase()
    |> String.split(~r/[^a-zA-Z0-9]+/)
    |> Enum.filter(fn word -> String.length(word) > 3 end)
    |> Enum.take(5)
  end

  defp parse_goal_analysis(response) do
    # Parse the LLM response for goal analysis
    %{
      functionality: extract_section(response, "Functionality|Purpose"),
      dependencies: extract_list_section(response, "Dependencies"),
      integration_points: extract_list_section(response, "Integration"),
      complexity: estimate_complexity(response)
    }
  end

  defp extract_section(text, section_name) do
    regex = Regex.compile!("(?i)#{section_name}[:\\s]*\\n(.*?)(?=\\n\\n|\\n[A-Z]|$)", "s")

    case Regex.run(regex, text) do
      [_, content] -> String.trim(content)
      nil -> ""
    end
  end

  defp extract_list_section(text, section_name) do
    section_content = extract_section(text, section_name)

    section_content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp estimate_complexity(response) do
    # Simple complexity estimation based on response length and keywords
    word_count = response |> String.split() |> length()

    cond do
      word_count > 500 -> :high
      word_count > 200 -> :medium
      true -> :low
    end
  end

  defp perform_static_analysis(code) do
    # Basic static analysis checks
    checks = [
      fn -> check_syntax(code) end,
      fn -> check_security_patterns(code) end,
      fn -> check_performance_patterns(code) end
    ]

    results = Enum.map(checks, fn check -> check.() end)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, "Static analysis issues found"}
    end
  end

  defp check_syntax(code) do
    # This would use Elixir's Code module for syntax checking
    # For now, just check basic patterns
    if String.match?(code, ~r/defmodule\s+\w+/) do
      :ok
    else
      {:error, "Invalid module syntax"}
    end
  end

  defp check_security_patterns(code) do
    # Check for common security issues
    dangerous_patterns = [
      "System.cmd",
      "File.rm",
      "Code.eval",
      "String.to_atom"
    ]

    has_dangerous_patterns = dangerous_patterns
    |> Enum.any?(fn pattern -> String.contains?(code, pattern) end)

    if has_dangerous_patterns do
      {:error, "Potentially unsafe code patterns detected"}
    else
      :ok
    end
  end

  defp check_performance_patterns(code) do
    # Check for performance anti-patterns
    # This is simplified - real implementation would be more sophisticated
    :ok
  end
end
