#!/bin/bash

# Setup script for Erlang node communication

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get current hostname
CURRENT_HOST=$(hostname)

# Node information
MAIN_NODE="STARCORE"
WORKER_NODE="001-LITE"
MAIN_IP="192.168.0.47"
WORKER_IP="192.168.0.49"
COOKIE="starweave-cookie"

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${YELLOW}Warning: Some operations require root privileges.${NC}"
        return 1
    fi
    return 0
}

# Function to update hosts file
update_hosts() {
    echo -e "\n${YELLOW}=== Updating /etc/hosts ===${NC}"
    
    # Create backup
    sudo cp /etc/hosts /etc/hosts.backup.$(date +%s)
    
    # Remove existing entries if they exist
    sudo sed -i "/$MAIN_NODE/d" /etc/hosts
    sudo sed -i "/$WORKER_NODE/d" /etc/hosts
    
    # Add new entries
    echo -e "\n# STARWEAVE nodes" | sudo tee -a /etc/hosts
    echo -e "$MAIN_IP\t$MAIN_NODE $MAIN_NODE.local" | sudo tee -a /etc/hosts
    echo -e "$WORKER_IP\t$WORKER_NODE $WORKER_NODE.local" | sudo tee -a /etc/hosts
    
    echo -e "${GREEN}✓ Updated /etc/hosts${NC}"
    cat /etc/hosts | grep -A 2 "# STARWEAVE nodes"
}

# Function to test Erlang connection
test_erlang_connection() {
    local from_node=$1
    local to_node=$2
    
    echo -e "\n${YELLOW}=== Testing connection from $from_node to $to_node ===${NC}"
    
    # Start EPMD if not running
    if ! pgrep epmd > /dev/null; then
        echo "Starting EPMD..."
        epmd -daemon
    fi
    
    # Test connection
    echo "Testing Erlang distribution between nodes..."
    erl -sname test@$from_node -setcookie $COOKIE -eval \
        "io:format(\"Attempting to ping ~s from ~s...~n\", [\"$to_node\", \"$from_node\"]), 
        Result = net_adm:ping('test@$to_node'), 
        io:format(\"Result: ~p~n\", [Result]), 
        erlang:halt()."
}

# Main
main() {
    echo -e "${YELLOW}=== STARWEAVE Erlang Node Setup ===${NC}"
    echo "Current host: $CURRENT_HOST"
    
    # Check if we're on main or worker node
    if [ "$CURRENT_HOST" = "$MAIN_NODE" ]; then
        echo "Detected main node ($MAIN_NODE)"
        OTHER_NODE=$WORKER_NODE
    else
        echo "Detected worker node ($WORKER_NODE)"
        OTHER_NODE=$MAIN_NODE
    fi
    
    # Update hosts file if running as root
    if [ "$EUID" -eq 0 ]; then
        update_hosts
    else
        echo -e "\n${YELLOW}Run the following with sudo to update /etc/hosts:${NC}"
        echo "sudo $0 --update-hosts"
    fi
    
    # Test connection
    test_erlang_connection "$CURRENT_HOST" "$OTHER_NODE"
}

# Parse arguments
case "${1:-}" in
    --update-hosts)
        update_hosts
        ;;
    *)
        main
        ;;
esac
