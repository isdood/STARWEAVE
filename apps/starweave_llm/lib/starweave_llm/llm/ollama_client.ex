defmodule StarweaveLlm.LLM.OllamaClient do
  @moduledoc """
  Client for interacting with the Ollama API.
  """
  
  require Logger
  
  @default_model "llama3.1"
  @default_base_url "http://localhost:11434"
  
  @doc """
  Returns the base URL for the Ollama API.
  """
  def base_url do
    Application.get_env(:starweave_llm, :ollama_base_url, @default_base_url)
  end
  
  @doc """
  Sends a completion request to the Ollama API.
  
  ## Parameters
    * `prompt` - The prompt to send to the model
    * `opts` - Additional options
      * `:model` - The model to use (default: "llama3.1")
      * `:temperature` - Controls randomness (0.0 to 1.0)
      * `:max_tokens` - Maximum number of tokens to generate
  """
  @spec complete(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def complete(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)
    
    url = "#{base_url()}/api/generate"
    
    case Req.post(url, 
          json: %{
            model: model,
            prompt: prompt,
            temperature: temperature,
            max_tokens: max_tokens,
            stream: false
          },
          receive_timeout: 30_000
        ) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case body do
          %{"response" => response} when is_binary(response) ->
            {:ok, String.trim(response)}
          %{response: response} when is_binary(response) ->
            {:ok, String.trim(response)}
          _ ->
            {:error, :invalid_response_format}
        end
        
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"response" => response}} when is_binary(response) ->
            {:ok, String.trim(response)}
          {:ok, %{response: response}} when is_binary(response) ->
            {:ok, String.trim(response)}
          {:ok, _} ->
            {:error, :invalid_response_format}
          {:error, reason} ->
            if Mix.env() == :test do
              Logger.debug("Failed to parse response: #{inspect(reason)}")
            else
              Logger.error("Failed to parse response: #{inspect(reason)}")
            end
            {:error, :invalid_json}
        end
        
      {:ok, %{status: status, body: body}} ->
        error_message = 
          case body do
            %{"error" => msg} when is_binary(msg) -> msg
            %{error: msg} when is_binary(msg) -> msg
            _ -> inspect(body)
          end
          
        if Mix.env() == :test do
          Logger.debug("Ollama API error: #{status} - #{error_message}")
        else
          Logger.error("Ollama API error: #{status} - #{error_message}")
        end
        {:error, {:http_error, status, error_message}}
        
      {:error, %{reason: reason}} ->
        if Mix.env() == :test do
          Logger.debug("HTTP error: #{inspect(reason)}")
        else
          Logger.error("HTTP error: #{inspect(reason)}")
        end
        {:error, reason}
        
      {:error, reason} ->
        if Mix.env() == :test do
          Logger.debug("Request error: #{inspect(reason)}")
        else
          Logger.error("Request error: #{inspect(reason)}")
        end
        {:error, reason}
    end
  end
  
  @doc """
  Streams a completion from the Ollama API.
  
  Returns a stream of chunks that can be processed as they arrive.
  """
  @spec stream_complete(String.t(), keyword()) :: Enumerable.t()
  def stream_complete(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)
    
    url = "#{base_url()}/api/generate"
    if Mix.env() != :test do
      Logger.debug("Starting streaming request to #{url}")
    end

    Stream.resource(
      # Start function - makes the request
      fn ->
        request = %{
          model: model,
          prompt: prompt,
          temperature: temperature,
          max_tokens: max_tokens,
          stream: true
        }
        
        # Start the request and get the stream
        case Req.post(url, 
          json: request,
          receive_timeout: :infinity,
          into: []
        ) do
          {:ok, %{status: 200, body: chunks}} ->
            if Mix.env() != :test do
              Logger.debug("Received #{length(chunks)} chunks")
            end
            chunks
            
          {:ok, response} ->
            if Mix.env() != :test do
              Logger.error("Unexpected response: #{inspect(response)}")
            end
            []
            
          {:error, reason} ->
            if Mix.env() != :test do
              Logger.error("Request failed: #{inspect(reason)}")
            end
            []
        end
      end,
      
      # Process function - handles the response chunks
      fn chunks ->
        case chunks do
          [] ->
            {:halt, []}
            
          [chunk | rest] ->
            responses = 
              case chunk do
                chunk when is_binary(chunk) ->
                  chunk
                  |> String.split("\n\n", trim: true)
                  |> Enum.flat_map(fn event ->
                    case parse_chunk(event) do
                      {:ok, %{"response" => response, "done" => false}} ->
                        [response]
                        
                      {:ok, %{"done" => true}} ->
                        []
                        
                      _ ->
                        []
                    end
                  end)
                  
                _ ->
                  []
              end
            
            {responses, rest}
          end
        end,
      
      # After function - cleanup
      fn _ ->
        Logger.debug("Stream processing completed")
        :ok
      end
    )
  end
  
  # This function is no longer used but kept for reference
  # The streaming implementation has been moved to the stream_complete/2 function
  
  defp parse_chunk(chunk) when is_binary(chunk) do
    case String.split(chunk, "data: ", parts: 2, trim: true) do
      ["", json] ->
        case Jason.decode(json) do
          {:ok, %{"response" => response}} ->
            Logger.debug("Got response: #{inspect(response)}")
            {:ok, %{"response" => response, "done" => false}}
            
          {:ok, %{"done" => true}} ->
            Logger.debug("Got done signal")
            {:ok, %{"done" => true}}
            
          {:ok, %{"error" => error}} ->
            Logger.error("Error from Ollama API: #{inspect(error)}")
            {:error, :api_error, error}
            
          {:ok, other} ->
            Logger.warning("Unexpected JSON structure: #{inspect(other, limit: :infinity)}")
            {:error, :invalid_format, other}
            
          {:error, reason} ->
            Logger.error("Failed to parse JSON: #{inspect(reason)}")
            {:error, :json_parse_error, reason}
        end
        
      _ ->
        Logger.warning("Unexpected chunk format: #{inspect(chunk, limit: :infinity)}")
        {:error, :invalid_format, chunk}
    end
  end
  
  defp parse_chunk(chunk) when is_map(chunk) do
    Logger.debug("Processing map chunk: #{inspect(chunk, limit: :infinity)}")
    
    cond do
      Map.has_key?(chunk, "response") ->
        Logger.debug("Got map response: #{inspect(chunk["response"], limit: :infinity)}")
        {:ok, %{"response" => chunk["response"], "done" => Map.get(chunk, "done", false)}}
        
      Map.get(chunk, "done", false) ->
        Logger.debug("End of stream (map)")
        {:ok, %{"done" => true}}
        
      true ->
        Logger.warning("Unexpected map structure: #{inspect(chunk, limit: :infinity)}")
        {:error, :invalid_format, chunk}
    end
  end
  
  defp parse_chunk(other) do
    Logger.warning("Unexpected chunk type: #{inspect(other, limit: :infinity)}")
    {:error, :unsupported_chunk_type, other}
  end
end
