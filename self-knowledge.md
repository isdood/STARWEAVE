# STARWEAVE Self-Knowledge System

## Overview
The Self-Knowledge System enables STARWEAVE to understand and reason about its own codebase through semantic search and code analysis. This document tracks implementation status and next steps.

This system should establish a foundation for adding additional databases to STARWEAVE in the future, ideally in a modular way.

## Architecture

### 1. Knowledge Representation
- **Code Chunks**: Functions, modules, and components with metadata
- **Embeddings**: Vector representations for semantic search (BERT-based)
- **Metadata**: File paths, dependencies, timestamps, and context

### 2. Data Model (Current Implementation)
```elixir
%{
  id: String.t(),
  content: String.t(),
  embedding: [float()] | nil,
  file_path: String.t(),
  line_number: integer() | nil,
  last_updated: DateTime.t(),
  context: map() | nil  # Additional metadata and context
}
```

## Implementation Status

### ✅ Completed Components

#### Knowledge Base
- DETS-based persistent storage
- CRUD operations for code knowledge
- Vector similarity search with cosine distance
- Text-based search capabilities with term frequency scoring
- Error handling and recovery

#### Query Service
- Basic query parsing and routing
- Integration with LLM for semantic search
- Support for hybrid search (semantic + keyword)
- Context-aware result formatting
- Result ranking and combination

### 🔄 In Progress

#### Embedding Service
- Integration with BERT/Sentence-BERT models
- Batch processing of embeddings
- Caching layer for performance

#### Code Indexer
- Basic file system watching
- Code parsing and chunking
- Incremental updates

### 📋 Next Steps (Priority Order)
1. **Enhance Query Interface**
   - ~~Implement hybrid search (combining semantic and keyword search)~~ ✅
   - ~~Add result ranking and filtering~~ ✅
   - ~~Support for complex queries with multiple intents~~ ✅
   - ~~Improve keyword search with more sophisticated scoring (TF-IDF, BM25)~~ ✅

2. **Improve Code Understanding**
   - Better context extraction (function docs, type specs)
   - Cross-referencing between code elements
   - Support for more file types

3. **Performance Optimization**
   - Implement caching for frequent queries
   - Optimize DETS storage and retrieval
   - Add batching for large codebases

4. **Developer Experience**
   - Better error messages and logging
   - Progress tracking for indexing
   - Integration with development tools

## Integration Points

### LLM Integration
- [x] Basic semantic search via embeddings
- [ ] Context-aware code explanations
- [ ] Automated code documentation
- [ ] "Explain this code" functionality

### Development Workflow
- [x] Basic file watching
- [ ] Git hooks for automatic updates
- [ ] CI/CD pipeline integration

## Security & Reliability
- [x] Basic file operation validation
- [ ] Rate limiting for queries
- [ ] Access control for sensitive code
- [ ] Backup and recovery procedures

## Getting Started

### Prerequisites
- Elixir 1.12+
- DETS database (automatically managed)
- BERT/Sentence-BERT model for embeddings

### Quick Start
```bash
# Install dependencies
mix deps.get

# Start the system
iex -S mix phx.server
```

The system will automatically initialize the knowledge base and begin indexing available code.

## Monitoring
- Telemetry for query performance
- Indexing status and progress
- Error tracking and logging

## Future Enhancements
1. Multi-language support
2. Automated test generation
3. Integration with documentation tools
4. Advanced code analysis (dependencies, usage patterns)
5. Interactive code exploration UI
