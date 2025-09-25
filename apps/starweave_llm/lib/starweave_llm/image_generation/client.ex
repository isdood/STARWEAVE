defmodule StarweaveLlm.ImageGeneration.Client do
  @moduledoc """
  gRPC client for the Image Generation Service.
  """
  use GenServer
  require Logger

  alias Starweave.ImageGenerationService.Stub
  alias Starweave.{
    ImageRequest,
    ImageSettings,
    ImageResponse,
    ModelRequest,
    ModelResponse
  }

  @default_timeout 60_000
  @default_host "localhost"
  @default_port 50051

  defmodule State do
    @moduledoc """
    Client state.
    """
    @type t :: %__MODULE__{
            channel: GRPC.Channel.t() | nil,
            stub: module() | nil,
            host: String.t(),
            port: integer(),
            enabled: boolean()
          }

    defstruct [:channel, :stub, :host, :port, enabled: true]
  end

  @doc """
  Starts the gRPC client.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generates an image based on the given prompt and settings.
  """
  @spec generate_image(String.t(), keyword()) ::
          {:ok, binary(), map()} | {:error, String.t()}
  def generate_image(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_image, prompt, opts}, @default_timeout)
  end

  @doc """
  Lists available image generation models.
  """
  @spec list_models() :: {:ok, [map()]} | {:error, String.t()}
  def list_models do
    GenServer.call(__MODULE__, :list_models, @default_timeout)
  end

  @doc """
  Checks if the image generation service is available.
  """
  @spec available?() :: boolean()
  def available? do
    case GenServer.call(__MODULE__, :available) do
      {:ok, available} -> available
      _ -> false
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    host = Keyword.get(opts, :host, @default_host)
    port = Keyword.get(opts, :port, @default_port)
    enabled = Keyword.get(opts, :enabled, true)

    state = %State{
      host: host,
      port: port,
      enabled: enabled
    }

    if enabled do
      {:ok, connect(state)}
    else
      {:ok, %{state | channel: nil, stub: nil}}
    end
  end

  @impl true
  def handle_call({:generate_image, prompt, opts}, from, %{channel: nil} = state) do
    if state.enabled do
      # Try to reconnect if enabled
      case connect(state) do
        %{channel: _channel} = new_state ->
          handle_call({:generate_image, prompt, opts}, from, new_state)
        _ ->
          {:reply, {:error, "Image generation service is not available"}, state}
      end
    else
      {:reply, {:error, "Image generation is disabled"}, state}
    end
  end

  def handle_call({:generate_image, prompt, opts}, _from, %{channel: channel} = state) do
    settings = %ImageSettings{
      width: Keyword.get(opts, :width, 512),
      height: Keyword.get(opts, :height, 512),
      steps: Keyword.get(opts, :steps, 20),
      guidance_scale: Keyword.get(opts, :guidance_scale, 7.5),
      seed: Keyword.get(opts, :seed, :rand.uniform(1_000_000)),
      style: Keyword.get(opts, :style, "")
    }

    request = %ImageRequest{
      prompt: prompt,
      settings: settings,
      model: Keyword.get(opts, :model, "runwayml/stable-diffusion-v1-5"),
      user_id: Keyword.get(opts, :user_id, ""),
      context: Keyword.get(opts, :context, [])
    }

    try do
      case Stub.generate_image(channel, request, timeout: @default_timeout) do
        {:ok, %ImageResponse{error: "", image_data: image_data, metadata: metadata}} ->
          {:reply, {:ok, image_data, Map.from_struct(metadata)}, state}
        {:ok, %ImageResponse{error: error}} ->
          Logger.error("Image generation failed: #{error}")
          {:reply, {:error, error}, state}
        {:error, %GRPC.RPCError{} = e} ->
          Logger.error("gRPC error: #{inspect(e)}")
          {:reply, {:error, "gRPC error: #{e.status}"}, %{state | channel: nil, stub: nil}}
        {:error, reason} ->
          Logger.error("Image generation error: #{inspect(reason)}")
          {:reply, {:error, "Image generation failed"}, %{state | channel: nil, stub: nil}}
        other ->
          Logger.error("Unexpected response from image generation service: #{inspect(other)}")
          {:reply, {:error, "Unexpected response from service"}, state}
      end
    rescue
      e in GRPC.RPCError ->
        Logger.error("gRPC error: #{inspect(e)}")
        {:reply, {:error, "gRPC error: #{e.status}"}, %{state | channel: nil, stub: nil}}
      e ->
        Logger.error("Image generation error: #{inspect(e)}")
        {:reply, {:error, "Image generation failed"}, %{state | channel: nil, stub: nil}}
    end
  end

  def handle_call(:list_models, from, %{channel: nil} = state) do
    if state.enabled do
      case connect(state) do
        %{channel: _channel} = new_state ->
          handle_call(:list_models, from, new_state)
        _ ->
          {:reply, {:error, "Image generation service is not available"}, state}
      end
    else
      {:reply, {:ok, []}, state}
    end
  end

  def handle_call(:list_models, _from, %{channel: channel} = state) do
    try do
      request = %ModelRequest{}
      
      case Stub.get_image_models(channel, request, timeout: @default_timeout) do
        {:ok, %ModelResponse{models: models}} ->
          models = Enum.map(models, &Map.from_struct/1)
          {:reply, {:ok, models}, state}
        {:error, %GRPC.RPCError{} = e} ->
          Logger.error("Failed to list models due to gRPC error: #{inspect(e)}")
          {:reply, {:ok, []}, %{state | channel: nil, stub: nil}}
        {:error, reason} ->
          Logger.error("Failed to list models: #{inspect(reason)}")
          {:reply, {:ok, []}, state}
        other ->
          Logger.error("Unexpected response while listing models: #{inspect(other)}")
          {:reply, {:ok, []}, state}
      end
    rescue
      e ->
        Logger.error("Error listing models: #{inspect(e)}")
        {:reply, {:ok, []}, state}
    end
  end

  def handle_call(:available, _from, %{channel: nil} = state) do
    if state.enabled do
      case connect(state) do
        %{channel: _} = new_state ->
          {:reply, {:ok, true}, new_state}
        _ ->
          {:reply, {:ok, false}, state}
      end
    else
      {:reply, {:ok, false}, state}
    end
  end

  def handle_call(:available, _from, state) do
    {:reply, {:ok, true}, state}
  end

  defp connect(state) do
    endpoint = "#{state.host}:#{state.port}"
    
    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        %{state | channel: channel}
      error ->
        Logger.error("Failed to connect to image generation service at #{endpoint}: #{inspect(error)}")
        %{state | channel: nil, stub: nil}
    end
  end
end
