#!/bin/bash

# Simple EPMD debug script for STARWEAVE
# This script starts EPMD in debug mode and tests connectivity

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default EPMD port
EPMD_PORT=${ERL_EPMD_PORT:-4369}

# Function to check if a port is open
check_port() {
    local host=$1
    local port=$2
    
    if command -v nc &> /dev/null; then
        if nc -z -w 2 $host $port &> /dev/null; then
            return 0
        fi
    fi
    
    if command -v bash &> /dev/null; then
        if timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Function to get local IP addresses
get_local_ips() {
    if command -v hostname &> /dev/null; then
        hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' || \
        ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
    else
        ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
    fi
}

# Function to test connectivity
test_connectivity() {
    local host=$1
    local port=$2
    
    echo -e "\n${BLUE}Testing connection to $host:$port...${NC}"
    
    if check_port $host $port; then
        echo -e "${GREEN}✓ Connection to $host:$port successful!${NC}"
        return 0
    else
        echo -e "${RED}✗ Could not connect to $host:$port${NC}"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}=== STARWEAVE EPMD Debug Tool ===${NC}"

# Check if EPMD is already running
if pgrep -x "epmd" > /dev/null; then
    echo -e "${YELLOW}EPMD is already running. Please stop it first.${NC}"
    echo -e "  Run: ${YELLOW}killall epmd${NC} to stop all EPMD processes"
    exit 1
fi

# Start EPMD in debug mode in the background
echo -e "\n${BLUE}Starting EPMD in debug mode on port $EPMD_PORT...${NC}
${YELLOW}Keep this terminal open to maintain the EPMD process.${NC}\n"

# Start EPMD in the background
epmd -debug -port $EPMD_PORT &
EPMD_PID=$!

# Give it a moment to start
sleep 1

# Check if EPMD started
if ! ps -p $EPMD_PID > /dev/null; then
    echo -e "${RED}Failed to start EPMD.${NC}"
    exit 1
fi

# Test local connectivity
test_connectivity 127.0.0.1 $EPMD_PORT

# Test all local IPs
LOCAL_IPS=$(get_local_ips)
if [ -n "$LOCAL_IPS" ]; then
    echo -e "\n${BLUE}Testing local network interfaces:${NC}"
    for ip in $LOCAL_IPS; do
        echo -n "  $ip: "
        if check_port $ip $EPMD_PORT; then
            echo -e "${GREEN}✓ Accessible${NC}"
        else
            echo -e "${YELLOW}✗ Not accessible${NC}"
        fi
    done
fi

# Show instructions for remote testing
REMOTE_IP=$(echo "$LOCAL_IPS" | head -n 1)
if [ -n "$REMOTE_IP" ]; then
    echo -e "\n${BLUE}To test from another machine, run:${NC}"
    echo -e "  ${YELLOW}nc -zv $REMOTE_IP $EPMD_PORT${NC}"
    echo -e "or for more detailed output:"
    echo -e "  ${YELLOW}epmd -port $EPMD_PORT -names -addresses $REMOTE_IP${NC}\n"
fi

# Cleanup function
cleanup() {
    echo -e "\n${BLUE}Stopping EPMD (PID: $EPMD_PID)...${NC}"
    kill $EPMD_PID 2>/dev/null || true
    exit 0
}

# Set up trap to clean up on exit
trap cleanup INT TERM EXIT

echo -e "\n${GREEN}EPMD is running in debug mode. Press Ctrl+C to stop.${NC}"

# Keep the script running
wait $EPMD_PID
