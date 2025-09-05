#!/bin/bash

# Main Node Initialization Script for STARWEAVE
# Optimized for cross-PC distributed setup

set -euo pipefail

# Default values
DEFAULT_NODE_NAME="main"
DEFAULT_COOKIE="starweave-cookie"
DEFAULT_HTTP_PORT=4000
DEFAULT_DIST_PORT=9000
DEFAULT_ENV="dev"
DEFAULT_MODEL="gpt-oss:20b"
# Try to detect the default network interface (wlan0 for WiFi, eth0 for Ethernet, or first available)
DEFAULT_INTERFACE=""
if ip link show wlan0 &>/dev/null; then
    DEFAULT_INTERFACE="wlan0"
elif ip link show eth0 &>/dev/null; then
    DEFAULT_INTERFACE="eth0"
else
    # Fallback to first available non-loopback interface
    DEFAULT_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
    if [ -z "$DEFAULT_INTERFACE" ]; then
        DEFAULT_INTERFACE="lo"  # Fallback to loopback if nothing else is available
    fi
fi

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
    echo "  -n, --node-name NAME    Set the node name (default: $DEFAULT_NODE_NAME)"
    echo "  -c, --cookie COOKIE     Set the Erlang cookie (default: $DEFAULT_COOKIE)"
    echo "  -p, --http-port PORT    Set the HTTP port (default: $DEFAULT_HTTP_PORT)"
    echo "  -d, --dist-port PORT    Set the starting distribution port (default: $DEFAULT_DIST_PORT)"
    echo "  -i, --interface IFACE   Set the network interface (default: $DEFAULT_INTERFACE)"
    echo "  -e, --env ENV           Set the environment (dev/prod, default: $DEFAULT_ENV)"
    echo "  -m, --model MODEL       Set the Ollama model (default: $DEFAULT_MODEL)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --node-name main --cookie my-secret-cookie --http-port 4000 --dist-port 9000 --interface eth0"
}

# Function to get IP address for a specific interface
get_interface_ip() {
    local iface="${1:-$DEFAULT_INTERFACE}"
    local ip=""
    
    if [ -z "$iface" ]; then
        # If no interface specified, try to get the default route interface
        iface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
        if [ -z "$iface" ]; then
            echo "127.0.0.1"
            return 1
        fi
    fi
    
    echo "Using network interface: $iface" >&2
    
    if command -v ip &> /dev/null; then
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    elif command -v ifconfig &> /dev/null; then
        ip=$(ifconfig "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    if [ -z "$ip" ]; then
        echo "127.0.0.1"
        return 1
    fi
    
    echo "$ip"
    return 0
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
        local current_cookie
        current_cookie=$(cat "$cookie_file" 2>/dev/null || echo "")
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

# Function to check if a port is available
is_port_available() {
    local port=$1
    if command -v nc &> /dev/null; then
        if nc -z 127.0.0.1 "$port" &>/dev/null; then
            return 1
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0
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
        -p|--http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -d|--dist-port)
            DIST_PORT="$2"
            shift 2
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Set default values if not provided
NODE_NAME="${NODE_NAME:-$DEFAULT_NODE_NAME}"
COOKIE="${COOKIE:-$DEFAULT_COOKIE}"
HTTP_PORT="${HTTP_PORT:-$DEFAULT_HTTP_PORT}"
DIST_PORT="${DIST_PORT:-$DEFAULT_DIST_PORT}"
ENV="${ENV:-$DEFAULT_ENV}"
MODEL="${MODEL:-$DEFAULT_MODEL}"
INTERFACE="${INTERFACE:-$DEFAULT_INTERFACE}"

# Get network information
HOSTNAME=$(hostname -s)
LOCAL_IP=$(get_interface_ip "$INTERFACE")
FULL_NODE_NAME="${NODE_NAME}@${LOCAL_IP}"

# Check for required commands
for cmd in elixir mix epmd; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed or not in PATH${NC}"
        exit 1
    fi
done

# Verify ports are available
for port in "$HTTP_PORT" "$DIST_PORT"; do
    if ! is_port_available "$port"; then
        echo -e "${RED}Error: Port $port is already in use${NC}"
        exit 1
    fi
done

# Display configuration
echo -e "\n${BLUE}⚡ STARWEAVE Main Node Configuration ⚡${NC}"
echo -e "${YELLOW}Node Name:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Interface:${NC} $INTERFACE"
echo -e "${YELLOW}IP Address:${NC} $LOCAL_IP"
echo -e "${YELLOW}HTTP Port:${NC} $HTTP_PORT"
echo -e "${YELLOW}Distribution Port:${NC} $DIST_PORT"
echo -e "${YELLOW}Environment:${NC} $ENV"
echo -e "${YELLOW}Ollama Model:${NC} $MODEL"
echo -e "${YELLOW}Cookie:${NC} $COOKIE"

# Set up Erlang cookie
setup_cookie "$COOKIE"

# Check and start EPMD
check_epmd

# Export environment variables
export MIX_ENV="$ENV"
export PORT="$HTTP_PORT"
export OLLAMA_MODEL="$MODEL"
export RELEASE_DISTRIBUTION="name"
export RELEASE_NODE="$FULL_NODE_NAME"

# Configure Erlang distribution settings
export ERL_EPMD_ADDRESS="0.0.0.0"
export ERL_EPMD_PORT="4369"

# Generate ERL_FLAGS for distribution
export ERL_FLAGS="-setcookie \"$COOKIE\""
ERL_FLAGS+=" -kernel inet_dist_listen_min $DIST_PORT"
ERL_FLAGS+=" -kernel inet_dist_listen_max $((DIST_PORT + 10))"
ERL_FLAGS+=" -kernel inet_dist_use_interface \"{0,0,0,0}\""
ERL_FLAGS+=" -name \"$FULL_NODE_NAME\""
ERL_FLAGS+=" -start_epmd false"  # We manage EPMD ourselves
export ERL_FLAGS

# Change to the web app directory
cd "$PROJECT_ROOT/apps/starweave_web" || {
    echo -e "${RED}Error: Could not change to web app directory${NC}"
    exit 1
}

# Display startup information
echo -e "\n${BLUE}🚀 Starting STARWEAVE Main Node...${NC}"
echo -e "${YELLOW}Node:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}EPMD:${NC} Running on port 4369"
echo -e "${YELLOW}Distribution Ports:${NC} $DIST_PORT-$((DIST_PORT + 10))"
echo -e "${YELLOW}Web Interface:${NC} http://${LOCAL_IP}:${HTTP_PORT}"
echo -e "${YELLOW}Ollama Model:${NC} $MODEL"
echo -e "\n${YELLOW}To connect to this node:${NC}"
echo -e "  iex --name console@${LOCAL_IP} --cookie ${COOKIE}"
echo -e "\n${YELLOW}To connect from another node:${NC}"
echo -e "  Node.connect(\"${NODE_NAME}@${LOCAL_IP}\")"
echo -e "\n${YELLOW}To connect from a worker node:${NC}"
echo -e "  ./scripts/distributed/worker-node-init.sh --main-ip ${LOCAL_IP} --http-port ${HTTP_PORT} --dist-port ${DIST_PORT}"
echo

# Start the Phoenix server with the specified model
echo -e "${BLUE}Starting Phoenix server with model: ${MODEL}...${NC}"

exec mix phx.server
