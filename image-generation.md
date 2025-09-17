## Image Generation System

### Overview
The Image Generation System is a component of STARWEAVE that enables the AI to generate images based on natural language descriptions. This document outlines the architecture and implementation plan for building this system.

### Architecture

- We'll likely use our gRPC server to interface with HuggingFace's image generation models (Stable Diffusion, DALL-E, etc.) - this will likely allow for more efficient image generation than using Elixir directly, while also offering much more flexibility in terms of the models we can use. We should at least research and explore alternatives however, such as Ollama's image based models or Elixir's Bumblebee library.
- Define a system for the web interface to make a request to the gRPC server and return the image to the user; "Generate an image of a cat".
- There should be a clear seperation between the Ollama text generation and image generation models - should an image request to the gRPC server fail, the web interface should still be able to generate text using the Ollama text generation model, indicating to the user that the image generation service is unavailable.