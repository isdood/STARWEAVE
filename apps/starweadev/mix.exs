defmodule StarweaveDev.MixProject do
  use Mix.Project

  def project do
    [
      app: :starweadev,
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

  def application do
    [
      extra_applications: [:logger],
      mod: {StarweaveDev.Application, []}
    ]
  end

  defp deps do
    [
      {:libring, "~> 1.7.0"}
    ]
  end
end
