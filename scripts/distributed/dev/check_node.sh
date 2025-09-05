#!/bin/bash

# Check connection to the main node and verify Erlang distribution

set -e

# Configuration
MAIN_NODE="main@192.168.0.47"
COOKIE="starweave-cookie"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Node Connection Diagnostics ===${NC}"

# 1. Check if we can resolve the main node's hostname
if ! getent hosts "${MAIN_NODE##*@}" >/dev/null; then
    echo -e "${RED}Error: Cannot resolve hostname ${MAIN_NODE##*@}${NC}"
    exit 1
fi

# 2. Check if EPMD is running locally
if ! pgrep -x "epmd" >/dev/null; then
    echo -e "${RED}Error: Local EPMD is not running${NC}"
    exit 1
fi

# 3. Try to get EPMD names from the main node
echo -e "\n${GREEN}Checking EPMD on main node...${NC}"
if ! epmd -names -host "${MAIN_NODE##*@}"; then
    echo -e "${RED}Failed to get EPMD names from ${MAIN_NODE##*@}${NC}"
    echo -e "Possible issues:"
    echo -e "1. EPMD not running on ${MAIN_NODE##*@}"
    echo -e "2. Firewall blocking port 4369"
    echo -e "3. Main node not properly started"
    exit 1
fi

# 4. Try to ping the main node
echo -e "\n${GREEN}Attempting to ping main node...${NC}"
if ! iex --sname diag_$$ --cookie "$COOKIE" -e "
    case Node.ping(:#{$MAIN_NODE}) do
      :pong -> 
        IO.puts(\"${GREEN}Successfully pinged #{$MAIN_NODE}${NC}\");
        IO.puts(\"${GREEN}Connected nodes: #{inspect(Node.list())}\");
        System.halt(0)
      _ -> 
        IO.puts(\"${RED}Failed to ping #{$MAIN_NODE}${NC}\");
        System.halt(1)
    end"; then
    echo -e "${RED}Failed to connect to the main node${NC}"
    echo -e "Possible issues:"
    echo -e "1. Main node not running or not in distributed mode"
    echo -e "2. Cookie mismatch (check ~/.erlang.cookie on both nodes)"
    echo -e "3. Firewall blocking the distributed Erlang port range"
    exit 1
fi

echo -e "\n${GREEN}Diagnostics completed successfully!${NC}"
