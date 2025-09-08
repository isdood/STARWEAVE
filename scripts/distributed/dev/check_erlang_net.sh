#!/bin/bash
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "FQDN: $(hostname -f)"
echo "IP: $(ip route get 1 | awk '{print $7; exit}')"
echo -e "\n=== Network Interfaces ==="
ip addr show
echo -e "\n=== Firewall Status ==="
sudo firewall-cmd --state
sudo firewall-cmd --list-ports
echo -e "\n=== EPMD Status ==="
epmd -names
echo -e "\n=== Listening Ports ==="
sudo netstat -tulnp | grep -E '4369|9000|9100'

