defmodule StarweaveLlm.MockKnowledgeBase do
  @moduledoc """
  Mock implementation of the KnowledgeBase for testing purposes.
  """
  
  @behaviour StarweaveLlm.SelfKnowledge.Behaviour
  
  # This is a Mox mock, so we don't need to implement start_link directly
  # Mox will handle the function stubs for us
  
  @impl true
  def vector_search(knowledge_base, query_embedding, opts \\ []) do
    # For testing, return a simple result based on the query embedding
    min_similarity = Keyword.get(opts, :min_similarity, 0.0)
    max_results = Keyword.get(opts, :max_results, 10)
    
    # In a real test, you would have some test data to search through
    # For now, we'll return an empty list or a mock result
    {:ok, []}
  end
  
  @impl true
  def update_embedding(knowledge_base, id, embedding) do
    # For testing, just return :ok
    :ok
  end
  
  @impl true
  def put(knowledge_base, id, entry) do
    # For testing, just return :ok
    :ok
  end
  
  @impl true
  def get(knowledge_base, id) do
    # For testing, return nil or a mock entry
    nil
  end
  
  @impl true
  def search(knowledge_base, query, opts \\ []) when is_binary(query) do
    # For testing, return an empty list
    {:ok, []}
  end
end
