#!/bin/bash

# Script to properly stop and restart EPMD with debug output

# Stop any running EPMD
if pgrep -x "epmd" > /dev/null; then
    echo "Stopping existing EPMD..."
    epmd -kill 2>/dev/null || echo "Could not stop EPMD gracefully, trying to force..."
    pkill -9 epmd 2>/dev/null || echo "No EPMD process found"
    sleep 1
fi

# Start EPMD with debug output
echo -e "\nStarting EPMD with debug output..."
epmd -d -d &
sleep 1

# Verify EPMD is running
echo -e "\n=== EPMD Status ==="
if pgrep -x "epmd" > /dev/null; then
    echo "EPMD is running (PID: $(pgrep -x "epmd"))"
    echo -e "\n=== EPMD Names ==="
    epmd -names || echo "Failed to get EPMD names"
    
    echo -e "\n=== Network Status ==="
    if command -v ss &> /dev/null; then
        ss -tuln | grep 4369 || echo "No process listening on port 4369"
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep 4369 || echo "No process listening on port 4369"
    else
        echo "ss or netstat not available to check network status"
    fi
else
    echo "Failed to start EPMD"
    echo -e "\nTroubleshooting steps:"
    echo "1. Check if port 4369 is already in use:"
    echo "   sudo lsof -i :4369"
    echo "2. Check system logs: journalctl -xe | grep -i epmd"
    echo "3. Try starting EPMD manually with: epmd -d -d"
    exit 1
fi
