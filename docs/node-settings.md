# STARWEAVE Node Connection Guide

This document outlines the correct configuration for connecting Erlang/Elixir nodes in the STARWEAVE distributed system, based on lessons learned during initial setup.

## Prerequisites

1. **Firewall Configuration**:
   ```bash
   # Required ports
   sudo firewall-cmd --add-port=4369/tcp --permanent    # EPMD port
   sudo firewall-cmd --add-port=9000-9100/tcp --permanent  # Node distribution ports
   sudo firewall-cmd --reload
   ```

2. **Hosts File**:
   Ensure both nodes can resolve each other's hostnames by adding to `/etc/hosts`:
   ```
   192.168.0.47    STARCORE
   192.168.0.49    001-LITE
   ```

## Common Issues and Solutions

### 1. Hostname Resolution
**Error**: `Hostname X is illegal` or connection timeouts
**Solution**:
- Use short names without domain for `-sname`
- Ensure `/etc/hosts` has correct IP-hostname mappings
- Verify with `ping <hostname>`

### 2. Port Configuration
**Error**: Connection timeouts or `econnrefused`
**Solution**:
- Verify EPMD is running: `epmd -names`
- Check firewall: `sudo firewall-cmd --list-ports`
- Ensure port range 9000-9100 is open on both nodes

### 3. Node Naming
**Correct Format**:
- Short names: `-sname mynode` (becomes `mynode@HOSTNAME`)
- Full names: `-name mynode@hostname` (requires FQDN resolution)

**Important**: If hostname contains hyphens, always quote the node name in Erlang:
```erlang
% Correct
net_adm:ping('worker@001-LITE').

% Will cause syntax error
net_adm:ping(worker@001-LITE).
```

## Working Connection Example

### On Worker Node (001-LITE):
```bash
erl -sname worker -setcookie starweave-cookie \
    -kernel inet_dist_listen_min 9000 \
    -kernel inet_dist_listen_max 9100
```

### On Main Node (STARCORE):
```bash
erl -sname main -setcookie starweave-cookie \
    -kernel inet_dist_listen_min 9000 \
    -kernel inet_dist_listen_max 9100
```

### In Main Node Shell:
```erlang
% Verify connection
net_adm:ping('worker@001-LITE').  % Should return 'pong'

% List connected nodes
nodes().

% Test remote execution
rpc:call('worker@001-LITE', erlang, node, []).
```

## Troubleshooting

1. **Verify EPMD**:
   ```bash
   epmd -names
   ```
   Should show registered nodes.

2. **Check Network**:
   ```bash
   # From main to worker
   nc -zv 001-LITE 4369  # EPMD port
   nc -zv 001-LITE 9000  # Distribution port
   ```

3. **Enable Verbose Logging**:
   ```erlang
   net_kernel:verbose(2).  % In Erlang shell before connecting
   ```

## Best Practices

1. Use the same Erlang/OTP version on all nodes
2. Use the same cookie for all nodes in the cluster
3. Document your node naming convention
4. Test connectivity with simple `net_adm:ping/1` before complex operations
5. Consider using distributed Erlang tools like `observer:start()` for monitoring
