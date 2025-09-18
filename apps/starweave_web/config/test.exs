use Mix.Config

# Configure endpoint for test environment
config :starweave_web, StarweaveWeb.Endpoint,
  http: [port: 4002],
  server: true,
  secret_key_base: "test_secret_key_123456789012345678901234567890123456789012345678901234567890",
  live_view: [signing_salt: "test_signing_salt"]

# Configure Mox for testing
config :starweave_web, :grpc_client, StarweaveWeb.GRPC.PatternClient

# Configure gRPC client for test environment
config :starweave_web, StarweaveWeb.GRPC.PatternClient,
  # Disable SSL for testing
  ssl: false,
  grpc_adapter: GRPC.Client.Adapters.Gun,
  grpc_adapter_opts: [
    transport_opts: [
      connect_timeout: 10_000,
      retry_timeout: 1_000,
      retry_max: 3,
      # Disable SSL verification for testing
      verify: :verify_none
    ]
  ]

# Reduce noise in test logs
config :logger, level: :warn
