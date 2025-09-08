#!/bin/bash

# Test connection to main node script for STARWEAVE distributed setup
# This script verifies basic network connectivity to the main node

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
MAIN_IP="192.168.0.47"
HTTP_PORT=4000
DIST_PORT=9000
TIMEOUT=5  # seconds

# Function to display section header
section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is open
check_port() {
    local host=$1
    local port=$2
    local service=$3
    
    if command_exists nc; then
        if nc -z -w $TIMEOUT "$host" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $service port $port is accessible on $host"
            return 0
        else
            echo -e "${RED}✗${NC} $service port $port is NOT accessible on $host"
            return 1
        fi
    else
        echo -e "${YELLOW}ℹ nc (netcat) not found, using fallback port check${NC}"
        # Fallback using bash's /dev/tcp
        if timeout $TIMEOUT bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $service port $port is accessible on $host"
            return 0
        else
            echo -e "${RED}✗${NC} $service port $port is NOT accessible on $host"
            return 1
        fi
    fi
}

# Function to perform ping test
ping_test() {
    local host=$1
    echo -n "Pinging $host... "
    
    if ping -c 3 -W 2 "$host" &>/dev/null; then
        echo -e "${GREEN}SUCCESS${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

# Main execution
section "Network Connectivity Tests"

# Test 1: Basic ping test
echo -e "\n${YELLOW}1. Testing basic network connectivity...${NC}"
if ! ping_test "$MAIN_IP"; then
    echo -e "${RED}Error: Cannot ping main node at $MAIN_IP. Check network connection.${NC}"
    exit 1
fi

# Test 2: Check HTTP port (4000)
echo -e "\n${YELLOW}2. Checking HTTP port ($HTTP_PORT) accessibility...${NC}"
check_port "$MAIN_IP" "$HTTP_PORT" "HTTP"
http_result=$?

# Test 3: Check distribution port (9000)
echo -e "\n${YELLOW}3. Checking distribution port ($DIST_PORT) accessibility...${NC}"
check_port "$MAIN_IP" "$DIST_PORT" "Distribution"
dist_result=$?

# Test 4: Check if EPMD is running (port 4369)
echo -e "\n${YELLOW}4. Checking EPMD (Erlang Port Mapper Daemon) on port 4369...${NC}"
check_port "$MAIN_IP" 4369 "EPMD"
epmd_result=$?

# Summary
section "Connection Test Summary"
echo "Main Node: $MAIN_IP"
echo "HTTP Port ($HTTP_PORT): $( [ $http_result -eq 0 ] && echo -e "${GREEN}ACCESSIBLE${NC}" || echo -e "${RED}BLOCKED${NC}" )"
echo "Distribution Port ($DIST_PORT): $( [ $dist_result -eq 0 ] && echo -e "${GREEN}ACCESSIBLE${NC}" || echo -e "${RED}BLOCKED${NC}" )"
echo "EPMD Port (4369): $( [ $epmd_result -eq 0 ] && echo -e "${GREEN}ACCESSIBLE${NC}" || echo -e "${RED}BLOCKED${NC}" )"

# Final result
if [ $http_result -eq 0 ] && [ $dist_result -eq 0 ] && [ $epmd_result -eq 0 ]; then
    echo -e "\n${GREEN}✓ All connection tests passed! The worker node should be able to connect to the main node.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some connection tests failed. Please check the following:${NC}"
    [ $http_result -ne 0 ] && echo "- Ensure the main node's HTTP service is running and accessible on port $HTTP_PORT"
    [ $dist_result -ne 0 ] && echo "- Ensure the main node's distribution port $DIST_PORT is open and accessible"
    [ $epmd_result -ne 0 ] && echo "- Ensure EPMD is running on the main node and port 4369 is open"
    echo -e "\n${YELLOW}Note: If any ports are blocked, check your firewall settings and ensure the main node's services are properly configured.${NC}"
    exit 1
fi
