#!/bin/bash

# Create generated directory if it doesn't exist
mkdir -p generated

# Generate Python code from proto files
python -m grpc_tools.protoc -I. --python_out=generated --pyi_out=generated --grpc_python_out=generated protos/starweave.proto

# Fix import paths in generated files
sed -i 's/import starweave_pb2/from . import starweave_pb2/g' generated/starweave_pb2_grpc.py

echo "Protobuf files regenerated successfully!"
