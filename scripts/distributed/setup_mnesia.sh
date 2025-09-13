#!/bin/bash

# Mnesia setup script for STARWEAVE
# This script helps set up and verify Mnesia directories and permissions

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MNESIA_DIR="$BASE_DIR/priv/mnesia"

# Create directories if they don't exist
create_directories() {
    echo -e "${YELLOW}Creating Mnesia directories...${NC}"
    mkdir -p "$MNESIA_DIR/main"
    mkdir -p "$MNESIA_DIR/worker"
    
    # Set permissions
    chmod -R 755 "$MNESIA_DIR"
    
    echo -e "${GREEN}✓ Created Mnesia directories:${NC}"
    echo "  - Main node:   $MNESIA_DIR/main"
    echo "  - Worker node: $MNESIA_DIR/worker"
}

# Verify directory structure and permissions
verify_setup() {
    echo -e "\n${YELLOW}Verifying Mnesia setup...${NC}"
    
    # Check if directories exist
    if [ ! -d "$MNESIA_DIR/main" ] || [ ! -d "$MNESIA_DIR/worker" ]; then
        echo "❌ Error: Mnesia directories not found. Please run setup first."
        exit 1
    fi
    
    # Check permissions
    if [ ! -w "$MNESIA_DIR" ]; then
        echo "❌ Error: No write permissions for $MNESIA_DIR"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Mnesia setup verified successfully${NC}"
    echo -e "\nYou can now start the nodes:"
    echo "1. Start main node:   ./scripts/distributed/start-main-node.sh"
    echo "2. Start worker node: ./scripts/distributed/start-worker-node.sh"
}

# Clean up Mnesia data
cleanup() {
    echo -e "${YELLOW}Cleaning up Mnesia data...${NC}"
    
    if [ -d "$MNESIA_DIR/main" ]; then
        rm -rf "$MNESIA_DIR/main"/*
        echo "✓ Cleared main node data"
    fi
    
    if [ -d "$MNESIA_DIR/worker" ]; then
        rm -rf "$MNESIA_DIR/worker"/*
        echo "✓ Cleared worker node data"
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Show help
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup     Create Mnesia directories and set permissions"
    echo "  verify    Verify Mnesia setup"
    echo "  clean     Remove existing Mnesia data"
    echo "  help      Show this help message"
    echo ""
    echo "If no command is provided, 'setup' will be executed by default."
}

# Main script
execute() {
    case "$1" in
        setup)
            create_directories
            ;;
        verify)
            verify_setup
            ;;
        clean)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            create_directories
            verify_setup
            ;;
    esac
}

# Make the script executable
chmod +x "$0"

# Execute the command
if [ "$1" = "--self-install" ]; then
    # Make the script globally available
    sudo ln -sf "$0" "/usr/local/bin/setup-mnesia"
    echo "✓ Installed as 'setup-mnesia'"
else
    execute "$1"
fi
