defmodule StarweaveCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :starweave_core,
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
      extra_applications: [:logger],
      mod: {StarweaveCore.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:libring, "~> 1.7.0", runtime: true, override: true},
      {:memento, "~> 0.3.2"},  # Mnesia wrapper for Elixir
      {:ecto_sql, "~> 3.7"},   # For Ecto integration if needed
      
      # Test dependencies
      {:meck, "~> 0.9.2", only: :test},
      
      # Development tools
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
