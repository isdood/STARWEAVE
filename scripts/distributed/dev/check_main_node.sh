#!/bin/bash

# Diagnostic script to check main node status

# Configuration
MAIN_NODE="main"
MAIN_HOST="192.168.0.47"
COOKIE="starweave-cookie"
DIST_PORT=9100

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Main Node Diagnostic ===${NC}"

# 1. Check if EPMD port is open
echo -e "\n${BLUE}1. Checking EPMD port (4369) on ${MAIN_HOST}...${NC}"
if nc -zv ${MAIN_HOST} 4369 2>/dev/null; then
    echo -e "${GREEN}✓ EPMD port is open${NC}"
else
    echo -e "${RED}✗ Could not connect to EPMD on ${MAIN_HOST}:4369${NC}"
    echo -e "${YELLOW}  - Make sure EPMD is running on the main node${NC}"
    echo -e "${YELLOW}  - Check firewall settings on both nodes${NC}"
    exit 1
fi

# 2. Check if EPMD is responding
echo -e "\n${BLUE}2. Checking EPMD names...${NC}"
EPMD_NAMES=$(epmd -names -host ${MAIN_HOST} 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ EPMD is responding:${NC}"
    echo "$EPMD_NAMES"
else
    echo -e "${YELLOW}⚠ EPMD is not responding as expected:${NC}"
    echo "$EPMD_NAMES"
    echo -e "${YELLOW}  - Main node might not be running in distributed mode${NC}"
fi

# 3. Check if the main node is running
echo -e "\n${BLUE}3. Checking if main node is running...${NC}"
NODE_CHECK=$(erl -sname check_$$ -setcookie ${COOKIE} -noinput -eval "
    case net_adm:ping('${MAIN_NODE}@${MAIN_HOST}') of
        pong -> io:format(\"CONNECTED~n\");
        _ -> io:format(\"NOT_CONNECTED~n\")
    end." -run init stop 2>/dev/null)

if [ "$NODE_CHECK" = "CONNECTED" ]; then
    echo -e "${GREEN}✓ Main node is running and accessible${NC}"
else
    echo -e "${RED}✗ Could not connect to main node: ${MAIN_NODE}@${MAIN_HOST}${NC}"
    echo -e "${YELLOW}  - Make sure the main node is running with:${NC}"
    echo -e "    ./scripts/distributed/main-node-init.sh"
    echo -e "${YELLOW}  - Verify the node name and cookie match:${NC}"
    echo -e "    Node name: ${MAIN_NODE}@${MAIN_HOST}"
    echo -e "    Cookie: ${COOKIE}"
    exit 1
fi

# 4. Check if distributed port is open
echo -e "\n${BLUE}4. Checking distributed port (${DIST_PORT}) on ${MAIN_HOST}...${NC}"
if nc -zv ${MAIN_HOST} ${DIST_PORT} 2>/dev/null; then
    echo -e "${GREEN}✓ Distributed port ${DIST_PORT} is open${NC}"
else
    echo -e "${YELLOW}⚠ Could not connect to distributed port ${DIST_PORT} on ${MAIN_HOST}${NC}"
    echo -e "${YELLOW}  - The main node might be using a different port${NC}"
    echo -e "${YELLOW}  - Check firewall settings${NC}"
fi

echo -e "\n${BLUE}=== Diagnostic Complete ===${NC}"
echo -e "If all checks pass but you still can't connect, try:"
echo -e "1. Restarting the main node"
echo -e "2. Verifying the cookie matches on both nodes"
echo -e "3. Checking network connectivity between nodes"
