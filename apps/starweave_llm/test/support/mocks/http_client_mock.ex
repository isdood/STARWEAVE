defmodule HTTPoisonMock do
  @moduledoc """
  Mock implementation of HTTPoison for testing.
  """
  
  @behaviour HTTPoison.Base
  
  @impl true
  def request(method, url, body, headers, opts) do
    cond do
      # Handle the default case
      method == :post and url == "http://localhost:11434/api/generate" and 
      body == "{\"model\":\"llama3.1\",\"prompt\":\"test prompt\",\"temperature\":0.7,\"max_tokens\":2048,\"stream\":false}" ->
        {:ok, %HTTPoison.Response{
          status_code: 200,
          body: """
          {
            "model": "llama3.1",
            "created_at": "2023-05-12T23:08:45.000Z",
            "response": "This is a test response",
            "done": true
          }
          """,
          headers: []
        }}
      
      # Handle custom model case
      method == :post and url == "http://localhost:11434/api/generate" and 
      body =~ ~s("model":"custom-model") ->
        {:ok, %HTTPoison.Response{
          status_code: 200,
          body: """
          {
            "model": "custom-model",
            "response": "Custom model response",
            "done": true
          }
          """,
          headers: []
        }}
      
      # Handle error cases
      true ->
        {:ok, %HTTPoison.Response{status_code: 500, body: "Internal Server Error"}}
    end
  end
  
  @impl true
  def post(url, body, headers, opts) do
    {:ok, %HTTPoison.AsyncResponse{id: make_ref()}}
  end
end
