defmodule StarweaveCore.Autonomous.Toolbox.TestRunner do
  @moduledoc """
  Test execution and validation for autonomous tool creation.

  Runs the project's test suite and validates changes made by autonomous systems.
  """

  @project_root "/home/isdood/STARWEAVE"

  @doc """
  Runs the complete test suite and returns results.
  """
  def run_full_test_suite do
    run_mix_command(["test"], "Running full test suite")
  end

  @doc """
  Runs tests for a specific application or module.
  """
  def run_tests_for_module(module_name) do
    # Find test files for the module
    test_pattern = "**/*#{module_name}*test*.exs"

    case System.cmd("find", [@project_root, "-name", test_pattern]) do
      {output, 0} when output != "" ->
        test_files = output |> String.split("\n") |> Enum.reject(&(&1 == ""))
        run_specific_tests(test_files)
      _ ->
        {:error, "No test files found for module: #{module_name}"}
    end
  end

  @doc """
  Runs tests for specific files.
  """
  def run_tests_for_files(file_paths) do
    run_specific_tests(file_paths)
  end

  @doc """
  Validates that code compiles without errors.
  """
  def validate_compilation do
    run_mix_command(["compile"], "Validating compilation")
  end

  @doc """
  Checks code formatting.
  """
  def check_formatting do
    run_mix_command(["format", "--check-formatted"], "Checking code formatting")
  end

  @doc """
  Runs linter checks.
  """
  def run_linter do
    # Check if mix precommit is available
    case run_mix_command(["precommit"], "Running precommit checks") do
      {:ok, _} -> {:ok, "Precommit checks passed"}
      error -> error
    end
  end

  @doc """
  Performs a comprehensive validation of changes.
  """
  def validate_changes do
    results = %{
      compilation: validate_compilation(),
      formatting: check_formatting(),
      tests: run_full_test_suite(),
      linting: run_linter()
    }

    # Determine overall success
    all_passed = results
    |> Map.values()
    |> Enum.all?(fn
      {:ok, _} -> true
      _ -> false
    end)

    if all_passed do
      {:ok, "All validations passed", results}
    else
      {:error, "Some validations failed", results}
    end
  end

  # Private Functions

  defp run_mix_command(args, description) do
    Logger.info(description)

    case System.cmd("mix", args, cd: @project_root, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, parse_test_output(output)}
      {error_output, exit_code} ->
        {:error, "Command failed (exit code: #{exit_code})", parse_test_output(error_output)}
    end
  end

  defp run_specific_tests(test_files) do
    # Convert file paths to mix test patterns
    test_patterns = test_files
    |> Enum.map(fn path ->
      # Convert absolute path to relative test pattern
      relative_path = Path.relative_to(path, @project_root)
      "test/#{relative_path}"
    end)

    run_mix_command(["test" | test_patterns], "Running specific tests")
  end

  defp parse_test_output(output) do
    lines = String.split(output, "\n")

    %{
      raw_output: output,
      summary: extract_test_summary(lines),
      failed_tests: extract_failed_tests(lines),
      passed_tests: extract_passed_tests(lines)
    }
  end

  defp extract_test_summary(lines) do
    # Look for summary lines like "Finished in X seconds" or "XX tests, XX failures"
    summary_lines = lines
    |> Enum.filter(fn line ->
      String.match?(line, ~r/(Finished|tests?,|failures?|errors?)/i)
    end)

    summary_lines |> Enum.join(" ")
  end

  defp extract_failed_tests(lines) do
    # Extract lines that look like test failures
    failed_lines = lines
    |> Enum.filter(fn line ->
      String.match?(line, ~r/^\s*\*\s+test/) ||
      String.match?(line, ~r/Failure:|Error:/)
    end)

    failed_lines |> Enum.take(10)  # Limit to first 10 failures
  end

  defp extract_passed_tests(lines) do
    # Count passing tests (simplified)
    passing_lines = lines
    |> Enum.filter(fn line ->
      String.match?(line, ~r/\.\s*$/) &&  # Lines ending with just a dot
      !String.match?(line, ~r/(Failure|Error|exception)/i)
    end)

    length(passing_lines)
  end
end
