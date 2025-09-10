#!/bin/bash

# Main Node Startup Script for STARWEAVE
# This script starts the main node (STARCORE) with the web interface

# Set the node name and cookie
NODE_NAME=main
COOKIE=starweave-cookie
HOSTNAME=STARCORE
HTTP_PORT=4000

# Set distribution ports
DIST_MIN=9000
DIST_MAX=9100

echo "Starting STARWEAVE Main Node on $HOSTNAME..."
echo "HTTP server will be available on port $HTTP_PORT"

# Set the PORT environment variable for Phoenix
export PORT=$HTTP_PORT

# Start the Phoenix web server with distribution settings
echo "Starting Phoenix web server..."
iex \
  --sname $NODE_NAME \
  --cookie $COOKIE \
  --erl "-kernel inet_dist_listen_min $DIST_MIN inet_dist_listen_max $DIST_MAX" \
  -S mix phx.server

echo "Main node $NODE_NAME@$HOSTNAME started."
echo "Web interface available at http://$HOSTNAME:$HTTP_PORT"
