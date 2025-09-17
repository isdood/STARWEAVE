defmodule StarweaveLlm.MockBertEmbedder do
  @moduledoc """
  Mock implementation of the BERT embedder for testing.
  """
  @behaviour StarweaveLlm.Embeddings.Behaviour
  
  @impl true
  def embed(_text) do
    # Return a simple embedding for testing
    {:ok, [0.1, 0.2, 0.3, 0.4, 0.5]}
  end
end

defmodule StarweaveLlm.MockKnowledgeBase do
  @moduledoc """
  Mock implementation of the KnowledgeBase for testing.
  """
  @behaviour StarweaveLlm.SelfKnowledge.Behaviour
  
  @impl true
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  
  @impl true
  def put(_pid, _id, _entry), do: :ok
  
  @impl true
  def get(_pid, _id), do: {:ok, %{}}
  
  @impl true
  def search(_pid, _query, _opts \\ []), do: {:ok, []}
  
  @impl true
  def vector_search(_pid, _embedding, _opts \\ []) do
    # Return a test entry with a high similarity score
    test_entry = %{
      id: "test_entry_1",
      content: "Test content about pattern matching",
      file_path: "test/file.ex",
      module: "Test.Module",
      function: "test_function/1",
      embedding: [0.1, 0.2, 0.3, 0.4, 0.5],
      last_updated: DateTime.utc_now()
    }
    {:ok, [%{entry: test_entry, score: 0.98}]}
  end
  
  @impl true
  def update_embedding(_pid, _id, _embedding), do: :ok
end
