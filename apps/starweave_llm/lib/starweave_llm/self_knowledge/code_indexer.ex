defmodule StarweaveLLM.SelfKnowledge.CodeIndexer do
  @moduledoc """
  Handles scanning and indexing the codebase for the self-knowledge system.
  """

  require Logger
  alias StarweaveLLM.SelfKnowledge.KnowledgeBase

  @source_extensions [
    ".ex", 
    ".exs",
    ".heex",
    ".eex",
    ".leex"
  ]

  @ignored_dirs [
    "_build",
    "deps",
    "node_modules",
    "priv/static",
    "assets"
  ]

  @doc """
  Finds all source files in the project.
  """
  def find_source_files do
    root_dir = File.cwd!()
    
    files = 
      root_dir
      |> find_files_recursively()
      |> Enum.filter(&is_source_file?/1)
      |> Enum.reject(&ignored_file?/1)
    
    {:ok, files}
  end

  @doc """
  Indexes a list of files and stores them in the knowledge base.
  """
  def index_files(knowledge_base, files) do
    files
    |> Task.async_stream(
      &index_file(knowledge_base, &1),
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Stream.run()
    
    :ok
  end

  @doc """
  Checks if the codebase has changed since the last index.
  """
  def codebase_changed?(knowledge_base) do
    # This is a simplified implementation that checks file mtimes
    # In a real implementation, you'd want to track file hashes
    with {:ok, files} <- find_source_files(),
         {:ok, last_indexed} <- get_last_indexed(knowledge_base) do
      
      files
      |> Enum.any?(fn file -> 
        case File.stat(file, time: :posix) do
          {:ok, %{mtime: mtime}} -> 
            mtime > last_indexed
          _ -> 
            false
        end
      end)
    else
      _ -> true
    end
  end

  # Private functions

  defp index_file(knowledge_base, file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # In a real implementation, you'd want to parse the file
        # and extract meaningful chunks (functions, modules, etc.)
        # For now, we'll just index the whole file
        entry = %{
          file_path: file_path,
          content: content,
          last_updated: :os.system_time(:second),
          size: byte_size(content),
          language: Path.extname(file_path) |> String.trim_leading(".")
        }
        
        # Use the file path as the ID for now
        KnowledgeBase.put(knowledge_base, file_path, entry)
        
      {:error, reason} ->
        Logger.warning("Failed to read #{file_path}: #{inspect(reason)}")
    end
  end

  defp find_files_recursively(dir) do
    case File.dir?(dir) do
      true ->
        case File.ls(dir) do
          {:ok, entries} ->
            entries
            |> Enum.map(&Path.join(dir, &1))
            |> Enum.flat_map(fn path ->
              case File.dir?(path) do
                true -> find_files_recursively(path)
                false -> [path]
              end
            end)
          
          {:error, _reason} ->
            Logger.warning("Failed to list directory: #{dir}")
            []
        end
      
      false ->
        []
    end
  end

  defp is_source_file?(path) do
    ext = Path.extname(path)
    ext in @source_extensions
  end

  defp ignored_file?(path) do
    path_parts = Path.split(path)
    
    Enum.any?(@ignored_dirs, fn dir ->
      dir_parts = String.split(dir, "/")
      Enum.any?(0..(length(path_parts) - length(dir_parts)), fn i ->
        Enum.slice(path_parts, i, length(dir_parts)) == dir_parts
      end)
    end)
  end

  defp get_last_indexed(knowledge_base) do
    case KnowledgeBase.get(knowledge_base, "_last_indexed") do
      {:ok, %{last_updated: timestamp}} -> {:ok, timestamp}
      _ -> {:ok, 0}
    end
  end
end
