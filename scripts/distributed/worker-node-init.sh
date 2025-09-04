#!/bin/bash

# Worker Node Initialization Script for STARWEAVE
# This script helps set up and start a worker node that connects to the main STARWEAVE cluster.

set -e

# Default values
DEFAULT_NODE_NAME="worker"
DEFAULT_MAIN_NODE="main@127.0.0.1"
DEFAULT_COOKIE="starweave-cookie"
DEFAULT_DIST_PORT=9100
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
    echo -e "${BLUE}STARWEAVE Worker Node Initialization${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --node-name NAME    Set the worker node name (default: $DEFAULT_NODE_NAME)"
    echo "  -m, --main-node NODE    Set the main node address (default: $DEFAULT_MAIN_NODE)"
    echo "  -c, --cookie COOKIE     Set the Erlang cookie (default: $DEFAULT_COOKIE)"
    echo "  -p, --port PORT         Set the distribution port (default: $DEFAULT_DIST_PORT)"
    echo "  -e, --env ENV           Set the environment (dev/prod, default: $DEFAULT_ENV)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --node-name worker1 --main-node main@192.168.1.100 --cookie my-secret-cookie --port 9100"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--node-name)
            NODE_NAME="$2"
            shift 2
            ;;
        -m|--main-node)
            MAIN_NODE="$2"
            shift 2
            ;;
        -c|--cookie)
            COOKIE="$2"
            shift 2
            ;;
        -p|--port)
            DIST_PORT="$2"
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
MAIN_NODE="${MAIN_NODE:-$DEFAULT_MAIN_NODE}"
COOKIE="${COOKIE:-$DEFAULT_COOKIE}"
DIST_PORT="${DIST_PORT:-$DEFAULT_DIST_PORT}"
ENV="${ENV:-$DEFAULT_ENV}"

# Get the local IP address (works on both Linux and macOS)
if command -v ip &> /dev/null; then
    # Linux
    LOCAL_IP=$(ip route get 1 | awk '{print $7}' | head -1)
elif command -v ifconfig &> /dev/null; then
    # macOS
    LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
else
    echo -e "${YELLOW}Warning: Could not determine local IP address, using localhost${NC}"
    LOCAL_IP="127.0.0.1"
fi

FULL_NODE_NAME="${NODE_NAME}@${LOCAL_IP}"

# Display configuration
echo -e "${BLUE}⚡ STARWEAVE Worker Node Configuration ⚡${NC}"
echo -e "${YELLOW}Node Name:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Main Node:${NC} $MAIN_NODE"
echo -e "${YELLOW}Cookie:${NC} $COOKIE"
echo -e "${YELLOW}Distribution Port:${NC} $DIST_PORT"
echo -e "${YELLOW}Environment:${NC} $ENV"
echo -e "${YELLOW}Project Root:${NC} $PROJECT_ROOT"
echo ""

# Check if Elixir is installed
if ! command -v elixir &> /dev/null; then
    echo -e "${YELLOW}Elixir is not installed. Please install Elixir first.${NC}"
    exit 1
fi

# Handle Erlang cookie with proper permissions
echo -e "${BLUE}Setting Erlang cookie...${NC}"
COOKIE_FILE="/tmp/erlang.cookie.$UID"

# Create or update the cookie file
if [ -f "$COOKIE_FILE" ]; then
    echo -e "${YELLOW}Warning: $COOKIE_FILE already exists. Backing it up to ${COOKIE_FILE}.bak${NC}"
    cp -f "$COOKIE_FILE" "${COOKIE_FILE}.bak" 2>/dev/null || true
fi

echo "$COOKIE" > "$COOKIE_FILE"
chmod 600 "$COOKIE_FILE" 2>/dev/null || true

# Export the cookie file location for Erlang
export ERL_EPMD_ADDRESS="$LOCAL_IP"
export ERL_EPMD_PORT="4369"

# Start the worker node
echo -e "${BLUE}🚀 Starting STARWEAVE Worker Node...${NC}"
echo -e "${YELLOW}Node Name:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Connecting to Main Node:${NC} $MAIN_NODE"
echo -e "${YELLOW}Using cookie file:${NC} $COOKIE_FILE"
echo -e "${YELLOW}Distribution Port:${NC} $DIST_PORT"
echo ""

# Export environment variables
export MIX_ENV="$ENV"
export ERL_FLAGS="-setcookie \"${COOKIE}\""

# Start the worker node
echo -e "${BLUE}Starting worker node with:${NC}"
echo -e "  Node name: ${GREEN}${FULL_NODE_NAME}${NC}"
echo -e "  Main node: ${GREEN}${MAIN_NODE}${NC}"
echo -e "  Cookie: ${GREEN}${COOKIE}${NC}"
echo -e "  Environment: ${GREEN}${ENV}${NC}"
echo -e "  Distribution port: ${GREEN}${DIST_PORT}${NC}"
echo ""

# Change to the worker app directory
cd "$PROJECT_ROOT/apps/starweave_core" || exit 1

# Start the worker node
elixir \
  --name "$FULL_NODE_NAME" \
  --cookie "$COOKIE" \
  --erl "-kernel inet_dist_listen_min $DIST_PORT" \
  --erl "-kernel inet_dist_listen_max $DIST_PORT" \
  -S mix run --no-halt \
  -e "
    # Connect to the main node
    IO.puts(\"⏳ Connecting to main node: $MAIN_NODE\")
    main_node = String.to_atom(\"$MAIN_NODE\")
    case Node.connect(main_node) do
      true ->
        IO.puts(\"✅ Successfully connected to $MAIN_NODE\")
        :ok = :net_kernel.monitor_nodes(true, node_type: :all)
        IO.puts(\"🔍 Monitoring node status...\")
      _ ->
        IO.puts(\"❌ Failed to connect to $MAIN_NODE\")
        System.halt(1)
    end

    # Keep the node alive
    Process.flag(:trap_exit, true)
    receive do
      {:nodeup, node, _info} -> 
        IO.puts(\"\n🟢 Node connected: #{inspect(node)}\")
      {:nodedown, node, _info} -> 
        IO.puts(\"\n🔴 Node disconnected: #{inspect(node)}\")
        if node == \"$MAIN_NODE\" do
          IO.puts(\"\n⚠️  Main node disconnected. Shutting down...\")
          System.halt(0)
        end
    after
      1_000 -> :ok
    end

    # Keep the node alive
    Process.sleep(:infinity)
  "
