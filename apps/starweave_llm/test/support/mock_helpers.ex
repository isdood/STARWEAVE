defmodule StarweaveLlm.MockHelpers do
  @moduledoc """
  Helper functions for setting up mocks in tests.
  """
  
  defmacro __using__(_opts) do
    quote do
      import Mox
      
      # Define the mock modules at compile time
      @mock_knowledge_base StarweaveLlm.MockKnowledgeBase
      @mock_embedder StarweaveLlm.MockBertEmbedder
      
      # Make sure mocks are verified when the test exits
      setup :verify_on_exit!
      
      defp setup_mocks(query, embedding, results) do
        # Set up the embedder mock
        expect(@mock_embedder, :embed, fn ^query -> 
          {:ok, embedding}
        end)
        
        # Set up the knowledge base mock
        expect(@mock_knowledge_base, :vector_search, fn _, ^embedding, _opts ->
          {:ok, results}
        end)
      end
    end
  end
end
