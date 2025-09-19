defmodule StarweaveLlm.SelfKnowledge.KnowledgeBase.Mock do
  @moduledoc """
  Mock implementation of the KnowledgeBase for testing.
  """
  
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  
  # Add any mock implementations needed for testing
  def search(_, _, _), do: {:ok, []}
  def add_document(_, _), do: :ok
  def get_document(_, _), do: {:error, :not_found}
end
