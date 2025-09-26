#!/bin/bash
# Setup script for protoc-gen-elixir environment

# Find the latest Elixir version installed with asdf
ELIXIR_VERSION=$(asdf current elixir | awk '{print $2}' | sed 's/\x1b\[[0-9;]*m//g')
ESCRIPT_PATH="$HOME/.asdf/installs/elixir/$ELIXIR_VERSION/.mix/escripts"

# Add to PATH if not already present
if [[ ":$PATH:" != *":$ESCRIPT_PATH:"* ]]; then
    echo "Adding $ESCRIPT_PATH to PATH"
    echo "export PATH=\"$ESCRIPT_PATH:\$PATH\"" >> ~/.bashrc
    export PATH="$ESCRIPT_PATH:$PATH"
fi

# Install protobuf if not installed
if ! command -v protoc-gen-elixir &> /dev/null; then
    echo "Installing protobuf escript..."
    mix escript.install hex protobuf --force
fi

echo "Environment setup complete. Run 'source ~/.bashrc' or restart your shell."
echo "Verify with: which protoc-gen-elixir"
