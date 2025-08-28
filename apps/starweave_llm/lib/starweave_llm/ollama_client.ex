defmodule StarweaveLlm.OllamaClient do
  @moduledoc """
  Minimal Ollama HTTP client for chat completions.
  """
  require Logger

  @type opts :: [model: String.t(), host: String.t()]

  @spec chat(String.t(), opts()) :: {:ok, String.t()} | {:error, term()}
  def chat(prompt, opts \\ []) when is_binary(prompt) do
    host = Keyword.get(opts, :host, System.get_env("OLLAMA_HOST") || "http://localhost:11434")
    model = Keyword.get(opts, :model, System.get_env("OLLAMA_MODEL") || "llama3.1")

    url = host |> URI.parse() |> URI.merge("/api/chat") |> URI.to_string()
    body = %{
      model: model,
      messages: [
        %{role: "system", content: "You are STARWEAVE. Be concise and helpful."},
        %{role: "user", content: prompt}
      ],
      stream: false
    }

    case Req.post(url: url, json: body, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end


