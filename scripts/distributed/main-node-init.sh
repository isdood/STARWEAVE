#!/bin/bash

# Main Node Initialization Script for STARWEAVE
# This script helps set up and start the main node in a distributed STARWEAVE cluster.

set -e

# Default values
DEFAULT_NODE_NAME="main"
DEFAULT_COOKIE="starweave-cookie"
DEFAULT_PORT=4545  # Changed from 4500 to 4545 to avoid conflicts
DEFAULT_ENV="dev"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")/.."
cd "$PROJECT_ROOT" || exit 1

# Function to display usage
show_help() {
    echo -e "${BLUE}STARWEAVE Main Node Initialization${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --node-name NAME   Set the node name (default: $DEFAULT_NODE_NAME)"
    echo "  -c, --cookie COOKIE    Set the Erlang cookie (default: $DEFAULT_COOKIE)"
    echo "  -p, --port PORT        Set the Phoenix HTTP port (default: $DEFAULT_PORT)"
    echo "  -e, --env ENV          Set the environment (dev/prod, default: $DEFAULT_ENV)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --node-name main --cookie my-secret-cookie --port 4000 --env prod"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--node-name)
            NODE_NAME="$2"
            shift 2
            ;;
        -c|--cookie)
            COOKIE="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set default values if not provided
NODE_NAME="${NODE_NAME:-$DEFAULT_NODE_NAME}"
COOKIE="${COOKIE:-$DEFAULT_COOKIE}"
PORT="${PORT:-$DEFAULT_PORT}"
ENV="${ENV:-$DEFAULT_ENV}"

# Use hostname for the node name
HOSTNAME=$(hostname -s)
FULL_NODE_NAME="${NODE_NAME}@${HOSTNAME}"

# Get local IP for display purposes
if [ -n "$NODE_IP" ]; then
    LOCAL_IP="$NODE_IP"
elif command -v ip &> /dev/null; then
    LOCAL_IP=$(ip route get 1 | awk '{print $7}' | head -1)
elif command -v ifconfig &> /dev/null; then
    LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
else
    LOCAL_IP="127.0.0.1"
fi

# Display configuration
echo -e "${BLUE}⚡ STARWEAVE Main Node Configuration ⚡${NC}"
echo -e "${YELLOW}Node Name:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Cookie:${NC} $COOKIE"
echo -e "${YELLOW}Port:${NC} $PORT"
echo -e "${YELLOW}Environment:${NC} $ENV"
echo -e "${YELLOW}Project Root:${NC} $PROJECT_ROOT"
echo ""

# Check if Elixir and Mix are installed
if ! command -v elixir &> /dev/null; then
    echo -e "${YELLOW}Elixir is not installed. Please install Elixir first.${NC}"
    exit 1
fi

# Handle Erlang cookie with proper permissions
echo -e "${BLUE}Setting Erlang cookie...${NC}"
COOKIE_FILE="$HOME/.erlang.cookie"

# Check if we can write to the cookie file
if [ -f "$COOKIE_FILE" ] && [ ! -w "$COOKIE_FILE" ]; then
    echo -e "${YELLOW}Warning: Cannot write to $COOKIE_FILE. Using alternative location.${NC}"
    COOKIE_FILE="/tmp/erlang.cookie.$UID"
    echo -e "${YELLOW}Using temporary cookie file at: $COOKIE_FILE${NC}"
fi

# Create or update the cookie file
if [ -f "$COOKIE_FILE" ]; then
    echo -e "${YELLOW}Warning: $COOKIE_FILE already exists. Backing it up to ${COOKIE_FILE}.bak${NC}"
    cp -f "$COOKIE_FILE" "${COOKIE_FILE}.bak" 2>/dev/null || true
fi

echo "$COOKIE" > "$COOKIE_FILE"
chmod 600 "$COOKIE_FILE" 2>/dev/null || true

# Export the cookie file location for Erlang
export ERL_EPMD_ADDRESS="0.0.0.0"  # Listen on all interfaces
export ERL_EPMD_PORT="4369"

# Set node name and cookie for distribution
export NODE_NAME="$FULL_NODE_NAME"
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE="$NODE_NAME"

# Start the Phoenix server with distributed node configuration
echo -e "${BLUE}🚀 Starting STARWEAVE Main Node...${NC}"
echo -e "${YELLOW}Node will be available at:${NC} http://${LOCAL_IP}:${PORT}"
echo -e "${YELLOW}To connect to this node:${NC} iex --sname console@${LOCAL_IP} --cookie ${COOKIE}"
echo -e "${YELLOW}To connect from another node:${NC} Node.connect(\"${NODE_NAME}@${LOCAL_IP}\")"
echo -e "${YELLOW}Using cookie file:${NC} $COOKIE_FILE"
echo ""

# Export environment variables
export MIX_ENV="$ENV"
export PORT="$PORT"

# Set the cookie file path for Erlang
export ERL_FLAGS="-setcookie \"${COOKIE}\""

# Start the Phoenix server with the distributed node name
cd "$PROJECT_ROOT/apps/starweave_web" || exit 1

echo -e "${BLUE}Starting Phoenix server with:${NC}"
echo -e "  Node name: ${GREEN}${FULL_NODE_NAME}${NC}"
echo -e "  Cookie: ${GREEN}${COOKIE}${NC}"
echo -e "  Port: ${GREEN}${PORT}${NC}"
echo -e "  Environment: ${GREEN}${ENV}${NC}"
echo ""

echo -e "${BLUE}Starting node with full name: ${GREEN}$FULL_NODE_NAME${NC}"
echo -e "${BLUE}Using cookie: ${GREEN}$COOKIE${NC}"
echo -e "${BLUE}Listening on port: ${GREEN}4545${NC}"

# Change to the web app directory
cd "$PROJECT_ROOT/apps/starweave_web" || exit 1

# Use a simple node name without IP address
NODE_NAME="main"

# Display node information
echo -e "${BLUE}Node Information:${NC}"
echo "Node Name: $FULL_NODE_NAME"
echo "Hostname: $HOSTNAME"
echo "IP Address: $LOCAL_IP"

# Start the Phoenix server directly
echo -e "${BLUE}Starting Phoenix server...${NC}"

# Change to the project root to ensure proper path resolution
cd "$PROJECT_ROOT"

# Start Phoenix with environment variables
export MIX_ENV=dev
export PORT=$PORT

# Start the server
mix phx.server

# If the server exits, show a message
echo -e "${YELLOW}STARWEAVE Main Node has stopped.${NC}"
