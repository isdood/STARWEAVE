# STARWEAVE Self-Knowledge System

## Overview
The Self-Knowledge System enables STARWEAVE to understand and reason about its own codebase through semantic search and code analysis. This document tracks implementation status and next steps.

## Notes
- The self-knowledge system is currently in development, therefore major changes are expected.
- The system is currently functional & STARWEAVE can answer questions about its own codebase via the web interface.
- Optimizations are being considered to improve performance, specifically when it comes to hallucination reduction.

## Primary Goal
Enable STARWEAVE to answer questions about its own codebase by:
1. Understanding when a user query requires knowledge base lookup
2. Retrieving relevant code snippets and documentation
3. Generating clear, context-aware responses with proper source attribution

## Architecture

## Architecture

### 1. Knowledge Representation
- **Code Chunks**: Functions, modules, and components with metadata
- **Embeddings**: Vector representations for semantic search (BERT-based)
- **Metadata**: File paths, line numbers, function signatures, and context
- **Relationships**: Cross-references between related code elements

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
- Automatic file indexing on startup

#### Query Service
- Basic query parsing and routing
- Integration with LLM for semantic search
- Support for hybrid search (semantic + keyword)
- Context-aware result formatting
- Result ranking and combination
- Basic file system watching for changes

### 🔄 In Progress

#### LLM Integration
- Enhancing prompt engineering for knowledge base queries
- Implementing query intent detection
- Response generation with source attribution
- Context management for multi-turn conversations

#### Embedding Service
- Integration with BERT/Sentence-BERT models
- Batch processing of embeddings
- Caching layer for performance
- Incremental updates for changed files

#### Code Indexer
- Improved code parsing and chunking
- Syntax-aware code segmentation
- Metadata extraction (function docs, types, etc.)

### 📋 Next Steps (Priority Order)
1. **Enhance LLM Integration**
   - [x] Implement query intent detection to identify when knowledge base lookup is needed
     - Added support for :knowledge_base, :documentation, and :code_explanation intents
     - Implements simple pattern matching with LLM fallback
     - Includes comprehensive test coverage
   - [x] Create prompt templates for code explanation and documentation
     - Implemented template system with namespaced templates
     - Added code explanation template with support for context, related functions, and references
     - Created template management modules for chat and code templates
   - [x] Add source attribution to generated responses
     - Enhanced ContextManager to track sources with message IDs
     - Integrated with WorkingMemory for persistent storage
     - Improved response formatting with source metadata
   - [x] Implement conversation context tracking
     - Added PersistentContext for saving/loading conversation history
     - Integrated with Memory.Supervisor for process management
     - Supports user-specific conversation history

2. **Improve Code Understanding**
   - [x] Enhance context extraction (function docs, type specs, module attributes)
   - [x] Implement cross-referencing between related code elements
   - [ ] Add support for Elixir-specific constructs (macros, protocols, behaviours)
   - [ ] Improve handling of different file types

3. **Performance Optimization**
   - [ ] Implement caching for frequent queries
   - [ ] Optimize DETS storage and retrieval
   - [ ] Add batching for large codebases
   - [ ] Implement background indexing for large repositories

4. **User Experience**
   - [ ] Add visual indicators when knowledge base is being queried
   - [ ] Implement response formatting with syntax highlighting
   - [ ] Add support for follow-up questions
   - [ ] Create a feedback mechanism for response quality

## Integration Points

### LLM Integration
- [x] Basic semantic search via embeddings
- [ ] Context-aware code explanations
- [ ] Automated code documentation
- [ ] "Explain this code" functionality
- [ ] Query intent detection
- [ ] Multi-turn conversation support

### Development Workflow
- [x] Basic file watching
- [ ] Git hooks for automatic updates
- [ ] CI/CD pipeline integration
- [ ] Automated testing of knowledge base responses

## Security & Reliability
- [x] Basic file operation validation
- [ ] Rate limiting for queries
- [ ] Access control for sensitive code
- [ ] Backup and recovery procedures

## Getting Started

### Prerequisites
- Elixir 1.12+
- Ollama with a suitable LLM model (e.g., llama3.1)
- DETS database (automatically managed)
- BERT/Sentence-BERT model for embeddings

### Quick Start
```bash
# Install dependencies
mix deps.get

# Start the system
iex -S mix phx.server
```

The system will automatically:
1. Initialize the knowledge base
2. Index available code
3. Start the web interface at http://localhost:4000

## Monitoring
- Telemetry for query performance
- Indexing status and progress
- Error tracking and logging

## Future Enhancements
1. **Multi-language Support**
   - Add support for JavaScript/TypeScript, Python, and other languages
   - Language-specific syntax highlighting and parsing

2. **Advanced Code Analysis**
   - Call graph generation
   - Usage pattern analysis
   - Dead code detection

3. **Developer Experience**
   - VS Code/IDE integration
   - Interactive code exploration UI
   - Automated test generation
   - Code review assistance

4. **Knowledge Base Expansion**
   - Integration with documentation tools
   - Learning from external documentation
   - Community-contributed knowledge
