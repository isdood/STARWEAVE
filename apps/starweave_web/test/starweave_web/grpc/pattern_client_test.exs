defmodule StarweaveWeb.GRPC.PatternClientTest do
  use ExUnit.Case, async: false
  alias StarweaveWeb.GRPC.PatternClient

  @test_pattern %{
    id: "test-pattern-1",
    data: "test data",
    metadata: %{"source" => "test-client"}
  }

  @moduletag :grpc
  @moduletag :integration

  setup_all do
    # Start the gRPC application
    Application.ensure_all_started(:grpc)
    :ok
  end

  describe "recognize_pattern/2" do
    test "successfully recognizes a pattern" do
      assert {:ok, response} = PatternClient.recognize_pattern(@test_pattern)
      assert is_binary(response.request_id)
      assert is_list(response.labels)
      assert is_map(response.confidences)
      assert is_map(response.metadata)
    end
  end

  describe "get_status/1" do
    test "returns server status" do
      assert {:ok, status} = PatternClient.get_status()
      assert is_binary(status.status)
      assert is_binary(status.version)
      assert is_integer(status.uptime)
      assert is_map(status.metrics)
    end

    test "returns detailed status when requested" do
      assert {:ok, status} = PatternClient.get_status(true)
      assert is_binary(status.status)
      assert is_map(status.metrics)
      assert map_size(status.metrics) > 0
    end
  end

  describe "stream_patterns/2" do
    test "stream_patterns/2 processes patterns and returns responses" do
      # Define test patterns to send
      patterns = [
        %{id: "stream-1", data: "data-1", metadata: %{}},
        %{id: "stream-2", data: "data-2", metadata: %{}},
        %{id: "stream-3", data: "data-3", metadata: %{}}
      ]

      # Call the function with test patterns
      case PatternClient.stream_patterns(patterns) do
        {:ok, responses} when is_list(responses) ->
          # Verify we got responses for each pattern
          assert length(responses) == length(patterns)

          # Verify each response has the expected structure
          Enum.each(responses, fn response ->
            assert %Starweave.PatternResponse{} = response
            assert is_binary(response.request_id)
            assert is_list(response.labels)
            assert is_map(response.confidences)
            assert is_map(response.metadata)
          end)

        {:error, reason} ->
          flunk("Failed to process patterns: #{inspect(reason)}")

        other ->
          flunk("Unexpected response format: #{inspect(other)}")
      end
    end
  end

  test "verifies server status response format" do
    # This test verifies that the server responds with the expected status format
    assert {:ok, %Starweave.StatusResponse{} = status} = PatternClient.get_status()

    # Verify the response has the expected fields
    assert is_binary(status.status)
    assert is_binary(status.version)
    assert is_integer(status.uptime)
    assert is_map(status.metrics)

    # Verify specific metrics we expect to be present
    assert is_binary(status.metrics["status"])
    assert is_binary(status.metrics["requests_processed"])
    assert is_binary(status.metrics["uptime_seconds"])
  end

  @tag :skip
  test "handles server unavailability gracefully" do
    # This test is skipped by default because it requires the server to be down
    # To run this test, stop the Python gRPC server first

    # Test with a non-existent server
    original_opts = Application.get_env(:grpc, :default_channel_options)

    # Set to non-existent server with a short timeout
    test_opts = [
      host: "localhost",
      port: 12345,
      # 1 second timeout
      timeout: 1000,
      # Disable retries for this test
      retry: false
    ]

    Application.put_env(:grpc, :default_channel_options, test_opts)

    # This should fail because there's no server running on this port
    assert {:error, reason} = PatternClient.get_status()
    assert is_binary(reason) or is_map(reason) or is_list(reason)

    # Restore original config
    Application.put_env(:grpc, :default_channel_options, original_opts)
  end
end
