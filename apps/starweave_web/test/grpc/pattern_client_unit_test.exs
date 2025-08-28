defmodule StarweaveWeb.GRPC.PatternClientUnitTest do
  use ExUnit.Case, async: false
  
  alias StarweaveWeb.GRPC.PatternClient
  alias Starweave.{PatternResponse, StatusResponse, PatternRequest, Pattern}
  
  # Test data
  @test_pattern %{
    id: "test-pattern-1",
    data: "test data",
    metadata: %{"key" => "value"}
  }
  
  describe "PatternClient helper functions" do
    test "build_pattern_request/1 creates a valid PatternRequest" do
      request = PatternClient.build_pattern_request(@test_pattern)
      
      assert %PatternRequest{pattern: %Pattern{}} = request
      assert request.pattern.id == @test_pattern.id
      assert request.pattern.data == @test_pattern.data
      assert request.pattern.metadata == [{"key", "value"}]
    end
    
    test "build_pattern_request/1 handles missing metadata" do
      pattern = Map.drop(@test_pattern, [:metadata])
      request = PatternClient.build_pattern_request(pattern)
      
      assert %PatternRequest{pattern: %Pattern{}} = request
      assert request.pattern.metadata == []
    end
    
    test "build_status_request/1 creates a valid StatusRequest" do
      assert %Starweave.StatusRequest{detailed: true} = PatternClient.build_status_request(true)
      assert %Starweave.StatusRequest{detailed: false} = PatternClient.build_status_request(false)
      assert %Starweave.StatusRequest{detailed: false} = PatternClient.build_status_request()
    end
  end
  
  describe "Error handling" do
    test "format_grpc_error/1 formats RPC errors" do
      error = %GRPC.RPCError{status: 14, message: "unavailable"}
      assert "gRPC RPC error (status: 14): unavailable" = PatternClient.format_grpc_error(error)
    end
    
    test "format_grpc_error/1 handles non-RPC errors" do
      assert "unknown error: :econnrefused" = PatternClient.format_grpc_error(:econnrefused)
      assert "unknown error: {:error, :timeout}" = PatternClient.format_grpc_error({:error, :timeout})
    end
  end
end
