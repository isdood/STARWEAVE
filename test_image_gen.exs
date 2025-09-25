# test_image_gen.exs
# Run with: mix run test_image_gen.exs

alias StarweaveLlm.ImageGeneration.Client

prompt = "A beautiful sunset over a mountain lake, digital art, highly detailed, 4k"
opts = [
  width: 512,
  height: 512,
  steps: 10,
  guidance_scale: 7.5,
  model: "runwayml/stable-diffusion-v1-5"
]

# If the client is already running under the app supervision tree (mix run), use it.
# Otherwise, start a temporary instance.
IO.puts("Ensuring ImageGeneration client is running...")
unless Process.whereis(StarweaveLlm.ImageGeneration.Client) do
  {:ok, _pid} = Client.start_link(host: "localhost", port: 50051, enabled: true)
end

# Optional: brief availability check
available = Client.available?()
IO.puts("Client available?: #{inspect(available)}")

IO.puts("Requesting image from ImageGeneration service...")
case Client.generate_image(prompt, opts) do
  {:ok, image_data, metadata} ->
    out = "elixir_test_output.png"
    File.write!(out, image_data)
    IO.puts("OK! Saved image to #{out}")
    IO.puts("Metadata: #{inspect(metadata)}")

  {:error, reason} ->
    IO.puts("ERROR: #{inspect(reason)}")
    IO.puts("""
    Troubleshooting:
    - Ensure the Python gRPC server is running on localhost:50051
    - Generate Elixir protobuf modules (apps/starweave_llm/generate_protos.sh)
    - mix deps.get && mix compile
    - Try fewer steps (e.g., steps: 10) to reduce generation time
    """)
end
