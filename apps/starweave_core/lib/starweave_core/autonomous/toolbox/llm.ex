defmodule StarweaveCore.Autonomous.Toolbox.LLM do
  @moduledoc """
  LLM integration for autonomous tool creation and code generation.

  Provides safe access to language models for code analysis, generation, and validation.
  """

  alias StarweaveLlm.OllamaClient

  @doc """
  Generates code based on a description and requirements.
  """
  def generate_code(description, requirements \\ [], context \\ %{}) do
    prompt = build_code_generation_prompt(description, requirements, context)

    case OllamaClient.generate_completion(prompt) do
      {:ok, response} ->
        extract_code_from_response(response)
      {:error, reason} ->
        {:error, "LLM generation failed: #{reason}"}
    end
  end

  @doc """
  Analyzes existing code and suggests improvements.
  """
  def analyze_code(code, analysis_type \\ :general) do
    prompt = build_code_analysis_prompt(code, analysis_type)

    case OllamaClient.generate_completion(prompt) do
      {:ok, response} ->
        {:ok, parse_analysis_response(response)}
      {:error, reason} ->
        {:error, "Code analysis failed: #{reason}"}
    end
  end

  @doc """
  Validates generated code for safety and correctness.
  """
  def validate_generated_code(code, original_requirements) do
    validation_prompt = build_validation_prompt(code, original_requirements)

    case OllamaClient.generate_completion(validation_prompt) do
      {:ok, response} ->
        parse_validation_response(response)
      {:error, reason} ->
        {:error, "Code validation failed: #{reason}"}
    end
  end

  @doc """
  Generates tests for a given piece of code.
  """
  def generate_tests(code, module_name) do
    prompt = build_test_generation_prompt(code, module_name)

    case OllamaClient.generate_completion(prompt) do
      {:ok, response} ->
        extract_tests_from_response(response)
      {:error, reason} ->
        {:error, "Test generation failed: #{reason}"}
    end
  end

  @doc """
  Explains code functionality and patterns.
  """
  def explain_code(code) do
    prompt = """
    Please explain the following Elixir code in detail:

    #{code}

    Provide:
    1. What this code does
    2. Key functions and their purposes
    3. Important patterns or design decisions
    4. Potential improvements or considerations
    """

    case OllamaClient.generate_completion(prompt) do
      {:ok, response} ->
        {:ok, response}
      {:error, reason} ->
        {:error, "Code explanation failed: #{reason}"}
    end
  end

  # Private Functions

  defp build_code_generation_prompt(description, requirements, context) do
    base_prompt = """
    You are an expert Elixir developer creating autonomous tools for the STARWEAVE system.

    TASK: #{description}

    REQUIREMENTS:
    #{format_requirements(requirements)}

    CONTEXT:
    #{format_context(context)}

    Generate safe, well-structured Elixir code that:
    1. Follows Elixir conventions and best practices
    2. Includes proper error handling
    3. Has comprehensive documentation
    4. Is secure and prevents common vulnerabilities
    5. Integrates well with the existing STARWEAVE architecture

    Return only the Elixir code without markdown formatting or explanations.
    """

    base_prompt
  end

  defp build_code_analysis_prompt(code, analysis_type) do
    analysis_focus = case analysis_type do
      :security -> "security vulnerabilities and potential exploits"
      :performance -> "performance bottlenecks and optimization opportunities"
      :maintainability -> "code quality, readability, and maintainability issues"
      :general -> "overall code quality, potential issues, and improvements"
    end

    """
    Analyze the following Elixir code for #{analysis_focus}:

    #{code}

    Provide a detailed analysis including:
    1. Identified issues or concerns
    2. Potential improvements
    3. Security considerations
    4. Performance implications
    5. Code quality assessment

    Be specific and provide concrete suggestions.
    """
  end

  defp build_validation_prompt(code, original_requirements) do
    """
    Validate the following generated Elixir code against the original requirements:

    ORIGINAL REQUIREMENTS:
    #{format_requirements(original_requirements)}

    GENERATED CODE:
    #{code}

    Please evaluate:
    1. Does the code fulfill all requirements?
    2. Are there any security concerns?
    3. Is the code well-structured and maintainable?
    4. Are there any bugs or logical errors?
    5. Does it follow Elixir best practices?

    Provide a detailed validation report.
    """
  end

  defp build_test_generation_prompt(code, module_name) do
    """
    Generate comprehensive tests for the following Elixir code:

    MODULE: #{module_name}

    CODE:
    #{code}

    Generate tests that cover:
    1. All public functions
    2. Error conditions
    3. Edge cases
    4. Integration scenarios
    5. Mock external dependencies

    Use ExUnit testing framework and follow Elixir testing best practices.
    Include setup and teardown as needed.
    """
  end

  defp format_requirements(requirements) do
    requirements
    |> Enum.with_index(1)
    |> Enum.map(fn {req, i} -> "#{i}. #{req}" end)
    |> Enum.join("\n")
  end

  defp format_context(context) do
    context
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join("\n")
  end

  defp extract_code_from_response(response) do
    # Extract Elixir code from LLM response
    # This is a simplified implementation - in reality, you'd want more robust parsing

    code_block_regex = ~r/```elixir\s*\n(.*?)\n```/s

    case Regex.run(code_block_regex, response) do
      [_, code] ->
        {:ok, String.trim(code)}
      nil ->
        # Try to extract code without markdown formatting
        lines = String.split(response, "\n")
        code_lines = lines
        |> Enum.drop_while(fn line -> !String.match?(line, ~r/defmodule|def\s/) end)
        |> Enum.take_while(fn line -> !String.match?(line, ~r/^```|^~~~/) end)

        if Enum.any?(code_lines, fn line -> String.match?(line, ~r/defmodule|def\s/) end) do
          {:ok, Enum.join(code_lines, "\n")}
        else
          {:error, "No valid Elixir code found in response"}
        end
    end
  end

  defp extract_tests_from_response(response) do
    # Similar to extract_code_from_response but for test code
    extract_code_from_response(response)
  end

  defp parse_analysis_response(response) do
    # Parse structured analysis from LLM response
    %{
      issues: extract_section(response, "Issues|Problems|Concerns"),
      improvements: extract_section(response, "Improvements|Suggestions"),
      security: extract_section(response, "Security"),
      performance: extract_section(response, "Performance"),
      quality: extract_section(response, "Quality|Code Quality")
    }
  end

  defp parse_validation_response(response) do
    # Parse validation results
    meets_requirements = !String.match?(String.downcase(response), ~r/does not.*requirements|fail.*requirements/)
    has_security_concerns = String.match?(String.downcase(response), ~r/security.*concern|security.*issue|vulnerabilit/)
    is_well_structured = String.match?(String.downcase(response), ~r/well.*structured|good.*structure|maintainable/)

    %{
      meets_requirements: meets_requirements,
      security_concerns: has_security_concerns,
      well_structured: is_well_structured,
      details: response
    }
  end

  defp extract_section(text, section_name) do
    regex = Regex.compile!("(?i)#{section_name}[:\\s]*\\n(.*?)(?=\\n\\n|\\n[A-Z]|$)", "s")

    case Regex.run(regex, text) do
      [_, content] -> String.trim(content)
      nil -> ""
    end
  end
end
