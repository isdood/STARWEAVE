# STARWEAVE Self-Knowledge Base

## Overview

This document outlines the implementation of a persistent self-knowledge base for the STARWEAVE system, using DETS (Disk-Based Term Storage) for reliable data persistence across application restarts.

## Current Implementation

### ETS Storage Inventory

#### 1. Working Memory (`StarweaveCore.Intelligence.WorkingMemory`)
- **File**: `apps/starweave_core/lib/starweave_core/intelligence/working_memory.ex`
- **Table Name**: `:starweave_working_memory`
- **Type**: `:set` with `:public` access
- **Features**:
  - Persistence to disk via `MemoryPersistence`
  - TTL support for entries
  - Context-based organization
  - Importance scoring
- **Key Operations**:
  - `store/4`: Store key-value pairs with TTL
  - `retrieve/2`: Get value by key
  - `get_context/1`: Get all entries in a context
  - `search/2`: Full-text search

#### 2. Distributed Working Memory (`StarweaveCore.Intelligence.DistributedWorkingMemory`)
- **File**: `apps/starweave_core/lib/starweave_core/intelligence/distributed_working_memory.ex`
- **Purpose**: Distributed version of WorkingMemory with sharding and replication
- **Key Features**:
  - Uses process groups (`:pg` module) for node membership
  - Consistent hashing for sharding
  - Configurable replication factor (default: 2)
  - Local caching for performance
  - Automatic retry for failed operations
- **Configuration Options**:
  - `:replicas` - Number of replicas (default: 2)
  - `:retry_attempts` - Operation retry attempts (default: 3)
  - `:retry_delay` - Delay between retries in ms (default: 100)
- **Key Operations**:
  - `store/4`: Distributed storage with replication
  - `retrieve/2`: Consistent retrieval with local caching
  - `get_context/1`: Context-based retrieval across nodes
  - `search/2`: Distributed search across all nodes

#### 3. Pattern Store (`StarweaveCore.PatternStore`)
- **File**: `apps/starweave_core/lib/starweave_core/pattern_store.ex`
- **Table Name**: `:starweave_patterns`
- **Type**: `:set` with `:public` access and `read_concurrency: true`
- **Features**:
  - Simple key-value storage for patterns
  - No persistence (in-memory only)
- **Key Operations**:
  - `put/1`: Store a pattern
  - `get/1`: Retrieve a pattern by ID
  - `all/0`: List all patterns

### Current Limitations
- **Single-node focused**: ETS tables are local to each node
- **Manual synchronization**: No automatic sync between nodes
- **Limited query capabilities**: Basic pattern matching only
- **No built-in distribution**: Requires custom implementation for multi-node

## Migration to DETS - Completed

### Implementation Details
1. **DETS Implementation**
   - [x] Replaced ETS with DETS for persistent task storage
   - [x] Added robust error handling and recovery for DETS table initialization
   - [x] Implemented automatic directory creation for DETS files
   - [x] Added retry logic for corrupted DETS files
   - [x] Ensured proper cleanup on process termination

2. **Storage Details**
   - **DETS File Location**: `agent_tasks.dets` in the application's data directory
   - **Table Type**: `:set` with `:public` access
   - **Persistence**: Automatic disk-based persistence
   - **Recovery**: Automatic recovery from corrupted files with retry mechanism

### Implementation Status
1. **Core Implementation**
   - [x] DETS table initialization in application.ex
   - [x] Automatic table creation on application start
   - [x] Schema management for task data

2. **Storage Module**
   - [x] Implemented in `StarweaveCore.Intelligence.WorkingMemory`
   - [x] Complete CRUD operations with DETS backend
   - [x] Transaction support for data consistency

3. **Data Access Layer**
   - [x] Integrated with existing WorkingMemory context
   - [x] Robust error handling and validation
   - [x] Automatic cleanup and maintenance

### Phase 4: API & Integration
1. **Public API**
   - [ ] Define clean function interfaces
   - [ ] Add telemetry
   - [ ] Implement access controls

2. **LLM Integration**
   - [ ] Create knowledge base query interface
   - [ ] Add self-description capabilities
   - [ ] Implement auto-update triggers

## Configuration

### DETS Configuration
```elixir
# DETS file location is managed by the application
# Automatic directory creation is handled by the WorkingMemory module
```

### .gitignore Updates
```
# DETS data files
*.dets
*.dets.*

# Legacy data
/priv/data/memories/working_memory.etf
```

## Monitoring & Maintenance
- [x] Integrated with existing ETS dashboard for monitoring
- [x] Health checks for DETS file integrity
- [x] Automatic recovery from corrupted files

## Testing Strategy
1. **Unit Tests**
   - [x] Basic CRUD operations
   - [x] Transaction handling
   - [x] Error recovery scenarios

2. **Integration Tests**
   - [x] Data persistence across restarts
   - [x] File corruption recovery
   - [x] Concurrent access patterns

3. **Performance**
   - [x] Benchmarked against ETS for read/write operations
   - [x] Memory usage optimization

## Implementation Notes
- Successfully migrated from ETS to DETS for persistent storage
- Simplified the architecture while maintaining data persistence
- Improved error handling and recovery mechanisms

## Future Enhancements
- [ ] Consider distributed storage solutions if multi-node support becomes a requirement
- [ ] Implement periodic backup of DETS files
- [ ] Add monitoring hooks for DETS file size and health

## Maintenance
- DETS files are automatically maintained by the application
- No manual intervention required for normal operation
- Logs will indicate if any maintenance actions are needed
