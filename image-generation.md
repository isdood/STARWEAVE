# Image Generation System - Implementation Plan

## Implementation Status

### ✅ Completed (Phase 1.1)
- [x] Defined Protocol Buffers schema for image generation service
- [x] Added necessary Python dependencies to requirements.txt
- [x] Created ImageGenerationServicer implementation
- [x] Integrated with existing gRPC server
- [x] Implemented model loading and caching with validation
- [x] Added comprehensive request validation and error handling
- [x] Integrated Stable Diffusion for image generation
- [x] Added health checks and monitoring endpoints
- [x] Implemented graceful shutdown and resource cleanup
- [x] Added disk and memory cache management
- [x] Added ROCm (AMD GPU) support with automatic fallback to CPU
- [x] Improved error handling for model loading and device management
- [x] Enhanced logging and diagnostics for better troubleshooting
- [x] Elixir gRPC client and supervisor
- [x] Canonical protobuf generation (single source of truth) via `services/python/protos/starweave.proto`
- [x] Protobuf generation script: `apps/starweave_llm/generate_protos.sh`
- [x] Mix task: `mix image.gen` for CLI image generation
- [x] End-to-end Elixir verification (outputs: `elixir_test_output.png`, `elixir_task_output.png`)

### 🔄 In Progress
- [ ] Performance optimization for concurrent requests
- [ ] Add more model variants and configurations
- [ ] Implement advanced image editing features
- [ ] Add comprehensive unit and integration tests
- [ ] Implement model warmup and preloading

### 📅 Up Next
- [ ] Template system integration
- [ ] Web interface components
- [ ] Testing and documentation

## Overview
The Image Generation System enables STARWEAVE to generate images based on natural language descriptions, enhancing its multi-modal capabilities. This system integrates with the existing gRPC infrastructure and web interface while maintaining clear separation between text and image generation services.

## Architecture

### Core Design Principles
- **Service Separation**: Maintain complete isolation between text (Ollama) and image generation services
- **gRPC Integration**: Use existing gRPC infrastructure for efficient Python model integration
- **Fault Tolerance**: Ensure text generation continues even if image generation fails
- **Progressive Enhancement**: Image generation enhances but doesn't replace text responses
- **Storage Integration**: Leverage existing pattern storage and memory systems

### System Components

#### 1. Image Generation Service (Python/gRPC)
- **Location**: `services/python/server/image_generation_servicer.py`
- **Framework**: gRPC service with health checking
- **Models**: HuggingFace Diffusers (Stable Diffusion v1.5 by default: `runwayml/stable-diffusion-v1-5`)
- **Features**:
  - Text-to-image generation
  - Model caching and management
  - Automatic model loading/unloading
  - Resource monitoring and cleanup
  - Graceful shutdown handling
  - Health check endpoints
  - Configurable cache sizes and cleanup intervals

##### Service Configuration
```bash
# Start the server with custom configuration
python -m server.image_generation_servicer \
    --port 50051 \
    --model-dir ./models \
    --max-models 2 \
    --max-disk-cache 10 \
    --cleanup-interval 300

# Check server logs for device information
# Should show something like:
# Initialized with device: cuda, dtype: torch.float16  # When using GPU/ROCm
# or
# Initialized with device: cpu, dtype: torch.float32  # When falling back to CPU
```

### Elixir Quickstart

#### Setup Prerequisites

1. **Install Protocol Buffers Compiler**
   - On Ubuntu/Debian:
     ```bash
     sudo apt-get update && sudo apt-get install -y protobuf-compiler
     ```
   - On macOS (using Homebrew):
     ```bash
     brew install protobuf
     ```

2. **Setup Elixir Protocol Buffers**
   ```bash
   # Run the setup script to configure your environment
   chmod +x setup_protoc.sh
   ./setup_protoc.sh
   
   # Source your shell configuration or restart your terminal
   source ~/.bashrc  # or ~/.zshrc
   
   # Verify the installation
   which protoc-gen-elixir
   ```

#### Generate Protobuf Modules

Generate Elixir modules from `starweave.proto`:

```bash
bash apps/starweave_llm/generate_protos.sh
```

Compile:

```bash
mix deps.get && mix compile
```

Verify end-to-end (requires Python gRPC server running on `localhost:50051`):

```bash
mix run test_image_gen.exs
```

Or generate directly via Mix task:

```bash
mix image.gen --prompt "A cozy cabin in the woods, snow" --out image.png \
  --width 512 --height 512 --steps 20 --guidance_scale 7.5
```

Options:
- `--model runwayml/stable-diffusion-v1-5` (default)
- `--seed <int>` (defaults to random)
- `--style <string>` (optional)

##### Environment Variables
- `CUDA_VISIBLE_DEVICES`: Control GPU visibility (e.g., "0" for first GPU)
- `TORCH_DTYPE`: Set tensor precision (float16, float32, bfloat16)
- `HF_HOME`: Custom HuggingFace cache directory
- `HSA_OVERRIDE_GFX_VERSION`: Set ROCm GPU version (e.g., "10.3.0")
- `HCC_AMDGPU_TARGET`: Set ROCm target architecture (e.g., "gfx1030")

