defmodule StarweaveLlm.LLMTestHelper do
  @moduledoc """
  Helper functions for LLM-related tests.
  """
  
  defmacro __using__(_opts) do
    quote do
      import Mox
      import ExUnit.Case, except: [describe: 2]
      
      # Set up Mox
      setup :verify_on_exit!
      setup :set_mox_global
      
      # Make sure mocks are verified when the test exits
      setup do
        Mox.stub_with(HTTPoison.Base, HTTPoison.Base.Mock)
        :ok
      end
    end
  end
end
