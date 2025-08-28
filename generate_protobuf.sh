#!/bin/bash

# Set the path to the protoc-gen-elixir plugin
PROTOC_GEN_ELIXIR_PATH="$HOME/.mix/escripts/protoc-gen-elixir"

# Create the output directory if it doesn't exist
mkdir -p lib/starweave_web/grpc/generated

# Generate Elixir code from the protobuf file
protoc \
  --plugin=protoc-gen-elixir="$PROTOC_GEN_ELIXIR_PATH" \
  --elixir_out=plugins=grpc:./lib/starweave_web/grpc/generated \
  -I./apps/starweave_web/priv/protos \
  ./apps/starweave_web/priv/protos/starweave.proto

echo "Elixir code generated in lib/starweave_web/grpc/generated"
