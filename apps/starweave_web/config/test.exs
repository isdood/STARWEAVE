use Mix.Config

# Configure Mox for testing
config :starweave_web, :grpc_client, StarweaveWeb.GRPC.PatternClient

# Configure gRPC client for test environment
config :starweave_web, StarweaveWeb.GRPC.PatternClient,
  ssl: false,  # Disable SSL for testing
  grpc_adapter: GRPC.Client.Adapters.Gun,
  grpc_adapter_opts: [
    transport_opts: [
      connect_timeout: 10_000,
      retry_timeout: 1_000,
      retry_max: 3,
      verify: :verify_none  # Disable SSL verification for testing
    ]
  ]

# Reduce noise in test logs
config :logger, level: :warn
