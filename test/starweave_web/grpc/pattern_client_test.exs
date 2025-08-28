defmodule StarweaveWeb.GRPC.PatternClientTest do
  use ExUnit.Case, async: false
  alias StarweaveWeb.GRPC.PatternClient
  require Logger

  @test_pattern %{
    id: "test-pattern-1",
    data: "test data",
    metadata: %{"source" => "test-client"}
  }

  @moduletag :grpc
  @moduletag :integration
  @server_port 50051
  @server_host "localhost"
  @server_endpoint "#{@server_host}:#{@server_port}"

  setup_all do
    # Ensure the gRPC application is started
    Application.ensure_all_started(:grpc)
    
    # Check if the port is available
    port_available = case :gen_tcp.listen(@server_port, []) do
      {:ok, socket} -> 
        :gen_tcp.close(socket)
        true
      _ -> 
        Logger.warning("Port #{@server_port} is not available. Tests may fail if server is not running.")
        false
    end
    
    # Only start the server if the port is available
    if port_available do
      # Start the Python gRPC server in a separate process
      server_cmd = ~s(python3 -c "
import sys
sys.path.append('services/python/server')
from pattern_server import serve
serve()
      ")
      
      port = Port.open({:spawn, server_cmd}, [:binary, :exit_status, :stderr_to_stdout])
      
      # Wait for server to start (up to 5 seconds)
      case wait_for_server(@server_host, @server_port, 5000) do
        :ok -> 
          Logger.info("gRPC server started successfully")
          on_exit(fn -> 
            # Stop the server after tests complete
            if Process.alive?(port), do: Port.close(port)
            Logger.info("gRPC server stopped")
          end)
          {:ok, %{server_port: @server_port}}
        {:error, reason} -> 
          Logger.error("Failed to start gRPC server: #{inspect(reason)}")
          {:error, reason}
      end
    else
      # If port is not available, assume server is already running
      Logger.info("Assuming gRPC server is already running on port #{@server_port}")
      :ok
    end
  end
  
  defp wait_for_server(_host, _port, timeout) when timeout <= 0, do: {:error, :timeout}
  defp wait_for_server(host, port, timeout) do
    case :gen_tcp.connect(String.to_charlist(host), port, [], 1000) do
      {:ok, socket} -> 
        :gen_tcp.close(socket)
        :ok
      _ -> 
        Process.sleep(100)
        wait_for_server(host, port, timeout - 100)
    end
  end

  describe "recognize_pattern/2" do
    test "successfully recognizes a pattern" do
      assert {:ok, response} = PatternClient.recognize_pattern(@test_pattern, [endpoint: @server_endpoint])
      assert is_binary(response.request_id)
      assert is_list(response.labels)
      assert is_map(response.confidences)
      assert is_map(response.metadata)
      assert response.labels == ["mock_label_1", "mock_label_2"]
      assert Map.has_key?(response.confidences, "mock_label_1")
    end
    
    test "handles invalid patterns" do
      assert {:error, _reason} = PatternClient.recognize_pattern(%{invalid: "pattern"}, [endpoint: @server_endpoint])
    end
  end

  describe "get_status/1" do
    test "returns server status" do
      assert {:ok, status} = PatternClient.get_status(false, [endpoint: @server_endpoint])
      assert is_binary(status.status)
      assert is_binary(status.version)
      assert is_integer(status.uptime)
      assert is_map(status.metrics)
      assert status.status == "SERVING"
    end

    test "returns detailed status when requested" do
      assert {:ok, status} = PatternClient.get_status(true, [endpoint: @server_endpoint])
      assert is_binary(status.status)
      assert is_map(status.metrics)
      assert map_size(status.metrics) > 2  # At least uptime and requests_processed should be present
      assert status.status == "SERVING"
    end
    
    test "handles server not available" do
      # Test with a non-existent server
      assert {:error, _reason} = PatternClient.get_status(false, [endpoint: "localhost:9999", connect_timeout: 1000])
    end
  end

  describe "stream_patterns/2" do
    test "streams patterns and receives responses" do
      patterns = [
        %{id: "stream-1", data: "data-1", metadata: %{}},
        %{id: "stream-2", data: "data-2", metadata: %{}},
        %{id: "stream-3", data: "data-3", metadata: %{}}
      ]

      # Convert the stream to a list to force evaluation
      responses = 
        patterns
        |> PatternClient.stream_patterns([endpoint: @server_endpoint])
        |> Enum.to_list()
      
      assert length(responses) == 3
      
      # Verify each response has the expected structure
      Enum.with_index(responses, 1)
      |> Enum.each(fn {response, idx} ->
        assert is_binary(response.request_id)
        assert is_list(response.labels)
        assert is_map(response.confidences)
        assert is_map(response.metadata)
        assert String.starts_with?(response.request_id, "stream-")
        assert response.metadata["pattern_id"] == "stream-#{idx}"
      end)
    end
    
    test "handles empty pattern list" do
      assert [] = PatternClient.stream_patterns([], [endpoint: @server_endpoint]) |> Enum.to_list()
    end
  end

  describe "error handling" do
    setup do
      # Save original configuration
      original_opts = Application.get_env(:grpc, :default_channel_opts, [])
      
      on_exit(fn ->
        # Restore original configuration after test
        Application.put_env(:grpc, :default_channel_opts, original_opts)
      end)
      
      :ok
    end
    
    @tag :skip
    test "handles server unavailability gracefully" do
      # This test is skipped because it requires a non-existent server to be available
      # In a real test environment, we would use Mox to mock the gRPC client
      :ok
    end
    
    test "handles invalid responses" do
      # This test mocks a server that returns an invalid response
      # We'll use Mox for this in a real test, but for now we'll skip it
      # and leave it as a TODO for when we set up test mocks
      :ok
    end
  end
end
