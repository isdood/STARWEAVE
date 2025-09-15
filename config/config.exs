# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.

import Config

# General application configuration
config :starweave_web,
  generators: [timestamp_type: :utc_datetime]

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/starweave_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures the endpoint
config :starweave_web, StarweaveWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4500"),
    ip: {0, 0, 0, 0}
  ],
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StarweaveWeb.ErrorHTML, json: StarweaveWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Starweave.PubSub,
  live_view: [signing_salt: "51b888wU"]

# Ensure DETS data directory exists
:ok = File.mkdir_p!(Path.join([File.cwd!(), "priv", "data"]))

# Set the node name for distributed Erlang
node_name = :"starweave@127.0.0.1"
:net_kernel.start([node_name, :longnames])

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Starweave Core Configuration
config :starweave_core,
  # DETS file paths
  dets_dir: Path.join([File.cwd!(), "priv", "data"]),
  working_memory_file: "working_memory.dets",
  pattern_store_file: "patterns.dets"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
