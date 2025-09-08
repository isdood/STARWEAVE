# Starweave LLM

LLM integration and conversation management for the STARWEAVE project, providing a robust interface for interacting with language models like Ollama.

## Overview

Starweave LLM offers a comprehensive solution for managing LLM interactions, conversation context, and memory integration. It's designed to work seamlessly with the STARWEAVE ecosystem while providing flexible configuration for different LLM backends.

## Features

### 1. LLM Client

- **Ollama Integration**: Native support for Ollama's API
- **Model Management**: Easy configuration for different LLM models
- **Templating System**: Support for prompt templates
- **Streaming**: Efficient handling of streaming responses

### 2. Context Management

- **Conversation History**: Maintains context across multiple interactions
- **Token Management**: Tracks token usage and manages context windows
- **Context Summarization**: Automatically summarizes long conversations
- **Multi-turn Dialogues**: Supports complex, multi-turn conversations

### 3. Memory Integration

- **Working Memory**: Short-term memory for current conversation
- **Long-term Memory**: Integration with persistent storage
- **Contextual Recall**: Retrieves relevant past interactions
- **Memory Optimization**: Manages memory usage and pruning

## Installation

Add `starweave_llm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:starweave_llm, "~> 0.1.0"}
  ]
end
```

## Configuration

Configure the default LLM settings in your `config/config.exs`:

```elixir
config :starweave_llm,
  default_model: "llama3.1",
  ollama_host: "http://localhost:11434",
  max_tokens: 4000,
  max_history: 20
```

## Usage

### Basic Chat

```elixir
# Start a new conversation
{:ok, context} = StarweaveLlm.ContextManager.new()

# Send a message to the LLM
{:ok, response, updated_context} = 
  StarweaveLlm.OllamaClient.chat("Hello, world!", context: context)

# Continue the conversation
{:ok, response, updated_context} = 
  StarweaveLlm.OllamaClient.chat("What was my previous message?", context: updated_context)
```

### Using Templates

```elixir
template = """
You are a helpful assistant. The user's name is {{name}}.

User: {{prompt}}
Assistant:
"""

context = 
  context
  |> StarweaveLlm.ContextManager.put(:user_name, "Alex")
  |> StarweaveLlm.ContextManager.put(:template, template)

{:ok, response, _context} = 
  StarweaveLlm.OllamaClient.chat("What's the weather like?", context: context)
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at <https://hexdocs.pm/starweave_llm>.

## License

[Specify License]

