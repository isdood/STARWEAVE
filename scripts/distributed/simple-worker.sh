#!/bin/bash

# Minimal Worker Node Initialization for STARWEAVE
# Focused on basic connection to main node

set -e

# Configuration
NODE_NAME="worker1"
MAIN_NODE="main"  # Just the node name, without @hostname
MAIN_HOST="192.168.0.47"
COOKIE="starweave-cookie"
DIST_PORT=9100

# Get system hostname for the worker node
HOSTNAME=$(hostname -s)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Get local IP
get_local_ip() {
    ip route get 1 | awk '{print $7; exit}'
}

# Main execution
echo -e "${BLUE}=== STARWEAVE Worker Node ===${NC}"

# Stop any running EPMD
echo -e "${YELLOW}Stopping any running EPMD...${NC}"
pkill -9 epmd 2>/dev/null || true
sleep 1

# Start EPMD
echo -e "${BLUE}Starting EPMD...${NC}"
epmd -daemon || { echo -e "${RED}Failed to start EPMD${NC}"; exit 1; }

# Set Erlang cookie
echo -e "${BLUE}Setting Erlang cookie...${NC}"
echo "$COOKIE" > "$HOME/.erlang.cookie"
chmod 600 "$HOME/.erlang.cookie"

# Get local IP
LOCAL_IP=$(get_local_ip)

# Set the full node names
FULL_NODE_NAME="${NODE_NAME}@${HOSTNAME}"
FULL_MAIN_NODE="${MAIN_NODE}@${MAIN_HOST}"

echo -e "${BLUE}Local IP: $LOCAL_IP${NC}"
echo -e "${BLUE}Starting worker node: $FULL_NODE_NAME${NC}"
echo -e "${BLUE}Connecting to main node: $FULL_MAIN_NODE${NC}"

# Start the node with a simple connection test
iex \
    --name "$FULL_NODE_NAME" \
    --cookie "$COOKIE" \
    --erl "-kernel inet_dist_listen_min $DIST_PORT" \
    --erl "-kernel inet_dist_listen_max $DIST_PORT" \
    -e "
        require Logger
        
        # Set up error logger
        :error_logger.tty(true)
        
        # Define main node name
        main_node = :'$MAIN_NODE@$MAIN_HOST'
        
        IO.puts(\"\\n${BLUE}Worker node started as: #{node()}${NC}\")
        IO.puts(\"${BLUE}Attempting to connect to: #{inspect(main_node)}...${NC}\")
        
        # Try to connect to main node
        IO.puts(\"${YELLOW}Pinging main node...${NC}\")
        case Node.ping(main_node) do
            :pong -> 
                IO.puts(\"\\n${GREEN}Successfully connected to #{inspect(main_node)}!${NC}\")
                IO.puts(\"${BLUE}Connected nodes: #{inspect(Node.list())}${NC}\")
                IO.puts(\"\\n${YELLOW}Press Ctrl+C to exit${NC}\")
                :timer.sleep(:infinity)
            _ -> 
                IO.puts(\"\\n${RED}Failed to connect to #{inspect(main_node)}${NC}\")
                IO.puts(\"\\n${YELLOW}Diagnostic information:${NC}\")
                IO.puts(\"  - Local node: #{node()}\")
                IO.puts(\"  - Target node: #{inspect(main_node)}\")
                IO.puts(\"  - Cookie: #{Node.get_cookie()}\")
                IO.puts(\"\\n${YELLOW}Possible issues:${NC}\")
                IO.puts(\"  1. Main node not running or not in distributed mode\")
                IO.puts(\"  2. Firewall blocking port $DIST_PORT\")
                IO.puts(\"  3. Cookie mismatch (check ~/.erlang.cookie on both nodes)\")
                IO.puts(\"  4. Network connectivity issues\")
                :timer.sleep(5)
                System.halt(1)
        end
    "
