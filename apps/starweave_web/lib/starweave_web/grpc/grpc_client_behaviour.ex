defmodule StarweaveWeb.GRPCClientBehaviour do
  @moduledoc """
  Defines the behaviour for gRPC client operations.
  This allows us to mock the gRPC client in tests.
  """

  @type pattern :: map()
  @type stream :: Enumerable.t()
  @type error :: {:error, term()}
  @type channel :: GRPC.Channel.t()

  @callback analyze_pattern(pattern :: pattern(), opts :: keyword()) ::
              {:ok, pattern()} | error()

  @callback analyze_pattern_stream(pattern :: pattern(), opts :: keyword()) ::
              {:ok, stream()} | error()

  @callback create_channel(endpoint :: String.t(), opts :: keyword()) ::
              {:ok, channel()} | error()

  @callback close_channel(channel :: channel()) :: :ok | error()

  @doc """
  Returns the default channel options.
  """
  @callback default_channel_opts() :: keyword()
end
