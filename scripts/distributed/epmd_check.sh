#!/bin/bash

# Script to check and manage EPMD status

echo "=== EPMD Status Check ==="

# Check if EPMD is installed
if ! command -v epmd &> /dev/null; then
    echo "EPMD is not installed or not in PATH"
    exit 1
fi

# Check if EPMD is running
if pgrep -x "epmd" > /dev/null; then
    echo "EPMD is running (PID: $(pgrep -x "epmd"))"
    echo "EPMD node names:"
    epmd -names || echo "Failed to get EPMD names"
    
    echo -e "\n=== EPMD Info ==="
    epmd -h
    
    echo -e "\n=== EPMD Environment ==="
    echo "ERL_EPMD_PORT: ${ERL_EPMD_PORT:-Not set (using default 4369)}"
    echo "HOME: $HOME"
    
    echo -e "\n=== EPMD Socket Status ==="
    if command -v lsof &> /dev/null; then
        lsof -i :4369 2>/dev/null || echo "No process listening on port 4369"
    else
        netstat -tuln | grep 4369 || echo "No process listening on port 4369"
    fi
    
    echo -e "\n=== EPMD Logs ==="
    tail -n 20 /var/log/epmd.log 2>/dev/null || echo "No EPMD logs found in /var/log/epmd.log"
else
    echo "EPMD is not running"
    
    echo -e "\nAttempting to start EPMD..."
    if epmd -daemon; then
        echo "EPMD started successfully"
        sleep 1
        echo -e "\nEPMD names after start:"
        epmd -names || echo "Failed to get EPMD names"
    else
        echo "Failed to start EPMD"
        echo -e "\nTroubleshooting steps:"
        echo "1. Check if port 4369 is already in use: netstat -tuln | grep 4369"
        echo "2. Check EPMD logs: journalctl -u epmd -n 50"
        echo "3. Try starting EPMD manually with debug: epmd -d 1 -d"
    fi
fi

echo -e "\n=== Current Erlang Cookie ==="
if [ -f "$HOME/.erlang.cookie" ]; then
    echo "Cookie file: $HOME/.erlang.cookie"
    echo "Permissions: $(ls -l "$HOME/.erlang.cookie" | awk '{print $1}')"
    echo "Value: $(cat "$HOME/.erlang.cookie")"
else
    echo "No .erlang.cookie found in $HOME/"
fi
