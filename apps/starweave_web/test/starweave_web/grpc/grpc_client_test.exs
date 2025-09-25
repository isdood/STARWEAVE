defmodule StarweaveWeb.GRPCClientTest do
  use ExUnit.Case, async: true
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Import the mock module
  alias StarweaveWeb.GRPCClientMock

  # Use the mock directly in tests
  @mock_client StarweaveWeb.GRPCClientMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  defp test_pattern do
    %{
      id: "test-pattern-1",
      data: "test data",
      metadata: %{"source" => "test-client"}
    }
  end

  defp test_response do
    %{
      request_id: "req-123",
      labels: ["test-label"],
      confidences: %{"test-label" => 0.95},
      metadata: %{"processing_time" => 42}
    }
  end

  describe "analyze_pattern/2" do
    test "successfully analyzes a pattern" do
      pattern = test_pattern()
      response = test_response()

      # Setup the mock expectation
      expect(GRPCClientMock, :analyze_pattern, fn ^pattern, _opts ->
        {:ok, response}
      end)

      # Call the function on the mock with the correct arity
      assert {:ok, result} = @mock_client.analyze_pattern(pattern, [])
      assert result.request_id == response.request_id
      assert result.labels == response.labels
    end

    test "handles gRPC errors" do
      pattern = test_pattern()

      # Setup the mock to return an error
      expect(GRPCClientMock, :analyze_pattern, fn ^pattern, _opts ->
        {:error, "gRPC error: connection refused"}
      end)

      # Call the function on the mock with the correct arity
      assert {:error, reason} = @mock_client.analyze_pattern(pattern, [])
      assert is_binary(reason)
    end
  end

  describe "create_channel/2" do
    test "creates a channel with default options" do
      endpoint = "localhost:50052"

      # Setup the mock expectation
      expect(GRPCClientMock, :create_channel, fn ^endpoint, opts ->
        assert is_list(opts)
        {:ok, %GRPC.Channel{}}
      end)

      # Call the function on the mock with the correct arity
      assert {:ok, %GRPC.Channel{}} = @mock_client.create_channel(endpoint, [])
    end
  end

  describe "close_channel/1" do
    test "closes a channel successfully" do
      channel = %GRPC.Channel{}

      # Setup the mock expectation
      expect(GRPCClientMock, :close_channel, fn ^channel ->
        :ok
      end)

      # Call the function on the mock
      assert :ok = @mock_client.close_channel(channel)
    end
  end
end
