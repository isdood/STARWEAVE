#!/bin/bash

# Main Node Initialization Script for STARWEAVE
# Simplified version with better error handling and EPMD management

set -e

# Default values
DEFAULT_NODE_NAME="main"
DEFAULT_COOKIE="starweave-cookie"
DEFAULT_PORT=4545
DEFAULT_ENV="dev"

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
    echo -e "${BLUE}STARWEAVE Main Node Initialization${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --node-name NAME   Set the node name (default: $DEFAULT_NODE_NAME)"
    echo "  -c, --cookie COOKIE    Set the Erlang cookie (default: $DEFAULT_COOKIE)"
    echo "  -p, --port PORT        Set the HTTP port (default: $DEFAULT_PORT)"
    echo "  -e, --env ENV          Set the environment (dev/prod, default: $DEFAULT_ENV)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --node-name main --cookie my-secret-cookie --port 4000 --env prod"
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

# Function to check if EPMD is running
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

# Get hostname and IP
HOSTNAME=$(hostname -s)
LOCAL_IP=$(get_local_ip)
FULL_NODE_NAME="${NODE_NAME}@${HOSTNAME}"

# Display configuration
echo -e "${BLUE}⚡ STARWEAVE Main Node Configuration ⚡${NC}"
echo -e "${YELLOW}Node Name:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}IP Address:${NC} $LOCAL_IP"
echo -e "${YELLOW}Cookie:${NC} $COOKIE"
echo -e "${YELLOW}Port:${NC} $PORT"
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

# Export environment variables
export MIX_ENV="$ENV"
export PORT="$PORT"
export RELEASE_DISTRIBUTION="name"
export RELEASE_NODE="$FULL_NODE_NAME"

# Set Erlang distribution settings
export ERL_EPMD_ADDRESS="0.0.0.0"
export ERL_EPMD_PORT="4369"

# Generate ERL_FLAGS with proper escaping for distribution
dist_port=$((PORT + 1))  # Use next port for distribution
export ERL_FLAGS="-setcookie \"$COOKIE\""
ERL_FLAGS+=" -kernel inet_dist_listen_min $dist_port"
ERL_FLAGS+=" -kernel inet_dist_listen_max $((dist_port + 10))"
ERL_FLAGS+=" -kernel inet_dist_use_interface \"{0,0,0,0}\""
ERL_FLAGS+=" -sname \"$NODE_NAME\""
ERL_FLAGS+=" -start_epmd false"  # We manage EPMD ourselves

export ERL_FLAGS

# Change to the web app directory
cd "$PROJECT_ROOT/apps/starweave_web" || exit 1

# Display startup information
echo -e "${BLUE}🚀 Starting STARWEAVE Main Node...${NC}"
echo -e "${YELLOW}Node:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}EPMD:${NC} Running on port 4369"
echo -e "${YELLOW}Distribution Ports:${NC} $dist_port-$((dist_port + 10))"
echo -e "${YELLOW}Web Interface:${NC} http://${LOCAL_IP}:${PORT}"
echo -e "${YELLOW}To connect to this node:${NC}"
echo -e "  iex --sname console@${HOSTNAME} --cookie ${COOKIE}"
echo -e "${YELLOW}To connect from another node:${NC}"
echo -e "  Node.connect(\"${NODE_NAME}@${HOSTNAME}\")"
echo

# Start the Phoenix server
echo -e "${BLUE}Starting Phoenix server...${NC}"

exec mix phx.server
