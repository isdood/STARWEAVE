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
DIST_PORT=9100
DEFAULT_ENV="dev"
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
    echo -e "${BLUE}STARWEAVE Worker Node Initialization${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --node-name NAME    Set the worker node name (default: $DEFAULT_NODE_NAME)"
    echo "  -i, --main-ip IP        Set the main node IP address (default: $DEFAULT_MAIN_IP)"
    echo "  -p, --http-port PORT    Set the main node HTTP port (default: $DEFAULT_MAIN_HTTP_PORT)"
    echo "  -d, --dist-port PORT    Set the main node distribution port (default: $DEFAULT_MAIN_DIST_PORT)"
    echo "  -w, --worker-port PORT  Set the worker node distribution port (default: $DIST_PORT)"
    echo "  -c, --cookie COOKIE     Set the Erlang cookie (default: $DEFAULT_COOKIE)"
    echo "  -e, --env ENV           Set the environment (dev/prod, default: $DEFAULT_ENV)"
    echo "  -I, --interface IFACE   Set the network interface (default: $DEFAULT_INTERFACE)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --node-name worker1 --main-ip 192.168.1.100 --http-port 4000 --dist-port 9000"
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

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if a port is available
is_port_available() {
    local port=$1
    if command_exists nc; then
        nc -z 127.0.0.1 "$port" &>/dev/null
        return $((! $?))
    elif command_exists ss; then
        ss -tuln | grep -q ":$port "
        return $((! $?))
    elif command_exists netstat; then
        netstat -tuln | grep -q ":$port "
        return $((! $?))
    else
        # If we can't check, assume the port is available
        return 0
    fi
}

# Function to check EPMD
check_epmd() {
    if ! command_exists epmd; then
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--node-name)
            NODE_NAME="$2"
            shift 2
            ;;
        -i|--main-ip)
            MAIN_IP="$2"
            shift 2
            ;;
        -p|--http-port)
            MAIN_HTTP_PORT="$2"
            shift 2
            ;;
        -d|--dist-port)
            MAIN_DIST_PORT="$2"
            shift 2
            ;;
        -w|--worker-port)
            DIST_PORT="$2"
            shift 2
            ;;
        -c|--cookie)
            COOKIE="$2"
            shift 2
            ;;
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -I|--interface)
            INTERFACE="$2"
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
MAIN_IP="${MAIN_IP:-$DEFAULT_MAIN_IP}"
MAIN_HTTP_PORT="${MAIN_HTTP_PORT:-$DEFAULT_MAIN_HTTP_PORT}"
MAIN_DIST_PORT="${MAIN_DIST_PORT:-$DEFAULT_MAIN_DIST_PORT}"
COOKIE="${COOKIE:-$DEFAULT_COOKIE}"
DIST_PORT="${DIST_PORT:-9100}"
ENV="${ENV:-$DEFAULT_ENV}"
INTERFACE="${INTERFACE:-$DEFAULT_INTERFACE}"

# Get network information
HOSTNAME=$(hostname -s)
LOCAL_IP=$(get_interface_ip "$INTERFACE")
FULL_NODE_NAME="${NODE_NAME}@${LOCAL_IP}"
MAIN_NODE="main@${MAIN_IP}"

# Check for required commands
for cmd in elixir mix epmd; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed or not in PATH${NC}"
        exit 1
    fi
done

# Verify ports are available
if ! is_port_available "$DIST_PORT"; then
    echo -e "${RED}Error: Port $DIST_PORT is already in use${NC}"
    exit 1
fi

# Display configuration
echo -e "\n${BLUE}⚡ STARWEAVE Worker Node Configuration ⚡${NC}"
echo -e "${YELLOW}Worker Node:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Main Node:${NC} $MAIN_NODE"
echo -e "${YELLOW}Main Node HTTP:${NC} http://${MAIN_IP}:${MAIN_HTTP_PORT}"
echo -e "${YELLOW}Distribution Port:${NC} $DIST_PORT"
echo -e "${YELLOW}Environment:${NC} $ENV"
echo -e "${YELLOW}Interface:${NC} $INTERFACE"
echo -e "${YELLOW}Local IP:${NC} $LOCAL_IP"

# Set up Erlang cookie
setup_cookie "$COOKIE"

# Check and start EPMD
check_epmd

# Check connection to main node
echo -e "\n${BLUE}Checking connection to main node at $MAIN_IP...${NC}"
if ! nc -z -w 5 "$MAIN_IP" 4369; then
    echo -e "${YELLOW}Warning: Cannot connect to EPMD on $MAIN_IP:4369${NC}"
    echo -e "${YELLOW}Make sure the main node is running and accessible${NC}"
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
ERL_FLAGS+=" -name \"$NODE_NAME@$LOCAL_IP\""
ERL_FLAGS+=" -start_epmd false"  # We manage EPMD ourselves

export ERL_FLAGS

# Change to the web app directory
cd "$PROJECT_ROOT/apps/starweave_web" || {
    echo -e "${RED}Error: Could not change to web app directory${NC}"
    exit 1
}

# Display startup information
echo -e "\n${BLUE}🚀 Starting STARWEAVE Worker Node...${NC}"
echo -e "${YELLOW}Node:${NC} $FULL_NODE_NAME"
echo -e "${YELLOW}Connecting to:${NC} $MAIN_NODE"
echo -e "${YELLOW}EPMD:${NC} Running on port 4369"
echo -e "${YELLOW}Distribution Ports:${NC} $DIST_PORT-$((DIST_PORT + 10))"
echo -e "\n${YELLOW}To connect to this node:${NC}"
echo -e "  iex --name console@$LOCAL_IP --cookie $COOKIE"
echo -e "\n${YELLOW}To connect from another node:${NC}"
echo -e "  Node.connect(\"$NODE_NAME@$LOCAL_IP\")"
echo

# Start the worker node
echo -e "${BLUE}Starting worker node and connecting to main node...${NC}"

exec iex \
  --name "$NODE_NAME@$LOCAL_IP" \
  --cookie "$COOKIE" \
  --erl "-start_epmd false -epmd_module Elixir.IEx.EPMD.Client -proto_dist Elixir.IEx.Distribution.Client.ERL_EPMD_DIST" \
  -S mix phx.server
