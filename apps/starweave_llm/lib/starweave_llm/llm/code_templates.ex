defmodule StarweaveLlm.LLM.CodeTemplates do
  @moduledoc """
  Handles code-related prompt templates for the LLM.
  Uses the template system for rendering with variables.
  """
  
  alias StarweaveLlm.Prompt.Template
  
  @doc """
  Generates a code explanation prompt.
  
  ## Parameters
    - `code`: The code to explain
    - `language`: The programming language of the code
    - `file_path`: Optional path to the file containing the code
    - `function_name`: Optional name of the function being explained
    - `context`: Optional additional context about the code
    - `explanation_points`: List of points to include in the explanation
    - `related_functions`: List of related function names
    - `see_also`: List of related resources or files
  """
  @spec explain_code(String.t(), String.t(), keyword()) :: String.t()
  def explain_code(code, language, opts \\ []) do
    variables = %{
      code: code,
      language: language,
      file_path: Keyword.get(opts, :file_path, ""),
      function_name: Keyword.get(opts, :function_name, ""),
      context: Keyword.get(opts, :context, ""),
      explanation_points: Keyword.get(opts, :explanation_points, []),
      related_functions: Keyword.get(opts, :related_functions, []),
      see_also: Keyword.get(opts, :see_also, [])
    }
    
    case Template.render_template("explanation", "code", variables) do
      {:ok, explanation} -> explanation
      _ -> default_code_explanation(code, language, opts)
    end
  end
  
  defp default_code_explanation(code, language, opts) do
    """
    # Code Explanation
    
    #{if file = Keyword.get(opts, :file_path), do: "## File: #{file}\n"}
    #{if func = Keyword.get(opts, :function_name), do: "## Function: #{func}\n"}
    
    ## Code
    ```#{language}
    #{code}
    ```
    
    ## Explanation
    #{if context = Keyword.get(opts, :context), do: "### Context\n#{context}\n\n"}
    ### What this code does:
    #{Enum.map_join(Keyword.get(opts, :explanation_points, ["Detailed explanation will be generated here"]), "\n", &("1. #{&1}"))}
    
    #{if related = Keyword.get(opts, :related_functions, []) do
        "### Related Functions:\n" <> Enum.map_join(related, "\n", &("- #{&1}"))
      end}
    
    #{if see_also = Keyword.get(opts, :see_also, []) do
        "### See Also:\n" <> Enum.map_join(see_also, "\n", &("- [#{&1}](#{&1})"))
      end}
    """
  end
end
