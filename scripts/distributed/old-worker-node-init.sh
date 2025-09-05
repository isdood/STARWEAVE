#!/bin/bash

# Worker Node Initialization Script for STARWEAVE
# Optimized for cross-PC distributed setup

set -euo pipefail

# Default values
DEFAULT_NODE_NAME="worker"
DEFAULT_MAIN_IP="192.168.0.47"
DEFAULT_MAIN_HTTP_PORT=4000
DEFAULT_MAIN_DIST_PORT=9000
DEFAULT_COOKIE="starweave-cookie"
DEFAULT_DIST_PORT=9100
DEFAULT_ENV="dev"
DEFAULT_INTERFACE="eth0"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
    echo "  -i, --main-ip IP        Set the main node IP address (default: $DEFAULT_MAIN_IP)"
    echo "  -p, --http-port PORT    Set the main node HTTP port (default: $DEFAULT_MAIN_HTTP_PORT)"
    echo "  -d, --dist-port PORT    Set the main node distribution port (default: $DEFAULT_MAIN_DIST_PORT)"
    echo "  -w, --worker-port PORT  Set the worker node distribution port (default: $DEFAULT_DIST_PORT)"
    echo "  -c, --cookie COOKIE     Set the Erlang cookie (default: $DEFAULT_COOKIE)"
    echo "  -e, --env ENV           Set the environment (dev/prod, default: $DEFAULT_ENV)"
    echo "  -I, --interface IFACE   Set the network interface (default: $DEFAULT_INTERFACE)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --node-name worker1 --main-ip 192.168.1.100 --http-port 4000 --dist-port 9000"
}

# Function to get local IP
get_local_ip() {
    if [ -n "$NODE_IP" ]; then
        echo "$NODE_IP"
    elif command -v ip &> /dev/null; then
        ip route get 1 | awk '{print $7}' | head -1
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1
    else
        echo "127.0.0.1"
    fi
}

# Function to check EPMD
check_epmd() {
    if ! command -v epmd &> /dev/null; then
        echo -e "${RED}Error: epmd (Erlang Port Mapper Daemon) not found in PATH${NC}"
        exit 1
    fi
    
    # Check if EPMD is already running
    if pgrep -x "epmd" > /dev/null; then
        echo -e "${YELLOW}Warning: EPMD is already running${NC}"
        return 0
    fi
    
    # Start EPMD if not running
    echo -e "${BLUE}Starting EPMD...${NC}"
    if ! epmd -daemon; then
        echo -e "${RED}Failed to start EPMD${NC}"
        exit 1
    fi
    
    # Verify EPMD is running
    if ! epmd -names &> /dev/null; then
        echo -e "${RED}EPMD failed to start properly${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}EPMD started successfully${NC}"
}

# Function to set up Erlang cookie
setup_cookie() {
    local cookie="$1"
    local cookie_file="$HOME/.erlang.cookie"
    
    # Create cookie file if it doesn't exist
    if [ ! -f "$cookie_file" ]; then
        echo "$cookie" > "$cookie_file"
        chmod 600 "$cookie_file"
        echo -e "${GREEN}Created Erlang cookie file at $cookie_file${NC}"
    else
        local current_cookie=$(cat "$cookie_file" 2>/dev/null || echo "")
        if [ "$current_cookie" != "$cookie" ]; then
            echo -e "${YELLOW}Warning: Existing Erlang cookie in $cookie_file does not match specified cookie${NC}"
            echo -e "  Current: $current_cookie"
            echo -e "  Specified: $cookie"
            read -p "  Do you want to update the cookie? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$cookie" > "$cookie_file"
                chmod 600 "$cookie_file"
                echo -e "${GREEN}Updated Erlang cookie${NC}"
            fi
        fi
    fi
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

# Get hostname and IP
HOSTNAME=$(hostname -s)
LOCAL_IP=$(get_local_ip)
FULL_NODE_NAME="${NODE_NAME}@${HOSTNAME}"

# Extract main node hostname
MAIN_NODE_HOST=${MAIN_NODE#*@}

# Display configuration
echo -e "${BLUE}⚡ STARWEAVE Worker Node Configuration ⚡${NC}"
echo -e "${YELLOW}Node Name:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Main Node:${NC} $MAIN_NODE"
echo -e "${YELLOW}IP Address:${NC} $LOCAL_IP"
echo -e "${YELLOW}Cookie:${NC} $COOKIE"
echo -e "${YELLOW}Distribution Port:${NC} $DIST_PORT"
echo -e "${YELLOW}Environment:${NC} $ENV"
echo -e "${YELLOW}Project Root:${NC} $PROJECT_ROOT"
echo

# Check for required commands
for cmd in elixir mix epmd; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed or not in PATH${NC}"
        exit 1
    fi
done

# Set up Erlang cookie
setup_cookie "$COOKIE"

# Check and start EPMD
check_epmd

# Check connection to main node
echo -e "${BLUE}Checking connection to main node at ${MAIN_NODE}...${NC}"
if ! nc -z -w 5 "$MAIN_NODE_HOST" 4369; then
    echo -e "${YELLOW}Warning: Cannot connect to EPMD on $MAIN_NODE_HOST:4369${NC}"
    echo -e "${YELLOW}Please ensure the main node is running and accessible.${NC}"
    echo -e "${YELLOW}If the main node is behind a firewall, make sure port 4369 (EPMD) is open.${NC}"
    exit 1
fi

# Export environment variables
export MIX_ENV="$ENV"

# Set Erlang distribution settings
export ERL_EPMD_ADDRESS="0.0.0.0"
export ERL_EPMD_PORT="4369"

# Generate ERL_FLAGS with proper escaping for distribution
export ERL_FLAGS="-setcookie \"$COOKIE\""
ERL_FLAGS+=" -kernel inet_dist_listen_min $DIST_PORT"
ERL_FLAGS+=" -kernel inet_dist_listen_max $((DIST_PORT + 10))"
ERL_FLAGS+=" -kernel inet_dist_use_interface \"{0,0,0,0}\""
ERL_FLAGS+=" -sname \"$NODE_NAME\""
ERL_FLAGS+=" -start_epmd false"  # We manage EPMD ourselves

export ERL_FLAGS

# Change to the web app directory
cd "$PROJECT_ROOT/apps/starweave_web" || exit 1

# Display startup information
echo -e "${BLUE}🚀 Starting STARWEAVE Worker Node...${NC}"
echo -e "${YELLOW}Node:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Connecting to Main Node:${NC} $MAIN_NODE"
echo -e "${YELLOW}EPMD:${NC} Running on port 4369"
echo -e "${YELLOW}Distribution Ports:${NC} $DIST_PORT-$((DIST_PORT + 10))"
echo -e "${YELLOW}To connect to this node:${NC}"
echo -e "  iex --sname console@${HOSTNAME} --cookie ${COOKIE}"
echo -e "${YELLOW}To connect from another node:${NC}"
echo -e "  Node.connect(\"${NODE_NAME}@${HOSTNAME}\")"
echo

# Start the worker node
echo -e "${BLUE}Starting worker node and connecting to main node...${NC}"

exec iex \
  --sname $NODE_NAME \
  --cookie "$COOKIE" \
  --erl "-start_epmd false -epmd_module Elixir.IEx.EPMD.Client -proto_dist Elixir.IEx.Distribution.Client.ERL_EPMD_DIST" \
  -S mix phx.server
