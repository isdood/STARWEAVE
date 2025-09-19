defmodule StarweaveLlm.LLM.LLMBehaviour do
  @moduledoc """
  Defines the behaviour for LLM clients.
  
  This behaviour ensures that any LLM client implements the required functions
  to work with the Starweave system.
  """
  
  @doc """
  Sends a prompt to the LLM and returns the response.
  
  ## Parameters
    * `prompt` - The prompt to send to the LLM
    
  ## Returns
    * `{:ok, response}` - The response from the LLM
    * `{:error, reason}` - If the request fails
  """
  @callback complete(prompt :: String.t()) :: {:ok, String.t()} | {:error, any()}
  
  @doc """
  Streams a response from the LLM for the given prompt.
  
  ## Parameters
    * `prompt` - The prompt to send to the LLM
    
  ## Returns
    * A stream of response chunks
  """
  @callback stream_complete(prompt :: String.t()) :: Enumerable.t()
end
