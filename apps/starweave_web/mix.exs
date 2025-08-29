defmodule StarweaveWeb.MixProject do
  use Mix.Project

  @version "0.1.0"
  @elixir_version "~> 1.15"

  def project do
    [
      app: :starweave_web,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: @elixir_version,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {StarweaveWeb.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :gettext, :starweave_core, :starweave_llm]
    ]
  end

  # CLI configuration is now handled in the project configuration above

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Dependencies
      {:starweave_core, in_umbrella: true},
      
      # Phoenix
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto, "~> 3.11.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},

      # Core dependencies
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # gRPC and Protocol Buffers
      {:grpc, "~> 0.7.0", override: true},
      {:protobuf, "~> 0.11.0"},
      {:google_protos, "~> 0.3"},
      # Required for gRPC client transport
      {:gun, "~> 2.0", override: true},
      # Required by Gun
      {:cowlib, "~> 2.12", override: true},

      # Development & Test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:floki, ">= 0.30.0", only: :test},

      # Umbrella apps
      {:starweave_core, in_umbrella: true},
      {:starweave_llm, in_umbrella: true},

      # Testing
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mox, "~> 1.0", only: :test},

      # HTTP Server
      {:bandit, "~> 1.5"},
      {:gettext, "~> 0.20"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"],
      "protobuf.gen": [
        "cmd protoc --elixir_out=plugins=grpc:lib/starweave_web/grpc -Ipriv/protos priv/protos/starweave.proto"
      ],
      "protoc.gen": ["protobuf.gen"]
    ]
  end
end
