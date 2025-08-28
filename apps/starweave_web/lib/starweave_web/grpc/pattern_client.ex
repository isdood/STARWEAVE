defmodule StarweaveWeb.GRPC.PatternClient do
  @moduledoc """
  This module provides functionality to interact with the Pattern Recognition Service via gRPC.
  It handles the communication with the gRPC server and provides a clean API for the application.

  ## Configuration

  In your config files, you can configure the gRPC client with:

      config :starweave_web, StarweaveWeb.GRPC.PatternClient,
        endpoint: "localhost:50051",
        ssl: false,
        connect_timeout: 5_000,
        recv_timeout: 10_000
  """

  require Logger

  @behaviour StarweaveWeb.GRPCClientBehaviour

  alias Starweave.PatternService.Stub, as: PatternServiceStub
  alias Starweave.{PatternRequest, Pattern, PatternResponse, StatusRequest}

  @default_endpoint "localhost:50051"
  @default_timeout 10_000
  @default_connect_timeout 5_000

  @doc """
  Get the default channel options from application config.
  """
  @impl true
  def default_channel_opts do
    config = Application.get_env(:starweave_web, __MODULE__, [])

    # Get SSL setting
    ssl = Keyword.get(config, :ssl, false)

    # Configure credentials based on SSL setting
    cred =
      if ssl do
        GRPC.Credential.new(ssl: [verify: :verify_none])
      else
        GRPC.Credential.new(ssl: false)
      end

    # Base configuration (keep minimal and let adapter defaults handle HTTP/2)
    [
      cred: cred,
      adapter: GRPC.Client.Adapters.Gun,
      timeout: Keyword.get(config, :recv_timeout, @default_timeout),
      connect_timeout: Keyword.get(config, :connect_timeout, @default_connect_timeout),
      scheme: if(ssl, do: "https", else: "http")
    ]
  end

  @doc """
  Analyzes a pattern by sending it to the gRPC server.

  ## Parameters
    - pattern: A map with the pattern data (id, data, metadata)
    - opts: Optional keyword list for additional options
      - `:endpoint` - The gRPC server endpoint (default: from config or "localhost:50051")
      - `:timeout` - Request timeout in milliseconds (default: from config or 10_000)
      
  ## Returns
    - `{:ok, PatternResponse.t()}` on success
    - `{:error, term()}` on failure
  """
  @impl true
  def analyze_pattern(%{} = pattern, opts \\ []) do
    with {:ok, request} <- build_pattern_request(pattern, opts),
         endpoint <- get_endpoint(opts),
         channel_opts <- build_channel_opts(opts),
         {:ok, channel} <- create_channel(endpoint, channel_opts) do
      result =
        PatternServiceStub.recognize_pattern(channel, request, timeout: channel_opts[:timeout])

      close_channel(channel)
      result
    end
  end

  @doc """
  Gets the status of the gRPC server.

  ## Parameters
    - detailed: Whether to include detailed status information (default: false)
    - opts: Optional keyword list for additional options
      - `:endpoint` - The gRPC server endpoint (default: from config or "localhost:50051")
      - `:timeout` - Request timeout in milliseconds (default: from config or 10_000)
      
  ## Returns
    - `{:ok, StatusResponse.t()}` on success
    - `{:error, term()}` on failure
  """
  def get_status(detailed \\ false, opts \\ []) do
    request = %StatusRequest{detailed: detailed}

    with endpoint <- get_endpoint(opts),
         channel_opts <- build_channel_opts(opts),
         {:ok, channel} <- create_channel(endpoint, channel_opts) do
      result = PatternServiceStub.get_status(channel, request, timeout: channel_opts[:timeout])
      close_channel(channel)
      result
    end
  end

  @doc """
  Streams multiple patterns to the gRPC server and collects responses.

  ## Parameters
    - patterns: A list of pattern maps
    - opts: Optional keyword list for additional options
      - `:endpoint` - The gRPC server endpoint (default: from config or "localhost:50051")
      - `:timeout` - Request timeout in milliseconds (default: from config or 10_000)
      
  ## Returns
    - A stream of `{:ok, PatternResponse.t()}` tuples
  """
  def stream_patterns(patterns, opts \\ []) when is_list(patterns) do
    patterns
    |> Enum.map(fn pattern -> analyze_pattern(pattern, opts) end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, %PatternResponse{} = resp}, {:ok, acc} -> {:cont, {:ok, [resp | acc]}}
      {:error, reason}, _ -> {:halt, {:error, reason}}
      other, {:ok, acc} -> {:cont, {:ok, [other | acc]}}
    end)
    |> case do
      {:ok, responses} -> {:ok, Enum.reverse(responses)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp build_pattern_request(pattern, _opts) do
    try do
      metadata =
        pattern
        |> Map.get(:metadata, %{})
        |> Map.to_list()

      request = %PatternRequest{
        pattern: %Pattern{
          id: to_string(Map.get(pattern, :id, "")),
          data: to_string(Map.get(pattern, :data, "")),
          metadata: metadata,
          timestamp: System.system_time(:second) / 1_000_000_000
        },
        context: []
      }

      {:ok, request}
    rescue
      e ->
        error_msg = "Failed to build pattern request: #{inspect(e)}"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  defp get_endpoint(opts) do
    config = Application.get_env(:starweave_web, __MODULE__, [])
    Keyword.get(opts, :endpoint, Keyword.get(config, :endpoint, @default_endpoint))
  end

  defp build_channel_opts(opts) do
    config = Application.get_env(:starweave_web, __MODULE__, [])

    # Get timeouts from opts with fallback to config
    timeout = Keyword.get(opts, :timeout, Keyword.get(config, :recv_timeout, @default_timeout))

    connect_timeout =
      Keyword.get(
        opts,
        :connect_timeout,
        Keyword.get(config, :connect_timeout, @default_connect_timeout)
      )

    # Build channel options
    [
      timeout: timeout,
      connect_timeout: connect_timeout,
      ssl: Keyword.get(opts, :ssl, Keyword.get(config, :ssl, false))
    ]
  end

  @doc """
  Creates a new gRPC channel.

  ## Parameters
    - endpoint: The server endpoint (e.g., "localhost:50051" or "example.com:443")
    - opts: Additional options for channel creation
      - `:timeout` - Request timeout in milliseconds
      - `:connect_timeout` - Connection timeout in milliseconds
      - `:ssl` - Whether to use SSL (default: false)
      
  ## Returns
    - `{:ok, GRPC.Channel.t()}` on success
    - `{:error, term()}` on failure
  """
  @impl true
  def create_channel(endpoint, opts \\ []) do
    # Parse the endpoint into host and port
    {host, port} = parse_endpoint(endpoint)

    # Get SSL setting
    ssl = Keyword.get(opts, :ssl, false)

    # Build minimal, valid connection options
    channel_opts = [
      host: host,
      port: port,
      scheme: if(ssl || port == 443, do: "https", else: "http"),
      adapter: GRPC.Client.Adapters.Gun,
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      connect_timeout: Keyword.get(opts, :connect_timeout, @default_connect_timeout)
    ]

    Logger.debug("Creating gRPC channel to #{host}:#{port}")

    # Connect to the gRPC server with retry logic
    case GRPC.Stub.connect("#{host}:#{port}", channel_opts) do
      {:ok, channel} ->
        Logger.debug("Successfully connected to gRPC server at #{host}:#{port}")
        {:ok, channel}

      {:error, reason} ->
        error_msg = "Failed to connect to gRPC server at #{host}:#{port}: #{inspect(reason)}"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  # Helper function to parse endpoint into {host, port} tuple
  defp parse_endpoint(endpoint) when is_binary(endpoint) do
    # Remove any http:// or https:// prefix
    endpoint = String.replace(endpoint, ~r/^https?:\/\//, "")

    # Split into host and port parts
    case String.split(endpoint, ":") do
      [host] ->
        # Default gRPC port if not specified
        {host, 50051}

      [host, port_str] ->
        {host, String.to_integer(port_str)}

      _ ->
        raise "Invalid endpoint format: #{endpoint}. Expected format: host:port"
    end
  end

  @doc """
  Closes a gRPC channel.

  ## Parameters
    - channel: The channel to close
    
  ## Returns
    - `:ok` on success
    - `{:error, term()}` on failure
  """
  @impl true
  def close_channel(channel) do
    try do
      GRPC.Stub.disconnect(channel)
      :ok
    rescue
      e ->
        Logger.error("Error closing gRPC channel: #{inspect(e)}")
        {:error, "Failed to close channel: #{inspect(e)}"}
    end
  end

  @doc """
  Analyzes a pattern stream by sending it to the gRPC server.

  ## Parameters
    - pattern: A map with the pattern data (id, data, metadata)
    - opts: Optional keyword list for additional options
    
  ## Returns
    - `{:ok, Enumerable.t()}` on success with a stream of responses
    - `{:error, term()}` on failure
  """
  @impl true
  def analyze_pattern_stream(%{} = pattern, opts \\ []) do
    metadata =
      pattern
      |> Map.get(:metadata, %{})
      |> Map.to_list()

    request = %PatternRequest{
      pattern: %Pattern{
        id: Map.get(pattern, :id, ""),
        data: Map.get(pattern, :data, ""),
        metadata: metadata,
        timestamp: System.system_time(:second) / 1_000_000_000
      },
      context: opts[:context] || []
    }

    with {:ok, channel} <- create_channel("localhost:50051", opts) do
      case PatternServiceStub.recognize_pattern(channel, [request]) do
        {:ok, stream} ->
          # Wrap the stream to ensure the channel is closed when done
          wrapped_stream =
            Stream.resource(
              fn -> {channel, stream} end,
              fn {channel, stream} ->
                case Enum.take(stream, 1) do
                  [] ->
                    {:halt, channel}

                  [response] ->
                    {[response], {channel, stream}}
                end
              end,
              fn channel ->
                close_channel(channel)
              end
            )

          {:ok, wrapped_stream}

        {:error, %GRPC.RPCError{status: status, message: message}} ->
          close_channel(channel)
          error_msg = "gRPC RPC error (status: #{status}): #{message}"
          Logger.error(error_msg)
          {:error, error_msg}

        {:error, reason} ->
          close_channel(channel)
          error_msg = "gRPC error: #{inspect(reason)}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    end
  end

  @doc """
  Recognizes a pattern by sending it to the Python gRPC server.

  ## Parameters
    - pattern: A map with the pattern data (id, data, metadata)
    - context: A list of context strings (optional)
    
  ## Returns
    - `{:ok, response}` on success
    - `{:error, reason}` on failure
  """
  @spec recognize_pattern(map(), [String.t()] | nil) ::
          {:ok, PatternResponse.t()} | {:error, any()}
  def recognize_pattern(%{} = pattern, context \\ nil) do
    analyze_pattern(pattern, context: context || [])
  end
end
