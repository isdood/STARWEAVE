#!/bin/bash
set -euo pipefail

# Ensure protoc is available
if ! command -v protoc >/dev/null 2>&1; then
  echo "Error: protoc not found. Please install the Protocol Buffers compiler (protoc)." >&2
  echo "  Debian/Ubuntu: sudo apt-get install -y protobuf-compiler" >&2
  exit 1
fi

# Ensure protoc-gen-elixir is available (installed via: mix escript.install hex protobuf)
export PATH="$HOME/.mix/escripts:$PATH"
if ! command -v protoc-gen-elixir >/dev/null 2>&1; then
  echo "Error: protoc-gen-elixir not found in PATH." >&2
  echo "  Install with: mix escript.install hex protobuf --force" >&2
  echo "  Then re-run this script." >&2
  exit 1
fi

# Resolve script directory and run from there so relative paths work regardless of CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Paths (relative to apps/starweave_llm)
OUT_DIR="lib/starweave_llm/image_generation/generated"
# Use Python service proto as the single source of truth
PROTO_DIR="../../services/python/protos"
GOOGLE_PROTO_DIR="../../deps/google_protos/priv/protos"

# Create the output directory if it doesn't exist
mkdir -p "$OUT_DIR"

echo "Generating Elixir code from protobuf..."
CMD=(protoc --elixir_out=plugins=grpc:"$OUT_DIR" -I"$PROTO_DIR")

# Add google protos include if available
if [ -d "$GOOGLE_PROTO_DIR" ]; then
  CMD+=(-I"$GOOGLE_PROTO_DIR" google/protobuf/timestamp.proto)
fi

CMD+=("$PROTO_DIR/starweave.proto")

"${CMD[@]}"

echo "✅ Protobuf files generated in $OUT_DIR"
