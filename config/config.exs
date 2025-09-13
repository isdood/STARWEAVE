# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

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

# Configure Mnesia
mnesia_dir = Path.join([File.cwd!(), "priv", "data", "mnesia"])

# Ensure Mnesia directory exists with proper permissions
:ok = File.mkdir_p!(mnesia_dir)

# Set the node name for distributed Erlang
node_name = :"starweave@127.0.0.1"
:net_kernel.start([node_name, :longnames])

# Set Mnesia directory and configuration
config :mnesia,
  dir: String.to_charlist(mnesia_dir),
  # Don't try to connect to other nodes automatically
  extra_db_nodes: [],
  # Set the schema location to disc_copies for the main node
  schema_location: :disc,
  dump_log_write_threshold: 1000,
  dc_dump_limit: 40,
  # Disable auto-connect to other nodes
  auto_repair: true

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Starweave Core Configuration
config :starweave_core, :mnesia,
  # Table configurations
  tables: [
    working_memory: [
      type: :ordered_set,
      attributes: [:id, :context, :key, :value, :metadata, :inserted_at, :updated_at],
      disc_copies: [node()],
      index: [:context, :key],
      storage_properties: []
    ],
    pattern_store: [
      type: :set,
      attributes: [:id, :pattern, :metadata, :inserted_at],
      disc_copies: [node()],
      index: [:id],
      storage_properties: []
    ]
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
