defmodule StarweaveLlm.Embeddings.BertEmbedder do
  @moduledoc """
  BERT-based text embedder that implements the Embeddings.Behaviour.
  
  This module uses BERT models to generate dense vector representations of text,
  which can be used for semantic search and similarity calculations.
  """
  
  use GenServer
  require Logger
  
  @behaviour StarweaveLlm.Embeddings.Behaviour
  
  @default_model "sentence-transformers/all-MiniLM-L6-v2"
  @default_batch_size 8
  
  defstruct [
    :model_name,
    :batch_size,
    :serving,
    :model_info,
    :tokenizer
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    model_name = Keyword.get(opts, :model, @default_model)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    Logger.info("Initializing BERT embedder with model: #{model_name}")

    case load_model(model_name, batch_size) do
      {:ok, state} ->
        {:ok, %__MODULE__{
          model_name: model_name,
          batch_size: batch_size,
          model_info: state.model_info,
          tokenizer: state.tokenizer
        }}
      {:error, reason} ->
        Logger.error("Failed to initialize BERT embedder: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp load_model(model_name, batch_size) do
    with {:ok, model_info} <- Bumblebee.load_model({:hf, model_name}, architecture: :base),
         {:ok, tokenizer} <- Bumblebee.load_tokenizer({:hf, model_name}) do

      # Try without EXLA first
      state = %{
        model_name: model_name,
        batch_size: batch_size,
        model_info: model_info,
        tokenizer: tokenizer
      }

      {:ok, state}
    else
      error -> {:error, error}
    end
  end


  # Define the callback for the Embeddings.Behaviour
  @impl true
  @spec embed(String.t()) :: {:ok, [float()]} | {:error, atom()}
  def embed(text) when is_binary(text) do
    GenServer.call(__MODULE__, {:embed, [text]}, :infinity)
    |> case do
      {:ok, [embedding]} -> {:ok, embedding}
      error -> error
    end
  end

  @doc """
  Generates embeddings for a list of texts.

  Returns `{:ok, embeddings}` where embeddings is a list of float lists,
  or `{:error, reason}` if the operation fails.
  """
  @spec embed(GenServer.server(), [String.t()]) :: {:ok, [list(float())]} | {:error, atom()}
  def embed(server, texts) when is_list(texts) do
    GenServer.call(server, {:embed, texts}, :infinity)
  end

  # For backward compatibility with the server-based API
  def embed(server, text) when is_binary(text) do
    case GenServer.call(server, {:embed, [text]}, :infinity) do
      {:ok, [embedding]} -> {:ok, embedding}
      error -> error
    end
  end

  @doc """
  Callback for handling embedding generation requests.
  """
  @impl true
  def handle_call({:embed, texts}, _from, state) do
    # Emit telemetry for embedding request
    :telemetry.execute(
      [:embed],
      %{count: length(texts)},
      %{model: state.model_name, batch_size: state.batch_size}
    )

    # Measure time for the embedding operation
    {microseconds, result} = :timer.tc(fn ->
      process_embedding_batch(texts, state)
    end)

    # Emit telemetry for embedding completion
    :telemetry.execute(
      [:embed_complete],
      %{duration: microseconds, count: length(texts)},
      %{model: state.model_name}
    )

    case result do
      {:ok, _} = ok ->
        {:reply, ok, state}
      {:error, reason} ->
        :telemetry.execute(
          [:embed_error],
          %{count: 1},
          %{model: state.model_name, reason: reason}
        )
        {:reply, {:error, reason}, state}
    end
  end

  defp process_embedding_batch(texts, %{model_info: model_info, tokenizer: tokenizer, batch_size: batch_size} = _state) do
    try do
      # Process each text individually for now
      results =
        texts
        |> Enum.map(fn text ->
          case Bumblebee.Text.text_embedding(model_info, tokenizer, text) do
            %{embeddings: embeddings} ->
              embeddings
            error ->
              Logger.error("Error generating embedding for text: #{inspect(error)}")
              nil
          end
        end)
        |> Enum.filter(&(&1 != nil))

      case results do
        [] -> {:error, :no_embeddings_generated}
        embeddings -> {:ok, embeddings}
      end
    rescue
      e ->
        Logger.error("Error in process_embedding_batch: #{inspect(e)}")
        {:error, :embedding_error}
    end
  end

  @doc """
  Calculates cosine similarity between two embedding vectors.
  """
  @spec cosine_similarity([number()], [number()]) :: float()
  def cosine_similarity(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    dot = dot_product(vec1, vec2)
    norm1 = norm(vec1)
    norm2 = norm(vec2)

    if norm1 > 0.0 and norm2 > 0.0 do
      dot / (norm1 * norm2)
    else
      0.0
    end
  end

  @doc """
  Calculates the Euclidean (L2) norm of a vector.
  """
  @spec norm([number()]) :: float()
  def norm(vec) when is_list(vec) do
    vec
    |> Enum.map(&(&1 * &1))
    |> Enum.sum()
    |> :math.sqrt()
  end

  @doc """
  Calculates the dot product of two vectors.
  """
  @spec dot_product([number()], [number()]) :: float()
  def dot_product(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    Enum.zip_with(vec1, vec2, &(&1 * &2))
    |> Enum.sum()
  end
end
