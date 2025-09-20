defmodule StarweaveLlm.Prompt.Template do
  @moduledoc """
  Handles dynamic prompt generation and template management.
  Supports template versioning and variable interpolation.
  
  Templates are stored in the `priv/templates` directory with the following structure:
  ```
  priv/
    templates/
      chat/           # Chat-related templates
        system.md
        knowledge_base_query.md
      code/           # Code-related templates (TODO)
  ```
  """
  
  @type template_name :: atom() | String.t()
  @type template_namespace :: atom() | String.t()
  @type template_version :: String.t()
  @type variables :: map()
  
  @templates_dir :starweave_llm
                 |> :code.priv_dir()
                 |> Path.join("templates")
  
  @doc """
  Renders a prompt template with the given variables.
  
  ## Examples
      iex> template = "Hello, {{name}}!"
      iex> render(template, %{name: "Alice"})
      {:ok, "Hello, Alice!"}
  """
  @spec render(String.t(), variables()) :: {:ok, String.t()} | {:error, String.t()}
  def render(template, variables) when is_binary(template) and is_map(variables) do
    try do
      # Convert {{variable}} syntax to <%= @variable %> for EEx
      eex_template = 
        template
        |> String.replace(~r/\{\{\s*([^}]+)\s*\}\}/, "<%= @\\1 %>")
      
      # Convert variables map to keyword list for EEx, ensuring keys are atoms
      assigns = 
        variables 
        |> Map.to_list()
        |> Enum.map(fn {k, v} -> 
          case k do
            k when is_atom(k) -> {k, v}
            k when is_binary(k) -> {String.to_atom(k), v}
            _ -> {k, v}
          end
        end)
      
      # Check for missing variables before rendering
      required_vars = 
        Regex.scan(~r/\{\{\s*([^}]+)\s*\}\}/, template)
        |> Enum.map(fn [_, var] -> String.trim(var) |> String.to_atom() end)
        |> Enum.uniq()
      
      available_vars = MapSet.new(assigns |> Enum.map(fn {k, _} -> k end))
      missing_vars = MapSet.difference(MapSet.new(required_vars), available_vars)
      
      if MapSet.size(missing_vars) > 0 do
        missing_list = missing_vars |> MapSet.to_list() |> Enum.join(", ")
        {:error, "Missing required variables: #{missing_list}"}
      else
        result = EEx.eval_string(eex_template, assigns: assigns)
        {:ok, result}
      end
    rescue
      e in [KeyError] -> 
        {:error, "Missing required variable: #{Exception.message(e)}"}
      e -> 
        {:error, "Template rendering error: #{inspect(e)}"}
    end
  end
  
  @doc """
  Renders a template by name with the given variables.
  
  ## Examples
      iex> render_template(:system, %{})
      {:ok, "System prompt..."}
  """
  @spec render_template(template_name(), variables()) :: 
          {:ok, String.t()} | {:error, String.t()}
  def render_template(name, variables) when is_map(variables) do
    render_template(name, :default, variables)
  end
  
  @doc """
  Renders a template by name and version with the given variables.
  
  ## Examples
      iex> render_template(:system, %{}, "v1")
      {:ok, "System prompt v1..."}
  """
  @spec render_template(template_name(), variables(), template_version()) :: 
          {:ok, String.t()} | {:error, String.t()}
  def render_template(name, variables, version) when is_map(variables) and is_binary(version) do
    with {:ok, template} <- load_template(name, version) do
      render(template, variables)
    end
  end
  
  @doc """
  Loads a template by name and version.
  Templates are stored in the priv/templates directory.
  """
  @spec load_template(template_name(), template_version()) :: 
          {:ok, String.t()} | {:error, String.t()}
  def load_template(name, version) do
    # Try the chat directory first for chat templates (only for :default, :pattern_analysis, :memory_retrieval)
    if name in [:default, :pattern_analysis, :memory_retrieval] do
      template_path = 
        :starweave_llm
        |> :code.priv_dir()
        |> Path.join("templates/chat/#{version}.eex")
      
      case File.read(template_path) do
        {:ok, content} -> 
          {:ok, content}
        {:error, _} -> 
          # Fallback to the original path structure
          fallback_path = 
            :starweave_llm
            |> :code.priv_dir()
            |> Path.join("templates/#{name}/#{version}.eex")
          
          case File.read(fallback_path) do
            {:ok, content} -> 
              {:ok, content}
            {:error, reason} -> 
              {:error, "Failed to load template #{name} v#{version}: #{:file.format_error(reason)}"}
          end
      end
    else
      # For other templates, use the original path structure
      template_path = 
        :starweave_llm
        |> :code.priv_dir()
        |> Path.join("templates/#{name}/#{version}.eex")
      
      case File.read(template_path) do
        {:ok, content} -> 
          {:ok, content}
        {:error, reason} -> 
          {:error, "Failed to load template #{name} v#{version}: #{:file.format_error(reason)}"}
      end
    end
  end
  
  @doc """
  Loads a template by name and namespace.
  
  ## Examples
      iex> load_template(:system, :chat)
      {:ok, "You are STARWEAVE..."}
  """
  @spec load_template(template_name(), template_namespace()) :: 
          {:ok, String.t()} | {:error, String.t()}
  def load_template(name, namespace) when is_atom(name) do
    load_template(Atom.to_string(name), namespace)
  end
  
  def load_template(name, namespace) when is_binary(name) and is_atom(namespace) do
    load_template(name, Atom.to_string(namespace))
  end
  
  def load_template(name, namespace) when is_binary(name) and is_binary(namespace) do
    # First try the namespaced path
    template_path = Path.join([@templates_dir, namespace, "#{name}.md"])
    
    case File.read(template_path) do
      {:ok, content} -> 
        {:ok, content}
      {:error, _} -> 
        # Fall back to legacy path for backward compatibility
        load_legacy_template(name, "latest")
    end
  end
  
  # For backward compatibility
  defp load_legacy_template(name, version) when is_binary(name) do
    template_path = Path.join([@templates_dir, "#{name}.#{version}.eex"])
    
    case File.read(template_path) do
      {:ok, content} -> 
        {:ok, content}
      {:error, reason} -> 
        {:error, "Failed to load template #{name} v#{version}: #{:file.format_error(reason)}"}
    end
  end
  
  @doc """
  Renders a template by name and namespace with the given variables.
  
  ## Examples
      iex> render_template(:system, :chat, %{})
      {:ok, "You are STARWEAVE..."}
  """
  @spec render_template(template_name(), template_namespace(), variables()) :: 
          {:ok, String.t()} | {:error, String.t()}
  def render_template(name, namespace, variables) when (is_atom(namespace) or is_binary(namespace)) and is_map(variables) do
    with {:ok, template} <- load_template(name, namespace) do
      render(template, variables)
    end
  end
  
  @doc """
  Renders a template by name with the given variables using default namespace.
  
  ## Examples
      iex> render_template(:system, %{})
      {:ok, "System prompt..."}
  """
  @spec render_template(template_name(), variables()) :: 
          {:ok, String.t()} | {:error, String.t()}
  def render_template(name, variables) when is_map(variables) do
    with {:ok, template} <- load_template(name, :default) do
      render(template, variables)
    end
  end
  
  @doc """
  Validates a template for required variables.
  """
  @spec validate_template(String.t()) :: 
          {:ok, [String.t()]} | {:error, String.t()}
  def validate_template(template) when is_binary(template) do
    # Extract all {{variable}} patterns
    variables = 
      Regex.scan(~r/\{\{\s*([^}]+)\s*\}\}/, template)
      |> Enum.map(fn [_, var] -> String.trim(var) end)
      |> Enum.uniq()
    
    {:ok, variables}
  end
  
  @doc """
  Gets the current version of a template.
  """
  @spec get_latest_version(template_name()) :: {:ok, template_version()} | {:error, String.t()}
  def get_latest_version(template_name) do
    # Try the chat directory first for chat templates (only for :default, :pattern_analysis, :memory_retrieval)
    if template_name in [:default, :pattern_analysis, :memory_retrieval] do
      template_dir = 
        :starweave_llm
        |> :code.priv_dir()
        |> Path.join("templates/chat")
      
      case File.ls(template_dir) do
        {:ok, files} -> 
          case files do
            [] -> {:error, "No template versions found for #{template_name}"}
            _ -> 
              # Sort versions and return the latest one
              versions = 
                files
                |> Enum.map(&Path.rootname/1)
                |> Enum.sort()
              
              {:ok, hd(versions)}
          end
        {:error, _} -> 
          # Fallback to the original path structure
          fallback_dir = 
            :starweave_llm
            |> :code.priv_dir()
            |> Path.join("templates/#{template_name}")
          
          case File.ls(fallback_dir) do
            {:ok, files} -> 
              case files do
                [] -> {:error, "No template versions found for #{template_name}"}
                _ -> 
                  versions = 
                    files
                    |> Enum.map(&Path.rootname/1)
                    |> Enum.sort()
                  
                  {:ok, hd(versions)}
              end
            {:error, _} -> 
              {:error, "Template directory not found for #{template_name}"}
          end
      end
    else
      # For other templates, use the original path structure
      template_dir = 
        :starweave_llm
        |> :code.priv_dir()
        |> Path.join("templates/#{template_name}")
      
      case File.ls(template_dir) do
        {:ok, files} -> 
          case files do
            [] -> {:error, "No template versions found for #{template_name}"}
            _ -> 
              versions = 
                files
                |> Enum.map(&Path.rootname/1)
                |> Enum.sort()
              
              {:ok, hd(versions)}
          end
        {:error, _} -> 
          {:error, "Template directory not found for #{template_name}"}
      end
    end
  end
end
