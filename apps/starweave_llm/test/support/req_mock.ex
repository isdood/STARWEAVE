defmodule StarweaveLlm.ReqMock do
  @moduledoc """
  Mox mock for the Req module.
  """
  use Mox

  def request(request) do
    case request.url do
      "http://localhost:33913/generate" ->
        # This is a simplified mock response - in a real test, you'd want to
        # verify the request body and headers as well
        {:ok, %{status: 200, body: [
          {:data, nil, nil, "data: {\"response\":\"Chunk 1\",\"done\":false}\n\n"},
          {:data, nil, nil, "data: {\"response\":\"Chunk 2\",\"done\":false}\n\n"},
          {:data, nil, nil, "data: {\"done\":true}\n\n"}
        ]}}
      _ ->
        {:error, :unexpected_url}
    end
  end
end
