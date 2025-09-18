use Mix.Config

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

# Configure test environment
config :logger, level: :warn
