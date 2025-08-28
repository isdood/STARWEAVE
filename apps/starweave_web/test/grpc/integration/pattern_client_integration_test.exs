defmodule StarweaveWeb.GRPC.PatternClientIntegrationTest do
  use ExUnit.Case, async: false
  
  # Only run these tests when explicitly requested
  @moduletag :integration
  
  alias StarweaveWeb.GRPC.PatternClient
  alias Starweave.{PatternResponse, StatusResponse}
  
  @test_pattern %{
    id: "test-pattern-1",
    data: "test data",
    metadata: %{"key" => "value"}
  }
  
  @tag :integration
  test "can connect to gRPC server" do
    assert {:ok, %StatusResponse{}} = PatternClient.get_status()
  end
  
  @tag :integration
  test "can recognize a pattern" do
    assert {:ok, %PatternResponse{}} = PatternClient.recognize_pattern(@test_pattern)
  end
  
  @tag :integration
  test "can stream patterns" do
    assert {:ok, [%PatternResponse{} | _]} = 
      PatternClient.stream_patterns([@test_pattern])
  end
end
