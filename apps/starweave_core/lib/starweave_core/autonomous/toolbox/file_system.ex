defmodule StarweaveCore.Autonomous.Toolbox.FileSystem do
  @moduledoc """
  Safe file system operations for autonomous tool creation.

  Provides controlled access to file operations within the STARWEAVE project directory.
  """

  @project_root "/home/isdood/STARWEAVE"
  @allowed_extensions [".ex", ".exs", ".md", ".txt", ".json", ".yml", ".yaml"]
  @max_file_size 1024 * 1024  # 1MB limit

  @doc """
  Safely reads a file within the project directory.
  """
  def read_file(path) do
    safe_path = validate_and_sanitize_path(path)

    if File.exists?(safe_path) do
      case File.read(safe_path) do
        {:ok, content} ->
          if String.length(content) > @max_file_size do
            {:error, "File too large"}
          else
            {:ok, content}
          end
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "File not found"}
    end
  end

  @doc """
  Safely writes a file within the project directory.
  """
  def write_file(path, content) do
    safe_path = validate_and_sanitize_path(path)

    # Validate file extension
    if valid_extension?(safe_path) do
      # Create directory if it doesn't exist
      safe_path |> Path.dirname() |> File.mkdir_p!()

      case File.write(safe_path, content) do
        :ok -> {:ok, "File written successfully"}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Invalid file extension"}
    end
  end

  @doc """
  Lists files in a directory within the project.
  """
  def list_directory(path) do
    safe_path = validate_and_sanitize_path(path)

    if File.dir?(safe_path) do
      case File.ls(safe_path) do
        {:ok, files} -> {:ok, files}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Directory not found"}
    end
  end

  @doc """
  Creates a backup of a file before modification.
  """
  def create_backup(original_path) do
    safe_path = validate_and_sanitize_path(original_path)

    if File.exists?(safe_path) do
      backup_path = "#{safe_path}.backup.#{DateTime.utc_now() |> DateTime.to_unix()}"

      case File.copy(safe_path, backup_path) do
        {:ok, _} -> {:ok, backup_path}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Original file not found"}
    end
  end

  @doc """
  Validates and sanitizes file paths to prevent directory traversal attacks.
  """
  def validate_and_sanitize_path(path) do
    # Remove any path traversal attempts
    clean_path = path
    |> String.replace("..", "")
    |> String.replace(~r{/+} , "/")

    # Ensure path is within project directory
    Path.join(@project_root, clean_path)
    |> Path.expand()
    |> then(fn expanded_path ->
      if String.starts_with?(expanded_path, @project_root) do
        expanded_path
      else
        raise "Path traversal attempt detected"
      end
    end)
  end

  defp valid_extension?(path) do
    extension = Path.extname(path)
    extension in @allowed_extensions
  end
end
