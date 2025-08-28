# Start ExUnit
ExUnit.start()

# Configure Mox
Application.ensure_all_started(:mox)
Mox.defmock(StarweaveWeb.GRPCClientMock, for: StarweaveWeb.GRPCClientBehaviour)

# Set Mox in global mode
Mox.stub_with(StarweaveWeb.GRPCClientMock, StarweaveWeb.GRPC.PatternClient)

# Set Mox to global mode for async tests
Application.put_env(:mox, :global_mox, true)

# Load test helpers
Code.require_file("test/support/grpc_case.ex")
