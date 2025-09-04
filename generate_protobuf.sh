#!/bin/bash

# Ensure we fail on any error
set -e

# Set the path to the protoc-gen-elixir plugin
PROTOC_GEN_ELIXIR_PATH="$HOME/.mix/escripts/protoc-gen-elixir"

# Create the output directories if they don't exist
mkdir -p lib/starweave_web/grpc/generated

# Generate Elixir code from the protobuf file using the latest gRPC plugin
echo "Generating Elixir code from protobuf..."
protoc \
  --elixir_out=gen_descriptors=true:./lib/starweave_web/grpc/generated \
  --elixir_opt=package_prefix=starweave_web.grpc \
  --elixir_opt=transform_module=StarweaveWeb.Grpc.TransformModule \
  -I./apps/starweave_web/priv/protos \
  ./apps/starweave_web/priv/protos/starweave.proto

# Generate gRPC service code
echo "Generating gRPC service code..."
protoc \
  --elixir_out=plugins=grpc,gen_descriptors=true:./lib/starweave_web/grpc/generated \
  --elixir_opt=package_prefix=starweave_web.grpc \
  -I./apps/starweave_web/priv/protos \
  ./apps/starweave_web/priv/protos/starweave.proto

# Fix any deprecation warnings in the generated code
echo "Fixing deprecation warnings..."
find lib/starweave_web/grpc/generated -name "*.ex" -type f -exec sed -i.bak 's/\.\([a-zA-Z0-9_]*\)\((\[\]\)/\1()/g' {} \;
find lib/starweave_web/grpc/generated -name "*.bak" -delete

echo -e "\n✅ Successfully generated and fixed gRPC code in lib/starweave_web/grpc/generated"
