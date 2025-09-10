#!/bin/bash

# Worker Node Startup Script for STARWEAVE
# This script starts a worker node (001-LITE) that connects to the main node

# Set the node name and cookie
NODE_NAME=worker
COOKIE=starweave-cookie
HOSTNAME=001-LITE
MAIN_NODE=main@STARCORE

# Set distribution ports
DIST_MIN=9000
DIST_MAX=9100

echo "Starting STARWEAVE Worker Node on $HOSTNAME..."
echo "Will connect to main node: $MAIN_NODE"

# Start the Erlang node with distribution settings
erl \
  -sname $NODE_NAME \
  -setcookie $COOKIE \
  -kernel inet_dist_listen_min $DIST_MIN \
  -kernel inet_dist_listen_max $DIST_MAX \
  -eval 'io:format("Worker node started. To connect to main node, run: net_adm:ping(\'$MAIN_NODE\').").' \
  -s init stop

# After the Erlang shell exits, start the IEx session with the same settings
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  --erl "-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
  -S mix