##### Health Check Endpoint
```bash
# Check service health
grpc_cli call localhost:50051 grpc.health.v1.Health/Check ""
```

## Protobuf Consolidation

We now use a single canonical `.proto` source:

- Source of truth: `services/python/protos/starweave.proto`
- Elixir generation script: `apps/starweave_llm/generate_protos.sh`
- Generated Elixir modules: `apps/starweave_llm/lib/starweave_llm/image_generation/generated/`

Notes:
- The script ensures `protoc` and `protoc-gen-elixir` are available and adjusts include paths automatically.
- We added a guard around `apps/starweave_web/lib/starweave_web/grpc/starweave.pb.ex` to avoid redefining modules if they’re already loaded from the canonical generated modules.
- The `mix protobuf.gen` alias in `apps/starweave_web` now delegates to the canonical script.

#### 2. Elixir Integration Layer
- **Location**: `apps/starweave_llm/lib/starweave_llm/image_generation/`
- **Components**:
  - `ImageGenerator` - Main service client
  - `ImageRequest` - Request/response models
  - `ImageStore` - Integration with existing pattern storage
  - `ImageTemplates` - Prompt optimization templates

#### 3. Web Interface Integration
- **Location**: `apps/starweave_web/lib/starweave_web/live/`
- **Components**:
  - `ImageGenerationLive` - LiveView for image generation UI
  - `ChatComponent` updates for image display
  - Toggle controls for enabling/disabling image generation
  - Error state handling and user feedback

## Detailed Implementation Plan

### Phase 1: Foundation (Week 1)

#### 1.1 Protobuf Schema Extension
```protobuf
// services/python/protos/starweave.proto

service ImageGenerationService {
  // Generate image from text description
  rpc GenerateImage (ImageRequest) returns (ImageResponse) {}

  // Generate multiple images with variations
  rpc GenerateImageVariations (ImageVariationsRequest) returns (stream ImageResponse) {}

  // Get available models and capabilities
  rpc GetImageModels (ModelRequest) returns (ModelResponse) {}
}

message ImageRequest {
  string prompt = 1;              // Text description
  string model = 2;               // Model to use
  ImageSettings settings = 3;     // Generation parameters
  string user_id = 4;             // For user-specific generation
  repeated string context = 5;    // Conversation context
}

message ImageResponse {
  string request_id = 1;          // Correlation ID
  bytes image_data = 2;           // Generated image (PNG/JPEG)
  string format = 3;              // Image format
  GenerationMetadata metadata = 4; // Generation details
  string error = 5;               // Error message if failed
}

message ImageSettings {
  int32 width = 1;                // Image dimensions
  int32 height = 2;
  int32 steps = 3;                // Generation steps
  float guidance_scale = 4;       // Prompt adherence
  int32 seed = 5;                 // Random seed
  string style = 6;               // Art style preset
}
```

#### 1.2 Python Service Implementation
- Extend existing `pattern_server.py` with `ImageGenerationServicer`
- Implement HuggingFace Diffusers integration
- Add model loading and caching mechanisms
- Implement request validation and error handling
- Add health checks and monitoring endpoints

#### 1.3 Elixir Client Implementation
- Create `ImageGenerator` GenServer in `starweave_llm`
- Implement gRPC client with connection pooling
- Add request/response transformation layer
- Integrate with existing context management system

### Phase 2: Core Integration (Week 2)

#### 2.1 Template System Integration
- Extend existing template system for image prompts
- Create `ImageTemplates` module with optimization patterns
- Implement prompt enhancement for better image generation
- Add style and quality modifiers

#### 2.2 Context-Aware Generation
- Integrate with `ContextManager` for conversation-aware prompts
- Add pattern-based prompt enhancement
- Implement user preference learning
- Add conversation history integration

#### 2.3 Storage Integration
- Extend `PatternStore` for image metadata storage
- Implement image caching with DETS persistence
- Add image search and retrieval capabilities
- Integrate with existing memory systems

### Phase 3: Web Interface (Week 3)

#### 3.1 LiveView Components
- Create `ImageGenerationLive` for real-time image generation
- Extend existing chat components to display images
- Add loading states and progress indicators
- Implement image preview and comparison

#### 3.2 User Controls
- Add toggle switch for enabling/disabling image generation
- Create model selection dropdown
- Add generation parameter controls (style, size, quality)
- Implement batch generation controls

#### 3.3 Error Handling UI
- Display graceful error messages for failed generations
- Show fallback text when image generation unavailable
- Add retry mechanisms with exponential backoff
- Implement user feedback collection

### Phase 4: Advanced Features (Week 4)

#### 4.1 Multi-Model Support
- Implement model switching without restart
- Add model performance comparison
- Create model recommendation system
- Implement automatic model selection

#### 4.2 Image Enhancement
- Add upscaling capabilities
- Implement style transfer
- Add image-to-image generation
- Create image variation generation

