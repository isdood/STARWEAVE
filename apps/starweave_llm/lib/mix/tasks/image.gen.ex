defmodule Mix.Tasks.Image.Gen do
  use Mix.Task
  @shortdoc "Generate an image via the ImageGeneration gRPC service"

  @moduledoc """
  Generates an image by calling the Python gRPC ImageGeneration service.

  Examples:

      mix image.gen --prompt "A cozy cabin in the woods, snow" --out image.png

  Options:
  --prompt           Prompt text (required)
  --out              Output file path (default: image.png)
  --model            Model ID (default: runwayml/stable-diffusion-v1-5)
  --width            Image width (default: 512)
  --height           Image height (default: 512)
  --steps            Steps (default: 20)
  --guidance_scale   Guidance scale (default: 7.5)
  --seed             Seed (default: random)
  --style            Style tag (optional)
  --host             Service host (default: localhost)
  --port             Service port (default: 50051)
  """

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(argv,
      switches: [
        prompt: :string,
        out: :string,
        model: :string,
        width: :integer,
        height: :integer,
        steps: :integer,
        guidance_scale: :float,
        seed: :integer,
        style: :string,
        host: :string,
        port: :integer
      ]
    )

    prompt = Keyword.get(opts, :prompt)

    if is_nil(prompt) or String.trim(prompt) == "" do
      Mix.raise("--prompt is required. Example: mix image.gen --prompt 'A sunset' --out img.png")
    end

    out = Keyword.get(opts, :out, "image.png")

    width = Keyword.get(opts, :width, 512)
    height = Keyword.get(opts, :height, 512)
    steps = Keyword.get(opts, :steps, 20)
    guidance_scale = Keyword.get(opts, :guidance_scale, 7.5)

    model = Keyword.get(opts, :model, "runwayml/stable-diffusion-v1-5")
    seed = Keyword.get(opts, :seed, :rand.uniform(1_000_000))
    style = Keyword.get(opts, :style, "")

    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 50051)

    # Ensure client is running (either supervised or start a temp instance)
    alias StarweaveLlm.ImageGeneration.Client
    unless Process.whereis(StarweaveLlm.ImageGeneration.Client) do
      {:ok, _pid} = Client.start_link(host: host, port: port, enabled: true)
    end

    IO.puts("[image.gen] Generating image...")

    gen_opts = [
      width: width,
      height: height,
      steps: steps,
      guidance_scale: guidance_scale,
      seed: seed,
      style: style,
      model: model
    ]

    case Client.generate_image(prompt, gen_opts) do
      {:ok, image_data, metadata} ->
        File.write!(out, image_data)
        IO.puts("[image.gen] Saved to #{out}")
        IO.puts("[image.gen] Metadata: #{inspect(metadata)}")
      {:error, reason} ->
        Mix.raise("[image.gen] Failed: #{inspect(reason)}")
    end
  end
end
