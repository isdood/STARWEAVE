#!/bin/bash

# Test connection to worker node script for STARWEAVE distributed setup
# This script verifies basic network connectivity from the main node to a worker node

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
WORKER_IP="192.168.0.49"
DIST_PORT=9100  # Default worker distribution port
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--worker-ip)
            WORKER_IP="$2"
            shift 2
            ;;
        -p|--dist-port)
            DIST_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -w, --worker-ip IP    Worker node IP address (default: $WORKER_IP)"
            echo "  -p, --dist-port PORT  Worker distribution port (default: $DIST_PORT)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main execution
section "Worker Node Connectivity Tests"
echo "Worker Node: $WORKER_IP"
echo "Distribution Port: $DIST_PORT"

# Test 1: Basic ping test
echo -e "\n${YELLOW}1. Testing basic network connectivity...${NC}"
if ! ping_test "$WORKER_IP"; then
    echo -e "${RED}Error: Cannot ping worker node at $WORKER_IP. Check network connection.${NC}"
    exit 1
fi

# Test 2: Check distribution port (9100 by default for workers)
echo -e "\n${YELLOW}2. Checking worker distribution port ($DIST_PORT) accessibility...${NC}"
check_port "$WORKER_IP" "$DIST_PORT" "Worker Distribution"
dist_result=$?

# Test 3: Check if EPMD is running (port 4369)
echo -e "\n${YELLOW}3. Checking EPMD (Erlang Port Mapper Daemon) on port 4369...${NC}"
check_port "$WORKER_IP" 4369 "EPMD"
epmd_result=$?

# Summary
section "Connection Test Summary"
echo "Worker Node: $WORKER_IP"
echo "Distribution Port ($DIST_PORT): $( [ $dist_result -eq 0 ] && echo -e "${GREEN}ACCESSIBLE${NC}" || echo -e "${RED}BLOCKED${NC}" )"
echo "EPMD Port (4369): $( [ $epmd_result -eq 0 ] && echo -e "${GREEN}ACCESSIBLE${NC}" || echo -e "${RED}BLOCKED${NC}" )"

# Final result
if [ $dist_result -eq 0 ] && [ $epmd_result -eq 0 ]; then
    echo -e "\n${GREEN}✓ All connection tests passed! The main node should be able to connect to the worker node.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some connection tests failed. Please check the following:${NC}"
    [ $dist_result -ne 0 ] && echo "- Ensure the worker node's distribution port $DIST_PORT is open and accessible"
    [ $epmd_result -ne 0 ] && echo "- Ensure EPMD is running on the worker node and port 4369 is open"
    echo -e "\n${YELLOW}Note: If any ports are blocked, check your firewall settings and ensure the worker node's services are properly configured.${NC}"
    exit 1
fi
