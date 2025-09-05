#!/bin/bash

# Simple script to check the Erlang cookie

echo "Current Erlang cookie in ~/.erlang.cookie:"
if [ -f "$HOME/.erlang.cookie" ]; then
    echo -n "Value: "
    cat "$HOME/.erlang.cookie"
    echo -e "\nPermissions: $(ls -l "$HOME/.erlang.cookie" | awk '{print $1}')"
else
    echo "No .erlang.cookie file found in $HOME/"
fi
