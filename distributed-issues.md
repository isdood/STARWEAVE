## Distributed Issues

./scripts/distributed/worker-node-init.sh --node-name worker1 --main-node main@192.168.0.47 --cookie starweave-cookie --port 4010

isdood@001-LITE ~/STARWEAVE (main)> ./scripts/distributed/worker-node-init.sh --node-name worker1 --main-node main@192.168.0.47 --cookie starweave-cookie -
-port 4010
⚡ STARWEAVE Worker Node Configuration ⚡
Node Name: worker1@001-LITE
Main Node: main@192.168.0.47
Cookie: starweave-cookie
Distribution Port: 4010
Environment: dev
Project Root: /home/isdood/STARWEAVE/scripts/..

Setting Erlang cookie...
Warning: Cannot write to /home/isdood/.erlang.cookie. Using alternative location.
Using temporary cookie file at: /tmp/erlang.cookie.1000
Warning: /tmp/erlang.cookie.1000 already exists. Backing it up to /tmp/erlang.cookie.1000.bak
Checking connection to main node at main@192.168.0.47...
Warning: Cannot connect to EPMD on 192.168.0.47:4369
Please ensure the main node is running and accessible.
If the main node is behind a firewall, make sure port 4369 (EPMD) and 4010 (distribution) are open.