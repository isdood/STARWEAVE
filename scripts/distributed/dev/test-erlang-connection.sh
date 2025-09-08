#!/bin/bash

# Test Erlang node connectivity

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Node information
MAIN_NODE="STARCORE"
WORKER_NODE="001-LITE"
MAIN_IP="192.168.0.47"
WORKER_IP="192.168.0.49"
COOKIE="starweave-cookie"

# Function to check EPMD
check_epmd() {
    echo -e "\n${YELLOW}=== Checking EPMD ===${NC}"
    
    # Check if EPMD is running
    if ! pgrep epmd > /dev/null; then
        echo "Starting EPMD..."
        epmd -daemon
    fi
    
    # List registered nodes
    echo -e "\nEPMD registered nodes:"
    epmd -names || echo "Failed to get EPMD names"
}

# Function to test Erlang connection
test_erlang_connection() {
    local from_node=$1
    local to_node=$2
    
    echo -e "\n${YELLOW}=== Testing Erlang connection from $from_node to $to_node ===${NC}"
    
    # Create a temporary Erlang script
    cat > /tmp/erlang_test.erl << EOF
-module(erlang_test).
-export([test_connection/0]).

test_connection() ->
    io:format("Node name: ~p~n", [node()]),
    io:format("Cookie: ~p~n", [erlang:get_cookie()]),
    io:format("Kernel options: ~p~n", [init:get_arguments()]),
    io:format("Net kernel: ~p~n", [net_kernel:options()]),
    
    io:format("\nTrying to ping ~p...~n", ['$to_node']),
    case net_adm:ping('$to_node') of
        pong -> 
            io:format("Successfully connected to ~p!~n", ['$to_node']),
            {ok, connected};
        pang ->
            io:format("Failed to connect to ~p.~n", ['$to_node']),
            io:format("Troubleshooting steps:~n"),
            io:format("1. Check if EPMD is running on both nodes~n"),
            io:format("2. Verify the cookie matches on both nodes~n"),
            io:format("3. Check firewall settings (ports 4369, 9000-9100)~n"),
            io:format("4. Ensure hostname resolution works in both directions~n"),
            {error, connection_failed}
    end.
EOF

    # Run the test
    echo "Running Erlang connection test..."
    erl -sname test_$from_node \
        -setcookie "$COOKIE" \
        -noshell \
        -eval "{ok, _} = net_kernel:start([test_$from_node, shortnames]), io:format(\"Net kernel started.~n\"), c:l(erlang_test), erlang_test:test_connection(), erlang:halt()." \
        -s init stop \
        -pa .
}

# Main
main() {
    echo -e "${YELLOW}=== STARWEAVE Erlang Connection Test ===${NC}"
    echo "Main Node: $MAIN_NODE ($MAIN_IP)"
    echo "Worker Node: $WORKER_NODE ($WORKER_IP)"
    
    check_epmd
    
    # Test connection from main to worker
    test_erlang_connection "$MAIN_NODE" "test@$WORKER_NODE"
    
    echo -e "\n${YELLOW}=== Test Complete ===${NC}"
}

# Run the main function
main "$@"
