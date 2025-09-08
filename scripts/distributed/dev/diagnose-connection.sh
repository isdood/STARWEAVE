#!/bin/bash

# Diagnostic script for STARWEAVE distributed connection issues

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Defaults
WORKER_IP="192.168.0.49"
MAIN_IP="192.168.0.47"
PORTS=("9100" "4369" "9000" "4000")

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${YELLOW}Warning: Some checks require root privileges. Consider running with sudo.${NC}"
        return 1
    fi
    return 0
}

# Check local firewall
check_local_firewall() {
    echo -e "\n${YELLOW}=== Local Firewall Status ===${NC}"
    if command -v firewall-cmd &> /dev/null; then
        echo "Firewalld active zones:"
        sudo firewall-cmd --get-active-zones
        echo -e "\nOpen ports:"
        sudo firewall-cmd --list-ports
        echo -e "\nServices:"
        sudo firewall-cmd --list-services
    else
        echo "firewalld not found. Checking iptables..."
        sudo iptables -L -n -v
    fi
}

# Check listening ports
check_listening_ports() {
    echo -e "\n${YELLOW}=== Listening Ports ===${NC}"
    echo "TCP:"
    sudo ss -tulnp | grep -E "$(IFS='|'; echo "${PORTS[*]}")" || true
    echo -e "\nUDP:"
    sudo ss -ulnp | grep -E "$(IFS='|'; echo "${PORTS[*]}")" || true
}

# Test port connectivity
test_port() {
    local host=$1
    local port=$2
    local protocol=${3:-tcp}
    
    echo -n "Testing $protocol port $port on $host... "
    if nc -z -w 2 "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}OPEN${NC}"
        return 0
    else
        echo -e "${RED}CLOSED${NC}"
        return 1
    fi
}

# Main
main() {
    echo -e "${YELLOW}=== STARWEAVE Connection Diagnostics ===${NC}"
    echo "Local IP: $(hostname -I | awk '{print $1}')"
    echo "Main Node: $MAIN_IP"
    echo "Worker Node: $WORKER_IP"
    
    check_root
    check_local_firewall
    check_listening_ports
    
    echo -e "\n${YELLOW}=== Testing Connectivity to Worker ($WORKER_IP) ===${NC}"
    for port in "${PORTS[@]}"; do
        test_port "$WORKER_IP" "$port"
    done
    
    echo -e "\n${YELLOW}=== Quick Fixes to Try ===${NC}"
    echo "1. Open all required ports:"
    echo "   sudo firewall-cmd --permanent --add-port=4000/tcp"
    echo "   sudo firewall-cmd --permanent --add-port=4369/tcp"
    echo "   sudo firewall-cmd --permanent --add-port=9000-9100/tcp"
    echo "   sudo firewall-cmd --reload"
    echo -e "\n2. On the worker node, test with a simple listener:"
    echo "   nc -l -p 9100 -v"
    echo -e "\n3. Then from this machine, test the connection:"
    echo "   nc -zv $WORKER_IP 9100"
    echo -e "\n4. Check SELinux status (if enabled):"
    echo "   getenforce"
    echo "   sudo setenforce 0  # Temporarily disable for testing"
}

main "$@"
