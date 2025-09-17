defmodule StarweaveLlm.Embeddings.Behaviour do
  @moduledoc """
  Defines the behaviour for text embedding modules.
  
  This behaviour specifies the contract that all embedding implementations must follow.
  It ensures consistency across different embedding providers and makes it easy to
  swap implementations for testing or different environments.
  """

  @doc """
  Generates an embedding vector for the given text.
  
  ## Parameters
    * `text` - The input text to generate an embedding for
    
  ## Returns
    * `{:ok, embedding}` - A tuple with `:ok` and the embedding vector on success
    * `{:error, reason}` - A tuple with `:error` and a reason on failure
  """
  @callback embed(text :: String.t()) :: {:ok, [float()]} | {:error, any()}
end