#### 4.3 Analytics and Monitoring
- Add generation metrics collection
- Implement performance monitoring
- Create usage analytics dashboard
- Add A/B testing for prompt templates

## Error Handling Strategy

### Service-Level Error Handling
- **Connection Failures**: Automatic retry with exponential backoff
- **Model Loading Errors**: Graceful fallback to alternative models
- **Generation Timeouts**: Configurable timeouts with cancellation
- **Resource Exhaustion**: Queue management and load balancing

### User Experience Error Handling
- **Service Unavailable**: Clear messaging with text-only fallback
- **Generation Failure**: Retry options and alternative suggestions
- **Invalid Requests**: Input validation with helpful error messages
- **Rate Limiting**: User-friendly rate limit notifications

## Storage Architecture

### Image Metadata Storage
- **Primary Storage**: PostgreSQL for relational image metadata
- **Cache Layer**: ETS for frequently accessed image data
- **Persistence**: DETS for crash recovery and session persistence
- **Search Index**: Pattern-based indexing for image retrieval

### Image Data Storage
- **Blob Storage**: File system for generated images
- **CDN Integration**: Optional cloud storage for scalability
- **Retention Policy**: Configurable cleanup and archival
- **Backup Strategy**: Automated backup with integrity checking

## Integration Points

### Existing System Integration
- **ContextManager**: Conversation context for enhanced prompts
- **QueryService**: Intent detection for image vs text responses
- **Template System**: Prompt optimization and formatting
- **Memory Systems**: Pattern-based image storage and retrieval
- **ETS Dashboard**: Image generation monitoring and metrics

### External Dependencies
- **HuggingFace Diffusers**: Primary image generation backend
- **Torch/TensorFlow**: ML framework for model inference
- **Pillow**: Image processing and format conversion
- **gRPC**: Service communication protocol

## Testing Strategy

### Unit Testing
- Python service functionality tests
- Elixir client integration tests
- Template system validation tests
- Error handling scenario tests

### Integration Testing
- End-to-end image generation workflows
- Web interface interaction tests
- Multi-service communication tests
- Performance and load testing

### User Acceptance Testing
- Image quality assessment
- User experience validation
- Error scenario handling
- Cross-browser compatibility

## Deployment Considerations

### Development Environment
- Local HuggingFace model caching
- Development model configurations
- Debug logging and monitoring
- Hot reload capabilities

### Production Environment
- Model optimization and quantization
- GPU acceleration setup
- Load balancing and scaling
- Monitoring and alerting
- Backup and disaster recovery

## Success Metrics

### Technical Metrics
- **Generation Success Rate**: >95% successful generations
- **Average Generation Time**: <30 seconds for standard images
- **Service Availability**: >99.9% uptime
- **Error Recovery Rate**: <5% failed generations require manual intervention

### User Experience Metrics
- **User Engagement**: Increased interaction time with image capabilities
- **Satisfaction Score**: >4.5/5 user satisfaction rating
- **Feature Adoption**: >70% of users enable image generation
- **Error Tolerance**: <10% of users disable feature due to errors

## Future Enhancements

## Getting Started

### Prerequisites
- Python 3.8+
- CUDA-capable GPU (recommended)
- Docker (for containerized deployment)

### Installation
1. Create and activate virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```

2. Install dependencies:
   ```bash
   cd services/python
   pip install -r requirements.txt
   ```

3. Start the service:
   ```bash
   python -m server.image_generation_servicer
   ```

### Example Usage

#### Generate an Image (Python)
```python
import grpc
from starweave_pb2 import ImageRequest, ImageSettings
from starweave_pb2_grpc import ImageGenerationServiceStub

channel = grpc.insecure_channel('localhost:50051')
stub = ImageGenerationServiceStub(channel)

request = ImageRequest(
    prompt="A futuristic city at night, neon lights, cyberpunk style",
    settings=ImageSettings(
        width=768,
        height=768,
        steps=30,
        guidance_scale=7.5,
        seed=42
    ),
    model="runwayml/stable-diffusion-v1-5"
)

response = stub.GenerateImage(request)

# Save the generated image
with open('generated_image.png', 'wb') as f:
    f.write(response.image_data)
```

### Monitoring and Maintenance

#### Cache Management
The service automatically manages:
- GPU memory usage (unloads least recently used models)
- Disk cache (removes oldest models when space is needed)
- Model validation (verifies model integrity on load)

#### Logs
Logs include:
- Model loading/unloading events
- Generation statistics
- Resource usage
- Error conditions

### Short-term (Post-Launch)
- [ ] Video generation capabilities
- [ ] 3D model generation
- [ ] Advanced style transfer
- [ ] Custom model training
- [ ] Multi-modal prompts (text + image)
- [ ] Real-time generation progress
- [ ] User-specific model fine-tuning

### Long-term Vision
- Multi-modal generation (text + image)
- Interactive image editing
- Real-time style adaptation
- Collaborative generation features

---

*This plan provides a comprehensive roadmap for implementing image generation capabilities in STARWEAVE while maintaining system stability and user experience quality.*