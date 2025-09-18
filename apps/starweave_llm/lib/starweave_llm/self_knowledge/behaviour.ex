defmodule StarweaveLlm.SelfKnowledge.Behaviour do
  @moduledoc """
  Defines the behaviour for knowledge base modules.
  
  This behaviour specifies the contract that all knowledge base implementations must follow.
  It ensures consistency across different storage backends and makes it easy to
  swap implementations for testing or different environments.
  """
  
  @type entry :: %{
    id: String.t(),
    content: String.t(),
    file_path: String.t(),
    module: String.t() | nil,
    function: String.t() | nil,
    embedding: [float()] | nil,
    last_updated: DateTime.t()
  }
  
  @type search_result :: %{
    entry: entry(),
    score: float()
  }

  @doc """
  Starts the knowledge base process.
  
  ## Options
    * `:name` - The name to register the process under (optional)
    * `:table_name` - The name of the ETS/DETS table (required)
    * `:dets_path` - The path for the DETS file (required for persistent storage)
    
  ## Returns
    * `{:ok, pid}` - The process ID of the server
    * `{:error, reason}` - If the server fails to start
  """
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  
  @doc """
  Stores an entry in the knowledge base.
  
  ## Parameters
    * `id` - A unique identifier for the entry
    * `entry` - The entry to store (must be a map)
    
  ## Returns
    * `:ok` - If the entry was stored successfully
    * `{:error, reason}` - If the operation failed
  """
  @callback put(pid() | atom(), String.t(), map()) :: :ok | {:error, any()}
  
  @doc """
  Retrieves an entry from the knowledge base by ID.
  
  ## Parameters
    * `id` - The ID of the entry to retrieve
    
  ## Returns
    * `{:ok, entry}` - The retrieved entry
    * `{:error, :not_found}` - If no entry exists with the given ID
  """
  @callback get(pid() | atom(), String.t()) :: {:ok, map()} | {:error, :not_found}
  
  @doc """
  Performs a full-text search across the knowledge base.
  
  ## Parameters
    * `query` - The search query string
    * `opts` - Additional options
      * `:limit` - Maximum number of results to return (default: 10)
      
  ## Returns
    * `{:ok, [search_result]}` - A list of search results with relevance scores
    * `{:error, reason}` - If the search failed
  """
  @callback search(pid() | atom(), String.t(), keyword()) :: {:ok, [search_result()]} | {:error, any()}
  
  @doc """
  Performs a vector similarity search across the knowledge base.
  
  ## Parameters
    * `embedding` - The query embedding vector
    * `opts` - Additional options
      * `:min_similarity` - Minimum similarity score (0.0 to 1.0, default: 0.6)
      * `:max_results` - Maximum number of results to return (default: 5)
      * `:include_context` - Whether to include context in the results (default: false)
      
  ## Returns
    * `{:ok, [search_result]}` - A list of search results with similarity scores
    * `{:error, reason}` - If the search failed
  """
  @callback vector_search(pid() | atom(), [float()], keyword()) :: {:ok, [search_result()]} | {:error, any()}

  @doc """
  Performs a text-based search against the knowledge base.
  
  ## Parameters
    * `query` - The search query string
    * `opts` - Search options
      * `:min_score` - Minimum score threshold (0.0 to 1.0)
      * `:max_results` - Maximum number of results to return
      * `:include_context` - Whether to include surrounding context
      
  ## Returns
    * `{:ok, [search_result()]}` - A list of search results
    * `{:error, reason}` - If the search failed
  """
  @callback text_search(pid() | atom(), String.t(), keyword()) :: {:ok, [search_result()]} | {:error, any()}

  @doc """
  Updates the embedding for a specific entry.
  
  ## Parameters
    * `id` - The ID of the entry to update
    * `embedding` - The new embedding vector
    
  ## Returns
    * `:ok` - If the update was successful
    * `{:error, reason}` - If the update failed
  """
  @callback update_embedding(pid() | atom(), String.t(), [float()]) :: :ok | {:error, any()}
end
