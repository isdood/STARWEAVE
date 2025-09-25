defmodule StarweaveLlm.MixProject do
  use Mix.Project

  def project do
    [
      app: :starweave_llm,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {StarweaveLlm.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:bumblebee, "~> 0.5.0"},
      {:exla, "~> 0.7.0", only: :dev},
      {:nx, "~> 0.7.0", override: true},
      {:starweave_core, in_umbrella: true},
      {:mox, "~> 1.0", only: :test},
      
      # HTTP client for Ollama API
      {:httpoison, "~> 2.0"},
      
      # JSON encoding/decoding
      {:jason, "~> 1.4"},
      
      # gRPC and Protocol Buffers
      {:grpc, "~> 0.7.0"},
      {:protobuf, "~> 0.11.0"},
      {:google_protos, "~> 0.3"},
      
      # Connection pooling
      {:poolboy, "~> 1.5"},
      
      # Test dependencies
      {:bypass, "~> 2.1", only: :test},
      {:mimic, "~> 1.7", only: :test}
    ]
  end
end
