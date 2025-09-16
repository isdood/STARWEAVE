# STARWEAVE Self-Knowledge System

## Overview
The Self-Knowledge System is a core component of STARWEAVE that enables the AI to understand and reason about its own codebase. This document outlines the architecture and implementation plan for building this system.

## Architecture

### 1. Knowledge Representation
- **Code Chunks**: Break down code into meaningful chunks (functions, modules, components)
- **Embeddings**: Generate vector embeddings for semantic search
- **Metadata**: Store additional context (file path, dependencies, last modified, etc.)

### 2. Data Model
```elixir
%SelfKnowledge.Entry{
  id: String.t(),
  content: String.t(),
  embedding: [float()],
  file_path: String.t(),
  module: String.t(),
  function: String.t() | nil,
  docstring: String.t() | nil,
  last_updated: DateTime.t(),
  dependencies: [String.t()],
  tags: [String.t()]
}
```

### 3. Components

#### 3.1 Code Indexer ✅
- ✅ Watches the codebase for changes
- ✅ Parses Elixir/other source files
- ✅ Extracts code chunks and metadata
- ⏳ Generates embeddings using a local model (partial)
- ✅ Updates the knowledge base

#### 3.2 Knowledge Base ✅
- ✅ DETS-based storage for code knowledge
- ✅ Basic search capabilities
- ✅ Versioning support
- ✅ Index management
- ⏳ Vector similarity search (partial)

#### 3.3 Query Interface ⏳
- ✅ Basic natural language to code search
- ⏳ Context-aware code retrieval (basic implementation)
- ⏳ Integration with LLM for better understanding (planned)

## Implementation Plan

### Phase 1: Basic Indexing ✅
1. ✅ Set up file system watcher for the codebase
2. ✅ Implement Elixir source code parser (basic)
3. ✅ Create basic DETS schema for code knowledge
4. ⏳ Build embedding generation pipeline (in progress)

### Phase 2: Query Capabilities ⏳
1. ⏳ Implement vector similarity search (basic implementation)
2. ✅ Create basic query parser and processor
3. ✅ Add basic natural language understanding
4. ✅ Integrate with existing DETS dashboard

### Phase 3: Advanced Features
1. Code change detection and incremental updates
2. Cross-reference analysis
3. Usage pattern tracking
4. Automated documentation generation

## Database Schema

### DETS Tables
1. `:code_chunks` - Primary storage for code knowledge
2. `:embeddings` - Vector embeddings for semantic search
3. `:file_metadata` - Tracking file changes and hashes
4. `:dependencies` - Code dependency graph

## Current Status

### Completed
- Basic code indexing and storage in DETS
- File system monitoring for changes
- Basic query interface
- Integration with DETS dashboard
- Telemetry setup

### In Progress
- Vector embeddings for semantic search
- Advanced code parsing (extracting functions, modules, etc.)
- Performance optimizations

### Up Next
- Enhanced natural language understanding
- Cross-referencing between code elements
- Automated documentation generation

## Integration Points

1. **LLM Integration**:
   - Use embeddings for semantic search
   - Provide code context in prompts
   - Enable "explain this code" functionality

2. **Development Workflow**:
   - Git hooks for automatic updates
   - CI/CD pipeline integration
   - Development server hot-reload support

## Security Considerations
- Validate all file system operations
- Sanitize code before processing
- Implement access controls for sensitive code
- Consider rate limiting for queries

## Future Enhancements
1. Multi-language support
2. Integration with documentation
3. Automated test generation
4. Performance optimization for large codebases

## Getting Started

### Prerequisites
- Elixir 1.12+
- DETS database
- Local embedding model (e.g., BERT, Sentence-BERT)

### Setup
1. Clone the repository
2. Run `mix deps.get`
3. Start the development server with `iex -S mix phx.server`
4. The self-knowledge system will automatically index the codebase

## Monitoring and Maintenance
- Monitor indexing performance
- Track query patterns
- Regular database maintenance
- Backup and recovery procedures
