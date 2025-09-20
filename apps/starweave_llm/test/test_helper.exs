# Start ExUnit with the test suite
ExUnit.start()

# Define the mock modules
Mox.defmock(StarweaveLlm.MockBertEmbedder, for: StarweaveLlm.Embeddings.Behaviour)
Mox.defmock(StarweaveLlm.MockKnowledgeBase, for: StarweaveLlm.SelfKnowledge.Behaviour)
Mox.defmock(HTTPoison.Base, for: HTTPoison.Base)

# Set Mox in global mode
Application.put_env(:mox, :global_mock_server, true)

# Configure test environment
Application.put_env(:starweave_llm, :ollama_base_url, "http://localhost:11434/api")

# Prevent application from starting during tests
Application.put_env(:starweave_llm, :start_application, false)

# Enable test mode for more predictable test behavior
Application.put_env(:starweave_llm, :test_mode, true)

# Configure mock KnowledgeBase
Application.put_env(:starweave_llm, :knowledge_base, StarweaveLlm.SelfKnowledge.KnowledgeBase.Mock)

# Define a simple stub module for the embedder
defmodule StarweaveLlm.MockBertEmbedderStub do
  @moduledoc false
  @behaviour StarweaveLlm.Embeddings.Behaviour
  
  @impl true
  def embed(text) when is_binary(text) do
    # Generate a simple deterministic embedding based on the text
    embedding = 
      text
      |> String.to_charlist()
      |> Enum.take(5)
      |> Enum.map(fn char -> char / 1000 end)
    
    # Ensure we have at least 5 dimensions
    embedding = List.duplicate(0.1, max(0, 5 - length(embedding))) ++ embedding
    {:ok, Enum.take(embedding, 5)}
  end
  
  # Keep the server-based API for backward compatibility
  def embed(_server, text) when is_binary(text) do
    embed(text)
  end
  
  def embed(_server, texts) when is_list(texts) do
    # For lists, generate an embedding for each text
    embeddings = Enum.map(texts, &(elem(embed(&1), 1)))
    {:ok, embeddings}
  end
end

# Define a simple stub module for the knowledge base
defmodule StarweaveLlm.MockKnowledgeBaseStub do
  @moduledoc false
  @behaviour StarweaveLlm.SelfKnowledge.Behaviour
  
  @impl true
  def start_link(_opts), do: :ignore
  
  @impl true
  def vector_search(_knowledge_base, _query_embedding, _opts \\ []) do
    {:ok, []}
  end
  
  @impl true
  def text_search(_knowledge_base, _query, _opts \\ []) do
    {:ok, []}
  end
  
  @impl true
  def update_embedding(_knowledge_base, _id, _embedding), do: :ok
  
  @impl true
  def put(_knowledge_base, _id, _entry), do: :ok
  
  @impl true
  def get(_knowledge_base, _id), do: nil
  
  @impl true
  def search(_knowledge_base, _query, _opts \\ []), do: {:ok, []}
end

# Set up Mox to use our stub implementations
Mox.stub_with(StarweaveLlm.MockBertEmbedder, StarweaveLlm.MockBertEmbedderStub)
Mox.stub_with(StarweaveLlm.MockKnowledgeBase, StarweaveLlm.MockKnowledgeBaseStub)
