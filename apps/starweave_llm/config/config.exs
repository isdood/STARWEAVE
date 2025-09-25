import Config

# Image Generation Service Configuration
config :starweave_llm, :image_generation,
  host: System.get_env("IMAGE_GENERATION_HOST", "localhost"),
  port: System.get_env("IMAGE_GENERATION_PORT", "50051") |> String.to_integer(),
  enabled: System.get_env("ENABLE_IMAGE_GENERATION", "true") == "true",
  default_model: System.get_env("DEFAULT_IMAGE_MODEL", "runwayml/stable-diffusion-v1-5"),
  default_width: System.get_env("DEFAULT_IMAGE_WIDTH", "512") |> String.to_integer(),
  default_height: System.get_env("DEFAULT_IMAGE_HEIGHT", "512") |> String.to_integer(),
  default_steps: System.get_env("DEFAULT_IMAGE_STEPS", "20") |> String.to_integer(),
  default_guidance_scale: System.get_env("DEFAULT_GUIDANCE_SCALE", "7.5") |> String.to_float(),
  timeout: System.get_env("IMAGE_GENERATION_TIMEOUT", "60000") |> String.to_integer()

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing
config :phoenix, :json_library, Jason

# Configure the gRPC client
config :grpc, start_server: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
