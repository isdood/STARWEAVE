#!/bin/bash

# EPMD Test Script for STARWEAVE
# This script helps test and troubleshoot EPMD (Erlang Port Mapper Daemon) connectivity

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a port is open
check_port() {
    local port=$1
    if command -v nc &> /dev/null; then
        if nc -z 127.0.0.1 $port &> /dev/null; then
            return 0
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 0
        fi
    fi
    return 1
}

# Function to get EPMD port from environment or use default
get_epmd_port() {
    if [ -n "$ERL_EPMD_PORT" ]; then
        echo $ERL_EPMD_PORT
    else
        echo 4369
    fi
}

# Function to check EPMD status
check_epmd_status() {
    local epmd_port=$(get_epmd_port)
    
    echo -e "${BLUE}=== EPMD Status Check ===${NC}"
    
    # Check if EPMD is running
    if pgrep -x "epmd" > /dev/null; then
        echo -e "${GREEN}✓ EPMD is running (PID: $(pgrep -x "epmd"))${NC}"
    else
        echo -e "${YELLOW}⚠ EPMD is not running${NC}"
        return 1
    fi
    
    # Check if EPMD port is open
    if check_port $epmd_port; then
        echo -e "${GREEN}✓ EPMD port $epmd_port is open and listening${NC}"
    else
        echo -e "${RED}✗ EPMD port $epmd_port is not accessible${NC}"
        return 1
    fi
    
    # List registered nodes
    echo -e "\n${BLUE}=== Registered Nodes ===${NC}"
    if command -v epmd &> /dev/null; then
        epmd -names
    else
        echo -e "${YELLOW}epmd command not found in PATH${NC}"
    fi
    
    return 0
}

# Function to start EPMD
start_epmd() {
    local epmd_port=$(get_epmd_port)
    
    echo -e "${BLUE}=== Starting EPMD ===${NC}"
    
    # Check if EPMD is already running
    if pgrep -x "epmd" > /dev/null; then
        echo -e "${YELLOW}EPMD is already running. Restarting...${NC}"
        killall epmd 2>/dev/null || true
        sleep 1
    fi
    
    # Start EPMD in the background
    if command -v epmd &> /dev/null; then
        # Use -daemon flag if available (EPMD 5.0+)
        if epmd -h 2>&1 | grep -q -- '-daemon'; then
            epmd -daemon
        else
            epmd
        fi
        
        # Wait for EPMD to start
        sleep 1
        
        # Verify EPMD started
        if pgrep -x "epmd" > /dev/null; then
            echo -e "${GREEN}✓ EPMD started successfully${NC}"
            return 0
        else
            echo -e "${RED}Failed to start EPMD${NC}"
            return 1
        fi
    else
        echo -e "${RED}epmd command not found in PATH${NC}"
        return 1
    fi
}

# Function to test remote connectivity
test_remote_connectivity() {
    local ip=$1
    local port=${2:-$(get_epmd_port)}
    
    echo -e "\n${BLUE}=== Testing Remote Connectivity ===${NC}"
    echo "Testing connection to $ip:$port..."
    
    if command -v nc &> /dev/null; then
        if nc -zv -w 3 $ip $port; then
            echo -e "${GREEN}✓ Successfully connected to $ip:$port${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to connect to $ip:$port${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}netcat (nc) not found. Install it for better connectivity testing.${NC}"
        return 1
    fi
}

# Function to show firewall status
show_firewall_status() {
    echo -e "\n${BLUE}=== Firewall Status ===${NC}"
    
    if command -v ufw &> /dev/null && systemctl is-active --quiet ufw; then
        echo "UFW is active:"
        sudo ufw status verbose
    elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        echo "firewalld is active:"
        sudo firewall-cmd --list-all
    elif command -v iptables &> /dev/null; then
        echo "iptables rules for EPMD port (4369):"
        sudo iptables -L -n | grep -E "(4369|epmd)" || echo "No specific rules found for EPMD"
    else
        echo "No active firewall detected or insufficient permissions"
    fi
}

# Function to show network interfaces
show_network_interfaces() {
    echo -e "\n${BLUE}=== Network Interfaces ===${NC}"
    
    if command -v ip &> /dev/null; then
        ip addr show
    elif command -v ifconfig &> /dev/null; then
        ifconfig
    else
        echo "Could not determine network interfaces (ip/ifconfig not found)"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== STARWEAVE EPMD Test Tool ===${NC}"
    
    # Check for root privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Note: Some operations may require root privileges${NC}"
    fi
    
    # Get EPMD port
    local epmd_port=$(get_epmd_port)
    
    # Check if EPMD is running
    if ! check_epmd_status; then
        echo -e "\n${YELLOW}EPMD is not running or not accessible. Starting EPMD...${NC}"
        if ! start_epmd; then
            echo -e "${RED}Failed to start EPMD. Please check your Erlang installation.${NC}"
            exit 1
        fi
    fi
    
    # Show network information
    show_network_interfaces
    
    # Show firewall status
    show_firewall_status
    
    # Test local connectivity
    test_remote_connectivity 127.0.0.1 $epmd_port
    
    # Get local IP addresses
    local local_ips=$(hostname -I 2>/dev/null || ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
    
    # Test remote connectivity on all local IPs
    for ip in $local_ips; do
        test_remote_connectivity $ip $epmd_port
    done
    
    # Show EPMD information
    echo -e "\n${BLUE}=== EPMD Information ===${NC}"
    if command -v epmd &> /dev/null; then
        epmd -port $epmd_port -names
    fi
    
    echo -e "\n${GREEN}=== Test Complete ===${NC}"
    echo -e "If you're having issues with remote connections, check the following:"
    echo "1. Firewall settings (see above)"
    echo "2. Network connectivity between machines"
    echo "3. ERL_EPMD_PORT environment variable (if using non-standard port)"
    echo -e "4. Run this script with ${YELLOW}sudo${NC} for more detailed firewall information"
}

# Run the main function
main "$@"

exit 0
