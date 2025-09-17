defmodule StarweaveLlm.SelfKnowledge.CodeIndexer do
  @moduledoc """
  Handles scanning and indexing the codebase for the self-knowledge system.
  """

  require Logger
  alias StarweaveLlm.SelfKnowledge.KnowledgeBase
  alias StarweaveLlm.Embeddings.Supervisor, as: Embeddings

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
        entry = %{
          file_path: file_path,
          content: content,
          last_updated: :os.system_time(:second),
          size: byte_size(content),
          language: Path.extname(file_path) |> String.trim_leading("."),
          embedding: nil,
          embedding_status: :pending
        }
        
        case KnowledgeBase.put(knowledge_base, file_path, entry) do
          :ok ->
            Task.start_link(fn ->
              case generate_embedding(entry) do
                {:ok, embedding} ->
                  updated_entry = Map.merge(entry, %{
                    embedding: embedding,
                    embedding_status: :complete
                  })
                  case KnowledgeBase.put(knowledge_base, file_path, updated_entry) do
                    :ok -> :ok
                    error -> 
                      Logger.error("Failed to update entry with embedding for #{file_path}: #{inspect(error)}")
                  end
                {:error, reason} ->
                  Logger.error("Failed to generate embedding for #{file_path}: #{inspect(reason)}")
                  updated_entry = Map.put(entry, :embedding_status, :error)
                  case KnowledgeBase.put(knowledge_base, file_path, updated_entry) do
                    :ok -> :ok
                    error -> 
                      Logger.error("Failed to update entry with error status for #{file_path}: #{inspect(error)}")
                  end
              end
            end)
            :ok
            
          {:error, reason} ->
            Logger.error("Failed to store entry for #{file_path}: #{inspect(reason)}")
            {:error, :storage_failed}
            
          other ->
            Logger.error("Unexpected response from KnowledgeBase.put for #{file_path}: #{inspect(other)}")
            {:error, :unexpected_response}
        end
        
      {:error, reason} ->
        Logger.warning("Failed to read #{file_path}: #{inspect(reason)}")
        {:error, reason}
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
  
  defp generate_embedding(%{content: content} = _entry) when is_binary(content) do
    content = 
      content
      |> String.slice(0, 4_096)  # Limit to first 4K characters
      
    case Embeddings.embed_texts([content]) do
      {:ok, [embedding]} -> 
        {:ok, embedding}
      error -> 
        Logger.error("Embedding generation failed: #{inspect(error)}")
        error
    end
  end
  
  defp generate_embedding(_), do: {:error, :invalid_content}
end
