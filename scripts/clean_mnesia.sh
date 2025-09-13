#!/bin/bash

# Stop any running Mnesia nodes
echo "Stopping any running Mnesia nodes..."
epmd -kill 2>/dev/null || true

# Clean up Mnesia data
echo "Cleaning Mnesia data..."
MNE_DIR="$(pwd)/priv/data/mnesia"
rm -rf "$MNE_DIR"/*

# Ensure the directory exists
mkdir -p "$MNE_DIR"

echo "Mnesia data cleaned successfully"
