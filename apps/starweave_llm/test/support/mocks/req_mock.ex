defmodule StarweaveLlm.Mocks.ReqMock do
  @moduledoc """
  Mox mock for the Req module.
  """
  use Mox

  @spec request(map()) :: {:ok, map()} | {:error, any()}
  def request(request) do
    case request.url do
      "http://localhost:33913/generate" ->
        # Verify the request body
        assert request.method == :post
        assert request.json == %{
          model: "llama3.1",
          prompt: "test prompt",
          temperature: 0.7,
          max_tokens: 2048,
          stream: true
        }
        
        # Return a stream of chunks
        {:ok, %{
          status: 200,
          body: [
            {:data, nil, nil, "data: {\"response\":\"Chunk 1\",\"done\":false}\n\n"},
            {:data, nil, nil, "data: {\"response\":\"Chunk 2\",\"done\":false}\n\n"},
            {:data, nil, nil, "data: {\"done\":true}\n\n"}
          ]
        }}
      _ ->
        {:error, :unexpected_url}
    end
  end
end
