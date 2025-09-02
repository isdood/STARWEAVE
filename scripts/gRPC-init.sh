#!/bin/bash

# Exit on any error
set -e

echo "🚀 Setting up gRPC server environment..."

# Navigate to the python services directory
cd "$(dirname "$0")/../services/python"

# Create and activate virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🔧 Creating Python virtual environment..."
    python -m venv venv
    source venv/bin/activate
    echo "✅ Virtual environment created"
    
    echo "📦 Upgrading pip..."
    pip install --upgrade pip
    
    echo "📦 Installing dependencies..."
    pip install -r requirements.txt
    
    echo "✅ Dependencies installed successfully"
else
    echo "🔍 Found existing virtual environment"
    source venv/bin/activate
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "To start the gRPC server, run:"
echo "  cd services/python && source venv/bin/activate"
echo "  python -m server.pattern_server"
echo ""
echo "The server will start in the foreground. Use Ctrl+C to stop it when needed."

# Make the script executable
chmod +x "$(dirname "$0")/gRPC-init.sh"
