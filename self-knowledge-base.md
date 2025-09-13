# STARWEAVE Self-Knowledge Base

## Overview

This document outlines the plan to implement a distributed self-knowledge base for the STARWEAVE system, replacing the current ETS-based implementation with Mnesia for better distributed capabilities.

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

## Migration to Mnesia - In Progress

### Completed Work
1. **Mnesia Implementation**
   - [x] Created Mnesia-based storage modules for WorkingMemory and PatternStore
   - [x] Implemented proper table schemas with indexes
   - [x] Added support for TTL and importance scoring
   - [x] Updated GenServer modules to use Mnesia storage
   - [x] Configured disc_copies for persistence

2. **Schema Design**
   - Working Memory Table:
     - Attributes: `[:id, :context, :key, :value, :metadata]`
     - Type: `:set`
     - Indexes: `[:context, :key]`
   - Pattern Store Table:
     - Attributes: `[:id, :pattern, :inserted_at]`
     - Type: `:set`
     - Indexes: `[:inserted_at]`

### Next Steps
1. **Dependency Resolution**
   - [ ] Add Memento to the project dependencies
   - [ ] Configure Mnesia data directory
   - [ ] Update application startup sequence

2. **Testing & Validation**
   - [ ] Test basic CRUD operations
   - [ ] Verify persistence across restarts
   - [ ] Test distributed operation

### Phase 2: Core Implementation
1. **Mnesia Setup**
   - [ ] Configure Mnesia in application.ex
   - [ ] Set up table creation on application start
   - [ ] Implement schema management

2. **Storage Module**
   - [ ] Create `StarweaveCore.KnowledgeBase.Storage`
   - [ ] Implement CRUD operations
   - [ ] Add transaction support

3. **Data Access Layer**
   - [ ] Create `StarweaveCore.KnowledgeBase` context
   - [ ] Implement business logic
   - [ ] Add validation and error handling

### Phase 3: Distribution & Sync
1. **Cluster Integration**
   - [ ] Configure Mnesia for distributed operation
   - [ ] Implement node discovery
   - [ ] Add conflict resolution

2. **Synchronization**
   - [ ] Implement change propagation
   - [ ] Add conflict detection/resolution
   - [ ] Handle network partitions

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

### Mnesia Configuration
```elixir
config :mnesia,
  dir: 'priv/data/mnesia',
  debug: :verbose
```

### .gitignore Updates
```
# Mnesia data
/priv/data/mnesia/

# Legacy ETS data
/priv/data/memories/working_memory.etf
```

## Monitoring & Maintenance
- [ ] Add Prometheus metrics
- [ ] Set up health checks
- [ ] Implement backup/restore procedures

## Testing Strategy
1. **Unit Tests**
   - [ ] Basic CRUD operations
   - [ ] Transaction handling

2. **Integration Tests**
   - [ ] Multi-node operations
   - [ ] Failure scenarios

3. **Load Testing**
   - [ ] Performance benchmarks
   - [ ] Stress testing

## Rollout Plan
1. Deploy to development environment
2. Test with single node
3. Scale to multiple nodes
4. Monitor performance
5. Roll out to production

## Future Enhancements
- [ ] Query optimization
- [ ] Advanced indexing
- [ ] Offline support
- [ ] Conflict-free Replicated Data Types (CRDTs)

## Notes
- Current ETS data can be discarded as it's only test data
- Will need to coordinate deployment with team
- Consider implementing feature flags for gradual rollout
