defmodule StarweaveWeb.GRPCCase do
  @moduledoc """
  This module defines the test case for gRPC-related tests.
  It sets up mocks and test helpers for gRPC client testing.
  """

  use ExUnit.CaseTemplate

  # Set up Mox
  import Mox

  # Set up test case
  setup :set_mox_from_context
  setup :verify_on_exit!

  # Set up default mocks for gRPC
  setup do
    # Configure Mox to allow stubbing GRPC.Stub
    Mox.stub_with(GRPC.Stub, GRPC.Stub)
    :ok
  end

  @doc """
  Helper function to mock a successful gRPC connection.
  """
  def mock_successful_connection do
    allow(GRPC.Stub, :connect, fn _, _ ->
      {:ok, :mock_channel}
    end)
  end

  @doc """
  Helper function to mock a failed gRPC connection.
  """
  def mock_failed_connection(reason \\ :econnrefused) do
    allow(GRPC.Stub, :connect, fn _, _ ->
      {:error, reason}
    end)
  end
end
