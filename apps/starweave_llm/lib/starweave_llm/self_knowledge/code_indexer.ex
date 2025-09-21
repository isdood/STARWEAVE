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
    "assets",
    ".elixir_ls",
    "test",
    "tmp"
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
        # Parse the file content to extract structured information
        parsed_content = 
          case Path.extname(file_path) do
            ".ex" ->
              try do
                StarweaveLlm.SelfKnowledge.ElixirCodeParser.parse(content, file_path)
              rescue
                _ -> 
                  Logger.warning("Failed to parse #{file_path} with ElixirCodeParser")
                  %{content: content}
              end
            _ -> 
              %{content: content}
          end

        entry = %{
          file_path: file_path,
          content: content,
          parsed_content: parsed_content,
          last_updated: :os.system_time(:second),
          size: byte_size(content),
          language: Path.extname(file_path) |> String.trim_leading("."),
          embedding: nil,
          embedding_status: :pending,
          metadata: %{
            has_docs: has_docs?(parsed_content),
            has_specs: has_specs?(parsed_content),
            has_tests: String.contains?(file_path, "_test.exs")
          }
        }
        
        # Store the initial entry
        case KnowledgeBase.put(knowledge_base, file_path, entry) do
          :ok ->
            # Start async task to generate and store embeddings
            Task.start_link(fn ->
              # Generate embeddings for both full content and important sections
              embeddings = %{
                full_content: generate_embedding(%{content: content}),
                docs: generate_embedding(%{content: extract_documentation(parsed_content)})
              }
              
              # Update the entry with embeddings
              updated_entry = Map.merge(entry, %{
                embedding: embeddings.full_content,
                embeddings: %{
                  docs: embeddings.docs
                },
                embedding_status: :complete
              })
              
              KnowledgeBase.put(knowledge_base, file_path, updated_entry)
            end)
            
            :ok
            
          error ->
            Logger.error("Failed to index #{file_path}: #{inspect(error)}")
            error
        end

      error ->
        Logger.error("Failed to read #{file_path}: #{inspect(error)}")
        error
    end
  end
  
  # Helper functions for content analysis
  defp has_docs?(%{docs: %{module: module_doc, functions: func_docs}}), 
    do: not is_nil(module_doc) or length(func_docs) > 0
  defp has_docs?(_), do: false
  
  defp has_specs?(%{functions: funcs}) when is_list(funcs), 
    do: Enum.any?(funcs, &Map.has_key?(&1, :spec))
  defp has_specs?(_), do: false
  
  defp extract_documentation(%{docs: %{module: module_doc, functions: func_docs}} = _parsed) do
    module_doc_str = if module_doc, do: module_doc.content, else: ""
    func_docs_str = Enum.map_join(func_docs, "\n\n", & &1.content)
    "#{module_doc_str}\n\n#{func_docs_str}"
  end
  defp extract_documentation(_), do: ""

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
  
  # Helper to check if a file should be ignored
  defp ignored_file?(file_path) do
    path_parts = Path.split(file_path)
    
    Enum.any?(@ignored_dirs, fn dir ->
      dir_parts = String.split(dir, "/")
      Enum.any?(0..(length(path_parts) - length(dir_parts)), fn i ->
        Enum.slice(path_parts, i, length(dir_parts)) == dir_parts
      end)
    end)
  end
  
  # Helper to check if a file is a source file
  defp is_source_file?(file_path) do
    ext = Path.extname(file_path) |> String.downcase()
    ext in @source_extensions
  end
  
  # Recursively find files in a directory
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
  
  # Get the last indexed timestamp from the knowledge base
  defp get_last_indexed(knowledge_base) do
    case KnowledgeBase.get(knowledge_base, "_last_indexed") do
      {:ok, %{last_updated: timestamp}} -> {:ok, timestamp}
      _ -> {:ok, 0}
    end
  end
end
