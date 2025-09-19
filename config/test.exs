import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :starweave_web, StarweaveWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "a0cCE2alCQt5JERFCKzWK3nv7xWovz4/6sr2fB/ae4uYAZM1LInEFWhXPYHBTprI",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure gRPC for test environment
config :grpc,
  start_server: false,
  log_level: :debug,
  telemetry_enabled: true

# Configure gRPC client with robust settings
config :starweave_web, StarweaveWeb.GRPC.PatternClient,
  endpoint: "localhost:50051",
  ssl: false,
  adapter: GRPC.Client.Adapters.Gun,
  connect_timeout: 5_000,
  recv_timeout: 10_000,
  retry_timeout: 1_000,
  retry_max: 3,
  adapter_opts: [
    transport_opts: [
      protocols: [:http2],
      connect_timeout: 5_000,
      recv_timeout: 10_000,
      retry_timeout: 1_000,
      retry_max: 3,
      http2_opts: [
        keepalive: 30_000
      ],
      verify: :verify_none
    ]
  ]

# Configure test mode for starweave_llm
config :starweave_llm, test_mode: true

# Configure telemetry for gRPC
config :telemetry, :metrics, [
  # Capture gRPC client metrics
  [
    event_name: [:grpc, :client, :request, :stop],
    measurement: :duration,
    name: "grpc.client.request.duration",
    tags: [:service, :method, :status],
    unit: {:native, :millisecond}
  ]
]
