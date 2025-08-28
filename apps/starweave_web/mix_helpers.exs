defmodule Mix.Tasks.Compile.Protobuf do
  use Mix.Task.Compiler
  
  @moduledoc """
  Custom task to compile .proto files to Elixir modules using protoc.
  """
  
  @proto_dir "priv/protos"
  @output_dir "lib/starweave_web/grpc"
  
  @impl true
  def run(_args) do
    File.mkdir_p!(@output_dir)
    
    proto_files = Path.wildcard(Path.join(@proto_dir, "*.proto"))
    
    if proto_files == [] do
      Mix.shell().info("No .proto files found in #{@proto_dir}")
      return :noop
    end
    
    # Install protoc-gen-elixir if not installed
    unless System.find_executable("protoc-gen-elixir") do
      Mix.shell().info("Installing protoc-gen-elixir...")
      System.cmd("mix", ["escript.install", "hex", "protobuf"]) 
    end
    
    # Compile each .proto file
    Enum.each(proto_files, fn proto_file ->
      Mix.shell().info("Compiling #{Path.relative_to_cwd(proto_file)}")
      
      # Create output directory structure
      relative_path = Path.relative_to(proto_file, @proto_dir) |> Path.rootname()
      module_dir = Path.join(@output_dir, Path.dirname(relative_path))
      File.mkdir_p!(module_dir)
      
      # Run protoc
      protoc_args = [
        "--elixir_out=plugins=grpc:#{@output_dir}",
        "-I#{@proto_dir}",
        "--elixir_opt=package_prefix=starweave",
        "--elixir_opt=one_file_per_module=true",
        proto_file
      ]
      
      case System.cmd("protoc", protoc_args, stderr_to_stdout: true) do
        {output, 0} ->
          Mix.shell().info(output)
          :ok
          
        {error, _} ->
          Mix.raise("Failed to compile #{proto_file}: #{error}")
      end
    end)
    
    :ok
  end
end
