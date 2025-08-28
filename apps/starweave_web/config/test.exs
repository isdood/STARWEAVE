use Mix.Config

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
