defmodule StarweaveLlm.Config do
  @moduledoc """
  Centralized configuration for STARWEAVE LLM components.
  """

  @doc """
  Returns the default LLM model to use.
  Can be overridden by the OLLAMA_MODEL environment variable.
  """
  @spec default_model() :: String.t()
  def default_model do
    System.get_env("OLLAMA_MODEL") || "deepseek-r1:32b"
  end

  @doc """
  Returns the default Ollama host URL.
  Can be overridden by the OLLAMA_HOST environment variable.
  """
  @spec default_host() :: String.t()
  def default_host do
    System.get_env("OLLAMA_HOST") || "http://localhost:11434"
  end

  @doc """
  Returns the default template to use for prompts.
  """
  @spec default_template() :: atom()
  def default_template, do: :default

  @doc """
  Returns whether to use memory by default.
  """
  @spec use_memory?() :: boolean()
  def use_memory?, do: true

  @doc """
  Returns the default memory limit.
  """
  @spec default_memory_limit() :: non_neg_integer()
  def default_memory_limit, do: 5
end
