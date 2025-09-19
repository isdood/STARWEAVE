defmodule StarweaveLlm.MockHTTPoison do
  @moduledoc """
  Mock HTTPoison client for testing.
  """
  @behaviour HTTPoison.Base

  @impl true
  def process_request_headers(headers) do
    headers
  end

  @impl true
  def process_response_body(body) do
    body
  end

  @impl true
  def process_request_body(body) do
    body
  end

  @impl true
  def process_request_url(url) do
    url
  end

  @impl true
  def process_response_headers(headers) do
    headers
  end

  @impl true
  def process_status_code(status_code) do
    status_code
  end
end
