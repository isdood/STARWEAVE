use Mix.Config

# Prevent application from starting during tests
config :starweave_llm, :start_application, false

# Configure the mock BERT embedder for testing
config :starweave_llm, :embedder, StarweaveLlm.MockBertEmbedder

# Configure the test repository
config :starweave_llm, StarweaveLlm.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "starweave_llm_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Use the mock knowledge base for testing
config :starweave_llm, :knowledge_base, StarweaveLlm.MockKnowledgeBaseStub

# Configure Mox
config :starweave_llm, :mock_embedder, StarweaveLlm.MockBertEmbedder

# Configure HTTPoison mock
config :starweave_llm, :http_client, HTTPoison.Base

# Configure Ollama
config :starweave_llm, :ollama_base_url, "http://localhost:11434/api"

# Configure test environment
config :logger, level: :warn
config :mox, :global_mock_server, true
