# Start ExUnit with test coverage if available
if Code.ensure_loaded?(ExCoverage) do
  ExUnit.start(capture_log: true)
else
  ExUnit.start()
end

# Configure Mox for mocking
Application.ensure_all_started(:mox)
Mox.defmock(StarweaveWeb.GRPCClientMock, for: StarweaveWeb.GRPCClientBehaviour)
Mox.stub_with(StarweaveWeb.GRPCClientMock, StarweaveWeb.GRPC.PatternClient)
Application.put_env(:mox, :global_mox, true)

# Configure test environment
Application.put_env(:starweave_web, StarweaveWeb.Endpoint,
  http: [port: 4002],
  server: true,
  secret_key_base: "test_secret_key_123456789012345678901234567890123456789012345678901234567890",
  live_view: [signing_salt: "test_signing_salt"]
)

# Load test helpers
Code.require_file("test/support/conn_case.ex")
Code.require_file("test/support/grpc_case.ex")

# Start applications needed for testing
{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = Application.ensure_all_started(:plug_cowboy)
{:ok, _} = Application.ensure_all_started(:phoenix_live_view)

# Ensure the application is started
Application.ensure_all_started(:starweave_web)
