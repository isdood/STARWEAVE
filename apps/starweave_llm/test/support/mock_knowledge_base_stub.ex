defmodule StarweaveLlm.MockKnowledgeBaseStub do
  @moduledoc """
  Stub implementation of the MockKnowledgeBase for testing purposes.
  This is used with Mox to provide default implementations of the callbacks.
  """
  
  @behaviour StarweaveLlm.SelfKnowledge.Behaviour
  
  @impl true
  def start_link(_opts) do
    # This is a stub that will be replaced by Mox
    :ignore
  end
  
  @impl true
  def vector_search(_knowledge_base, _query_embedding, _opts \\ []) do
    # Default implementation that can be overridden in tests
    {:ok, []}
  end
  
  @impl true
  def update_embedding(_knowledge_base, _id, _embedding) do
    # Default implementation
    :ok
  end
  
  @impl true
  def put(_knowledge_base, _id, _entry) do
    # Default implementation
    :ok
  end
  
  @impl true
  def get(_knowledge_base, _id) do
    # Default implementation
    nil
  end
  
  @impl true
  def search(_knowledge_base, _query, _opts \\ []) do
    # Default implementation
    {:ok, []}
  end
end
