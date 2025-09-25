"""
Image Generation Service for STARWEAVE

This module implements the gRPC service for generating images using HuggingFace Diffusers.
"""
import os
import sys
import time
import uuid
import hashlib
import json
import threading
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
from concurrent import futures
from io import BytesIO
from enum import Enum
import re

import grpc
from loguru import logger
from PIL import Image, ImageFile
import torch
from diffusers import (
    StableDiffusionPipeline,
    DPMSolverSinglestepScheduler,
    StableDiffusionImg2ImgPipeline,
    StableDiffusionInpaintPipeline
)
from diffusers.pipelines.stable_diffusion.safety_checker import (
    StableDiffusionSafetyChecker
)

# Health service imports
from grpc_health.v1 import health
from grpc_health.v1 import health_pb2
from grpc_health.v1 import health_pb2_grpc

# Enable loading of truncated images
ImageFile.LOAD_TRUNCATED_IMAGES = True

# Constants
DEFAULT_MODEL = "stabilityai/stable-diffusion-2-1"

# Check for ROCm (AMD GPU) support
HAS_ROCM = False
try:
    import torch
    HAS_ROCM = torch.version.hip is not None
except:
    pass

def _get_default_device():
    """Determine the default device to use for PyTorch operations."""
    if torch.cuda.is_available():
        return "cuda", torch.float16
    elif HAS_ROCM:
        # Set environment variables for ROCm
        os.environ["HSA_OVERRIDE_GFX_VERSION"] = "10.3.0"  # Adjust based on your GPU
        os.environ["HCC_AMDGPU_TARGET"] = "gfx1030"  # Adjust based on your GPU
        return "cuda", torch.float16  # ROCm uses CUDA API
    return "cpu", torch.float32

# Global device and dtype settings
DEFAULT_DEVICE, DEFAULT_TORCH_DTYPE = _get_default_device()
MAX_IMAGE_SIZE = 1024  # Maximum width/height for generated images
MIN_IMAGE_SIZE = 128   # Minimum width/height for generated images
MAX_PROMPT_LENGTH = 1000
MAX_STEPS = 100
MAX_BATCH_SIZE = 4

class ModelType(Enum):
    TEXT_TO_IMAGE = "text-to-image"
    IMAGE_TO_IMAGE = "image-to-image"
    INPAINTING = "inpainting"

@dataclass
class ModelConfig:
    """Configuration for a single model."""
    model_id: str
    name: str
    description: str
    type: ModelType = ModelType.TEXT_TO_IMAGE
    default_size: Tuple[int, int] = (768, 768)
    supported_sizes: List[Tuple[int, int]] = field(default_factory=lambda: [(512, 512), (768, 768)])
    requires_safety_checker: bool = True
    requires_scheduler: bool = True
    requires_vae: bool = False
    min_steps: int = 10
    max_steps: int = 50
    default_steps: int = 25
    default_guidance_scale: float = 7.5
    default_seed: int = -1  # -1 means random
    enabled: bool = True

# Import generated protobuf code
from starweave_pb2 import (
    ImageRequest,
    ImageResponse,
    ImageSettings,
    ImageVariationsRequest,
    ModelRequest,
    ModelResponse,
    GenerationMetadata,
)
from starweave_pb2_grpc import ImageGenerationServiceServicer, add_ImageGenerationServiceServicer_to_server

@dataclass
class ModelInfo:
    """Container for model information and pipeline."""
    config: ModelConfig
    pipeline: Optional[Any] = None
    loaded: bool = False
    loading: bool = False
    load_error: Optional[str] = None
    last_used: float = 0.0
    memory_usage: int = 0  # In bytes
    load_count: int = 0
    error_count: int = 0

class ImageGenerationServicer(ImageGenerationServiceServicer):
    """gRPC servicer for image generation requests."""
    
    def __init__(self, model_dir: str = "./models", max_models_in_memory: int = 2, 
                 max_disk_cache_gb: float = 10.0, cleanup_interval: int = 300):
        """Initialize the image generation service.
        
        Args:
            model_dir: Directory to store model caches and metadata
            max_models_in_memory: Maximum number of models to keep in GPU memory
            max_disk_cache_gb: Maximum disk space to use for model cache (in GB)
            cleanup_interval: How often to run cleanup (in seconds)
        """
        # Initialize device settings
        self.device = DEFAULT_DEVICE
        self.torch_dtype = DEFAULT_TORCH_DTYPE
        
        self.model_dir = Path(model_dir)
        self.max_models_in_memory = max_models_in_memory
        self.max_disk_cache_bytes = int(max_disk_cache_gb * 1024 * 1024 * 1024)
        self.cleanup_interval = cleanup_interval
        self._models_lock = threading.RLock()
        self._models: Dict[str, ModelInfo] = {}
        self._cache_metadata_path = self.model_dir / "cache_metadata.json"
        self._stop_event = threading.Event()
        
        logger.info(f"Initialized with device: {self.device}, dtype: {self.torch_dtype}")
        
        # Initialize models and load cache state
        self.model_dir.mkdir(parents=True, exist_ok=True)
        self._init_models()
        self._load_cache_metadata()
        
        # Start with the default model loaded
        self._load_model(DEFAULT_MODEL)
        
        # Start maintenance threads
        self._cleanup_thread = threading.Thread(
            target=self._cleanup_models_loop,
            daemon=True,
            name="ModelCleanupThread"
        )
        self._cleanup_thread.start()
        
        # Start disk cache management thread
        self._disk_cleanup_thread = threading.Thread(
            target=self._manage_disk_cache_loop,
            daemon=True,
            name="DiskCacheManagerThread"
        )
        self._disk_cleanup_thread.start()
    
    def _load_cache_metadata(self):
        """Load cache metadata from disk."""
        if not self._cache_metadata_path.exists():
            return
            
        try:
            with open(self._cache_metadata_path, 'r') as f:
                cache_data = json.load(f)
                
            with self._models_lock:
                for model_id, model_info in cache_data.items():
                    if model_id in self._models:
                        self._models[model_id].last_used = model_info.get('last_used', 0)
                        self._models[model_id].load_count = model_info.get('load_count', 0)
                        self._models[model_id].error_count = model_info.get('error_count', 0)
                        
        except Exception as e:
            logger.warning(f"Failed to load cache metadata: {e}")
    
    def _save_cache_metadata(self):
        """Save cache metadata to disk."""
        try:
            cache_data = {}
            with self._models_lock:
                for model_id, model_info in self._models.items():
                    cache_data[model_id] = {
                        'last_used': model_info.last_used,
                        'load_count': model_info.load_count,
                        'error_count': model_info.error_count
                    }
            
            # Write to temporary file first, then rename (atomic operation)
            temp_path = f"{self._cache_metadata_path}.tmp"
            with open(temp_path, 'w') as f:
                json.dump(cache_data, f, indent=2)
            
            # Atomic rename on POSIX systems
            if os.name == 'posix':
                os.replace(temp_path, self._cache_metadata_path)
            else:
                # Fallback for Windows
                if os.path.exists(self._cache_metadata_path):
                    os.remove(self._cache_metadata_path)
                os.rename(temp_path, self._cache_metadata_path)
                
        except Exception as e:
            logger.error(f"Failed to save cache metadata: {e}")
    
    def _cleanup_models_loop(self):
        """Background thread to periodically clean up unused models."""
        while not self._stop_event.is_set():
            try:
                self._cleanup_models()
                self._save_cache_metadata()  # Persist state after cleanup
            except Exception as e:
                logger.error(f"Error in cleanup thread: {e}")
            
            # Wait for the next cleanup interval or stop event
            self._stop_event.wait(self.cleanup_interval)
    
    def _manage_disk_cache_loop(self):
        """Background thread to manage disk cache size."""
        while not self._stop_event.is_set():
            try:
                self._cleanup_disk_cache()
            except Exception as e:
                logger.error(f"Error in disk cache manager: {e}")
            
            # Check disk cache less frequently than memory cache
            self._stop_event.wait(self.cleanup_interval * 2)
    
    def _get_disk_usage(self, path: Path) -> int:
        """Calculate total disk usage of a directory in bytes."""
        total_size = 0
        for dirpath, _, filenames in os.walk(path):
            for f in filenames:
                try:
                    fp = os.path.join(dirpath, f)
                    total_size += os.path.getsize(fp)
                except (OSError, AttributeError):
                    continue
        return total_size
    
    def _cleanup_disk_cache(self):
        """Clean up old model caches to stay under disk quota."""
        cache_dir = self.model_dir / "diffusers"
        if not cache_dir.exists():
            return
        
        # Get all model cache directories with their last access times
        model_dirs = []
        for model_dir in cache_dir.iterdir():
            if not model_dir.is_dir():
                continue
                
            try:
                last_used = os.path.getatime(model_dir)
                size = self._get_disk_usage(model_dir)
                model_dirs.append({
                    'path': model_dir,
                    'last_used': last_used,
                    'size': size
                })
            except (OSError, AttributeError):
                continue
        
        # Sort by last used (oldest first)
        model_dirs.sort(key=lambda x: x['last_used'])
        
        # Calculate current disk usage
        total_size = sum(d['size'] for d in model_dirs)
        
        # Remove old caches until we're under the limit
        while model_dirs and total_size > self.max_disk_cache_bytes * 0.9:  # Target 90% of max
            oldest = model_dirs.pop(0)
            try:
                logger.info(f"Removing old model cache: {oldest['path'].name}, size: {oldest['size'] / (1024*1024):.2f}MB")
                import shutil
                shutil.rmtree(oldest['path'])
                total_size -= oldest['size']
            except Exception as e:
                logger.error(f"Failed to remove {oldest['path']}: {e}")
    
    def stop(self):
        """Stop background threads and clean up resources."""
        self._stop_event.set()
        
        # Wait for threads to finish
        if self._cleanup_thread.is_alive():
            self._cleanup_thread.join(timeout=5)
        if self._disk_cleanup_thread.is_alive():
            self._disk_cleanup_thread.join(timeout=5)
        
        # Save final state
        self._save_cache_metadata()
        
        # Unload all models
        with self._models_lock:
            for model_id, model_info in list(self._models.items()):
                if model_info.loaded and model_info.pipeline is not None:
                    self._unload_model(model_id, model_info)
        
        # Clean up CUDA cache
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
    
    def _init_models(self):
        """Initialize the available models with their configurations."""
        model_configs = [
            ModelConfig(
                model_id="stabilityai/stable-diffusion-2-1",
                name="Stable Diffusion 2.1",
                description="Stable Diffusion 2.1 model with 768x768 resolution",
                type=ModelType.TEXT_TO_IMAGE,
                default_size=(768, 768),
                supported_sizes=[(512, 512), (768, 768)],
                min_steps=10,
                max_steps=100,
                default_steps=30
            ),
            ModelConfig(
                model_id="runwayml/stable-diffusion-v1-5",
                name="Stable Diffusion 1.5",
                description="Stable Diffusion 1.5 model with 512x512 resolution",
                type=ModelType.TEXT_TO_IMAGE,
                default_size=(512, 512),
                supported_sizes=[(384, 384), (512, 512)],
                min_steps=10,
                max_steps=100,
                default_steps=25
            ),
            # Add more models as needed
        ]
        
        for config in model_configs:
            self._models[config.model_id] = ModelInfo(config=config)
    
    def _cleanup_models(self):
        """Unload unused models when memory is low."""
        with self._models_lock:
            # Get all currently loaded models
            loaded_models = [
                (model_id, info) 
                for model_id, info in self._models.items() 
                if info.loaded and info.pipeline is not None
            ]
            
            # If we're over the limit, unload the least recently used models
            if len(loaded_models) > self.max_models_in_memory:
                # Sort by last_used (oldest first) and error count (prioritize keeping reliable models)
                loaded_models.sort(key=lambda x: (x[1].last_used, x[1].error_count))
                
                # Calculate how many to unload
                num_to_unload = len(loaded_models) - self.max_models_in_memory
                if num_to_unload <= 0:
                    return
                
                logger.info(f"Unloading {num_to_unload} models to maintain memory limit of {self.max_models_in_memory}")
                
                # Unload models until we're under the limit
                for model_id, model_info in loaded_models[:num_to_unload]:
                    if model_id == DEFAULT_MODEL and len(loaded_models) > 1:
                        # Skip default model if possible
                        continue
                    self._unload_model(model_id, model_info)
                    
                    # If we've unloaded enough, stop
                    if len([m for m in self._models.values() if m.loaded and m.pipeline is not None]) <= self.max_models_in_memory:
                        break
            
            # Check CUDA memory usage and unload models if needed
            if torch.cuda.is_available():
                try:
                    # Get current CUDA memory usage
                    total_mem = torch.cuda.get_device_properties(0).total_memory
                    reserved = torch.cuda.memory_reserved(0)
                    allocated = torch.cuda.memory_allocated(0)
                    free_mem = total_mem - allocated
                    
                    # If we're using more than 90% of GPU memory, unload some models
                    if allocated > total_mem * 0.9:
                        logger.warning(f"High GPU memory usage ({allocated/1024**3:.2f}/{total_mem/1024**3:.2f}GB), forcing model cleanup")
                        
                        # Sort models by size (largest first) and unload until we have enough free memory
                        loaded_models.sort(key=lambda x: x[1].memory_usage, reverse=True)
                        
                        for model_id, model_info in loaded_models:
                            if model_id == DEFAULT_MODEL and len(loaded_models) > 1:
                                continue  # Try to keep default model loaded
                                
                            self._unload_model(model_id, model_info)
                            
                            # Check if we've freed enough memory
                            torch.cuda.empty_cache()
                            allocated = torch.cuda.memory_allocated(0)
                            if allocated <= total_mem * 0.7:  # Target 70% usage
                                break
                                
                except Exception as e:
                    logger.error(f"Error checking CUDA memory: {e}")
                    # If we can't check memory, do a conservative cleanup
                    if len(loaded_models) > 1:
                        for model_id, model_info in loaded_models[1:]:  # Keep first model
                            self._unload_model(model_id, model_info)
                            if len([m for m in self._models.values() if m.loaded]) <= max(1, self.max_models_in_memory // 2):
                                break
    
    def _unload_model(self, model_id: str, model_info: ModelInfo):
        """Unload a model from memory."""
        try:
            if model_info.pipeline is not None:
                # Move pipeline to CPU first to free GPU memory
                if hasattr(model_info.pipeline, 'to'):
                    model_info.pipeline.to('cpu')
                
                # Explicitly delete the pipeline and clear CUDA cache
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                
                model_info.pipeline = None
                model_info.loaded = False
                logger.info(f"Unloaded model: {model_id}")
                
        except Exception as e:
            logger.error(f"Error unloading model {model_id}: {e}")
            model_info.error_count += 1
    
    def _get_model_info(self, model_id: str) -> Optional[ModelInfo]:
        """Get model info, loading it if necessary."""
        with self._models_lock:
            if model_id not in self._models:
                return None
                
            model_info = self._models[model_id]
            
            # Update last used timestamp
            model_info.last_used = time.time()
            
            if not model_info.loaded and not model_info.loading:
                self._load_model(model_id)
                
            return model_info
    
    def _validate_model(self, pipe, model_config: ModelConfig) -> Tuple[bool, str]:
        """Validate that the loaded model meets requirements."""
        try:
            # Check required components
            if not hasattr(pipe, 'unet') or not hasattr(pipe, 'text_encoder') or not hasattr(pipe, 'vae'):
                return False, "Missing required model components (UNet, TextEncoder, or VAE)"
                
            # Check model type matches expected
            if model_config.type == ModelType.TEXT_TO_IMAGE and not isinstance(pipe, StableDiffusionPipeline):
                return False, f"Expected text-to-image model but got {type(pipe).__name__}"
                
            # Check model dimensions
            if hasattr(pipe, 'unet') and hasattr(pipe.unet.config, 'sample_size'):
                sample_size = pipe.unet.config.sample_size
                expected_size = 64  # SD 2.1 base size
                if sample_size != expected_size:
                    return False, f"Unexpected UNet sample size: {sample_size} (expected {expected_size})"
                    
            return True, ""
            
        except Exception as e:
            return False, f"Validation error: {str(e)}"
            
    def _warmup_model(self, pipe, model_config: ModelConfig) -> Tuple[bool, str]:
        """Warm up the model with a test generation."""
        try:
            # Use a small, fast test prompt
            test_prompt = "a small red square"
            test_settings = ImageSettings(
                width=64,
                height=64,
                steps=2,
                guidance_scale=1.0
            )
            
            # Run a test generation
            with torch.inference_mode():
                self._generate_image(
                    pipe=pipe,
                    prompt=test_prompt,
                    settings=test_settings,
                    num_images_per_prompt=1
                )
                
            return True, ""
            
        except Exception as e:
            return False, f"Warmup failed: {str(e)}"
    
    def _load_model(self, model_id: str) -> bool:
        """Load a model into memory with validation and warmup."""
        if model_id not in self._models:
            logger.warning(f"Unknown model: {model_id}")
            return False
            
        model_info = self._models[model_id]
        
        if model_info.loaded:
            return True
            
        if model_info.loading:
            return False
            
        model_info.loading = True
        
        def _load():
            try:
                logger.info(f"Loading model: {model_id}")
                start_time = time.time()
                
                # Create model directory if it doesn't exist
                model_dir = self.model_dir / hashlib.md5(model_id.encode()).hexdigest()
                model_dir.mkdir(parents=True, exist_ok=True)
                
                # Try different model loading strategies
                try:
                    # First try with fp16 if on CUDA/ROCm
                    if DEFAULT_DEVICE != "cpu":
                        try:
                            pipe = StableDiffusionPipeline.from_pretrained(
                                model_id,
                                revision="fp16",
                                torch_dtype=DEFAULT_TORCH_DTYPE,
                                cache_dir=str(model_dir),
                                safety_checker=None,
                                use_safetensors=True
                            )
                        except Exception as e:
                            logger.warning(f"FP16 load failed, trying without revision: {e}")
                            pipe = StableDiffusionPipeline.from_pretrained(
                                model_id,
                                torch_dtype=DEFAULT_TORCH_DTYPE,
                                cache_dir=str(model_dir),
                                safety_checker=None,
                                use_safetensors=True
                            )
                    else:
                        pipe = StableDiffusionPipeline.from_pretrained(
                            model_id,
                            torch_dtype=DEFAULT_TORCH_DTYPE,
                            cache_dir=str(model_dir),
                            safety_checker=None,
                            use_safetensors=True
                        )
                    
                    # Move to device with error handling
                    try:
                        pipe = pipe.to(self.device)
                    except Exception as e:
                        logger.warning(f"Failed to move model to {self.device}, falling back to CPU: {e}")
                        self.device = "cpu"
                        self.torch_dtype = torch.float32
                        pipe = pipe.to(self.device)
                    
                    # Configure scheduler if needed
                    if hasattr(pipe, 'scheduler'):
                        pipe.scheduler = DPMSolverSinglestepScheduler.from_config(pipe.scheduler.config)
                    
                    # Validate the loaded model
                    is_valid, validation_error = self._validate_model(pipe, model_info.config)
                    if not is_valid:
                        raise ValueError(f"Model validation failed: {validation_error}")
                    
                    # Warm up the model
                    warmup_ok, warmup_error = self._warmup_model(pipe, model_info.config)
                    if not warmup_ok:
                        logger.warning(f"Model warmup failed (continuing anyway): {warmup_error}")
                    
                    # Update model info
                    with self._models_lock:
                        model_info.pipeline = pipe
                        model_info.loaded = True
                        model_info.loading = False
                        model_info.load_count += 1
                        model_info.last_used = time.time()
                        
                        # Estimate memory usage
                        if DEFAULT_DEVICE.startswith("cuda") and torch.cuda.is_available():
                            model_info.memory_usage = torch.cuda.memory_allocated()
                    
                    load_time = time.time() - start_time
                    logger.info(f"Successfully loaded and validated model {model_id} in {load_time:.2f}s")
                    
                except Exception as e:
                    # Clean up partially loaded model
                    if 'pipe' in locals() and pipe is not None:
                        del pipe
                        if torch.cuda.is_available():
                            torch.cuda.empty_cache()
                    
                    # If we get a UNet sample size error, try a different model variant
                    if "Unexpected UNet sample size" in str(e):
                        logger.warning("UNet sample size mismatch, trying with a different variant...")
                        if model_id == "stabilityai/stable-diffusion-2-1":
                            return self._load_model("runwayml/stable-diffusion-v1-5")
                    
                    error_msg = f"Failed to load model {model_id}: {str(e)}"
                    logger.error(error_msg, exc_info=True)
                    
                    with self._models_lock:
                        model_info.load_error = error_msg
                        model_info.loading = False
                        model_info.error_count += 1
            
            except Exception as e:
                error_msg = f"Unexpected error loading model {model_id}: {str(e)}"
                logger.error(error_msg, exc_info=True)
                
                with self._models_lock:
                    model_info.load_error = error_msg
                    model_info.loading = False
                    model_info.error_count += 1
        
        # Start the loading in a separate thread
        threading.Thread(target=_load, daemon=True, name=f"ModelLoader-{model_id}").start()
        return True
    
    def _validate_image_request(self, request: ImageRequest) -> Tuple[bool, str]:
        """Validate an image generation request."""
        if not request.prompt or len(request.prompt.strip()) == 0:
            return False, "Prompt cannot be empty"
            
        if len(request.prompt) > MAX_PROMPT_LENGTH:
            return False, f"Prompt too long (max {MAX_PROMPT_LENGTH} characters)"
            
        if request.settings:
            if request.settings.width < MIN_IMAGE_SIZE or request.settings.width > MAX_IMAGE_SIZE:
                return False, f"Width must be between {MIN_IMAGE_SIZE} and {MAX_IMAGE_SIZE}"
                
            if request.settings.height < MIN_IMAGE_SIZE or request.settings.height > MAX_IMAGE_SIZE:
                return False, f"Height must be between {MIN_IMAGE_SIZE} and {MAX_IMAGE_SIZE}"
                
            if request.settings.steps < 1 or request.settings.steps > MAX_STEPS:
                return False, f"Steps must be between 1 and {MAX_STEPS}"
                
            if request.settings.guidance_scale < 1.0 or request.settings.guidance_scale > 20.0:
                return False, "Guidance scale must be between 1.0 and 20.0"
        
        return True, ""
    
    def GetImageModels(self, request: ModelRequest, context) -> ModelResponse:
        """Get list of available image generation models."""
        response = ModelResponse()
        
        with self._models_lock:
            for model_id, info in self._models.items():
                config = info.config
                model_info = response.models.add()
                model_info.id = model_id
                model_info.name = config.name
                model_info.description = config.description
                
                # Add capabilities based on model type
                if config.type == ModelType.TEXT_TO_IMAGE:
                    model_info.capabilities.extend(["text-to-image", "image-variation"])
                elif config.type == ModelType.IMAGE_TO_IMAGE:
                    model_info.capabilities.extend(["image-to-image", "image-variation"])
                elif config.type == ModelType.INPAINTING:
                    model_info.capabilities.extend(["inpainting"])
                
                # Add supported parameters
                model_info.parameters["width"] = "int"
                model_info.parameters["height"] = "int"
                model_info.parameters["steps"] = f"int (min: {config.min_steps}, max: {config.max_steps}, default: {config.default_steps})"
                model_info.parameters["guidance_scale"] = f"float (default: {config.default_guidance_scale})"
                model_info.parameters["seed"] = f"int (default: {config.default_seed} for random)"
                
                # Add supported sizes
                size_str = ", ".join(f"{w}x{h}" for w, h in config.supported_sizes)
                model_info.parameters["supported_sizes"] = size_str
                
                # Add model status
                status = "loaded" if info.loaded else "not_loaded"
                if info.loading:
                    status = "loading"
                elif info.load_error:
                    status = f"error: {info.load_error[:100]}"  # Truncate long error messages
                
                model_info.parameters["status"] = status
                model_info.parameters["memory_usage"] = f"{info.memory_usage / (1024*1024):.2f} MB"
                model_info.parameters["load_count"] = str(info.load_count)
                model_info.parameters["error_count"] = str(info.error_count)
        
        return response
    
    def _generate_image(self, pipe, prompt: str, settings: ImageSettings, **kwargs) -> Tuple[Image.Image, Dict[str, Any]]:
        """Generate an image using the given pipeline and parameters."""
        # Prepare generation parameters
        width = min(max(settings.width or 512, MIN_IMAGE_SIZE), MAX_IMAGE_SIZE)
        height = min(max(settings.height or 512, MIN_IMAGE_SIZE), MAX_IMAGE_SIZE)
        num_inference_steps = min(max(settings.steps or 25, 1), MAX_STEPS)
        guidance_scale = max(min(settings.guidance_scale or 7.5, 20.0), 1.0)
        seed = settings.seed if settings.seed is not None else -1
        
        # Set random seed if needed
        if seed == -1:
            seed = torch.randint(0, 2**32 - 1, (1,)).item()
        
        # Create generator with the specified seed
        device = "cuda" if torch.cuda.is_available() else "cpu"
        generator = torch.Generator(device=device).manual_seed(seed)
        
        # Prepare additional parameters
        gen_kwargs = {
            "prompt": prompt,
            "width": width,
            "height": height,
            "num_inference_steps": num_inference_steps,
            "guidance_scale": guidance_scale,
            "generator": generator,
            **kwargs
        }
        
        # Generate the image
        with torch.inference_mode():
            result = pipe(**gen_kwargs)
            
            # Handle different pipeline outputs
            if hasattr(result, 'images') and result.images:
                image = result.images[0]
            elif isinstance(result, list) and len(result) > 0 and isinstance(result[0], Image.Image):
                image = result[0]
            elif isinstance(result, Image.Image):
                image = result
            else:
                raise ValueError(f"Unexpected pipeline output format: {type(result)}")
        
        # Prepare metadata
        metadata = {
            "width": width,
            "height": height,
            "steps": num_inference_steps,
            "guidance_scale": guidance_scale,
            "seed": seed,
            "model": pipe.name_or_path if hasattr(pipe, 'name_or_path') else "unknown",
            "device": device,
            "dtype": str(pipe.dtype) if hasattr(pipe, 'dtype') else "unknown",
        }
        
        return image, metadata
    
    def GenerateImage(self, request: ImageRequest, context) -> ImageResponse:
        """Generate a single image from a text prompt."""
        start_time = time.time()
        request_id = str(uuid.uuid4())
        
        try:
            # Validate the request
            is_valid, error_msg = self._validate_image_request(request)
            if not is_valid:
                return ImageResponse(
                    request_id=request_id,
                    error=f"Invalid request: {error_msg}"
                )
            
            # Get model ID or use default
            model_id = request.model or DEFAULT_MODEL
            model_info = self._get_model_info(model_id)
            
            if not model_info or not model_info.loaded or not model_info.pipeline:
                return ImageResponse(
                    request_id=request_id,
                    error=f"Model {model_id} is not available or failed to load"
                )
            
            # Get the pipeline
            pipe = model_info.pipeline
            
            # Update last used timestamp
            model_info.last_used = time.time()
            
            # Generate the image
            image, gen_metadata = self._generate_image(
                pipe=pipe,
                prompt=request.prompt,
                settings=request.settings or ImageSettings(),
                num_images_per_prompt=1
            )
            
            # Convert to bytes
            img_byte_arr = BytesIO()
            image_format = "PNG"
            image.save(img_byte_arr, format=image_format)
            
            # Calculate generation time
            generation_time_ms = int((time.time() - start_time) * 1000)
            gen_metadata["generation_time_ms"] = generation_time_ms
            
            # Create response
            return ImageResponse(
                request_id=request_id,
                image_data=img_byte_arr.getvalue(),
                format=f"image/{image_format.lower()}",
                metadata=GenerationMetadata(
                    model=model_id,
                    generation_time_ms=generation_time_ms,
                    seed=gen_metadata["seed"],
                    debug_info={k: str(v) for k, v in gen_metadata.items()}
                )
            )
            
        except Exception as e:
            error_msg = f"Image generation failed: {str(e)}"
            logger.exception("Error in GenerateImage")
            
            # Update error count for the model
            if 'model_info' in locals() and model_info:
                model_info.error_count += 1
            
            return ImageResponse(
                request_id=request_id,
                error=error_msg
            )
    
    def GenerateImageVariations(self, request: ImageVariationsRequest, context):
        """Generate multiple variations of an image."""
        request_id = str(uuid.uuid4())
        
        try:
            # Validate the base request
            if not request.base_request:
                yield ImageResponse(
                    request_id=request_id,
                    error="Base request is required"
                )
                return
                
            # Validate the base image request
            is_valid, error_msg = self._validate_image_request(request.base_request)
            if not is_valid:
                yield ImageResponse(
                    request_id=request_id,
                    error=f"Invalid base request: {error_msg}"
                )
                return
            
            # Get model ID or use default
            model_id = request.base_request.model or DEFAULT_MODEL
            model_info = self._get_model_info(model_id)
            
            if not model_info or not model_info.loaded or not model_info.pipeline:
                yield ImageResponse(
                    request_id=request_id,
                    error=f"Model {model_id} is not available or failed to load"
                )
                return
            
            # Get the pipeline
            pipe = model_info.pipeline
            
            # Update last used timestamp
            model_info.last_used = time.time()
            
            # Generate variations
            num_variations = max(1, min(request.num_variations or 1, MAX_BATCH_SIZE))
            variation_strength = max(0.0, min(1.0, request.variation_strength or 0.5))
            
            # Generate each variation
            for i in range(num_variations):
                try:
                    # Add variation strength to the prompt
                    variation_prompt = f"{request.base_request.prompt} (variation {i+1}, strength: {variation_strength:.2f})"
                    
                    # Generate the image with a slightly modified seed
                    settings = request.base_request.settings or ImageSettings()
                    if settings.seed is not None:
                        settings.seed += i  # Vary the seed for each variation
                    
                    image, gen_metadata = self._generate_image(
                        pipe=pipe,
                        prompt=variation_prompt,
                        settings=settings,
                        num_images_per_prompt=1,
                        strength=variation_strength
                    )
                    
                    # Convert to bytes
                    img_byte_arr = BytesIO()
                    image_format = "PNG"
                    image.save(img_byte_arr, format=image_format)
                    
                    # Create response
                    yield ImageResponse(
                        request_id=f"{request_id}-{i}",
                        image_data=img_byte_arr.getvalue(),
                        format=f"image/{image_format.lower()}",
                        metadata=GenerationMetadata(
                            model=model_id,
                            generation_time_ms=gen_metadata.get("generation_time_ms", 0),
                            seed=gen_metadata.get("seed", 0),
                            debug_info={
                                "variation_index": str(i),
                                "variation_strength": f"{variation_strength:.2f}",
                                **{k: str(v) for k, v in gen_metadata.items()}
                            }
                        )
                    )
                    
                except Exception as e:
                    logger.error(f"Error generating variation {i}: {str(e)}")
                    yield ImageResponse(
                        request_id=f"{request_id}-{i}",
                        error=f"Failed to generate variation {i+1}: {str(e)}"
                    )
        
        except Exception as e:
            error_msg = f"Image variation generation failed: {str(e)}"
            logger.exception("Error in GenerateImageVariations")
            
            # Update error count for the model
            if 'model_info' in locals() and model_info:
                model_info.error_count += 1
            
            yield ImageResponse(
                request_id=request_id,
                error=error_msg
            )

def serve(port: int = 50051, model_dir: str = "./models", max_models_in_memory: int = 2, 
          max_disk_cache_gb: float = 10.0, cleanup_interval: int = 300):
    """Start the gRPC server for image generation.
    
    Args:
        port: Port to listen on
        model_dir: Directory to store model caches and metadata
        max_models_in_memory: Maximum number of models to keep in GPU memory
        max_disk_cache_gb: Maximum disk space to use for model cache (in GB)
        cleanup_interval: How often to run cleanup (in seconds)
    """
    server = None
    servicer = None
    
    def handle_sigterm(*_):
        logger.info("Received SIGTERM, shutting down gracefully...")
        if servicer:
            servicer.stop()
        if server:
            server.stop(0)
        sys.exit(0)
    
    # Configure logging
    logger.remove()  # Remove default handler
    logger.add(
        sys.stderr,
        format="<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
    )
    
    # Log system information
    logger.info("Starting STARWEAVE Image Generation Service")
    logger.info(f"Python: {sys.version}")
    logger.info(f"PyTorch: {torch.__version__}")
    logger.info(f"CUDA available: {torch.cuda.is_available()}")
    
    if torch.cuda.is_available():
        logger.info(f"CUDA device: {torch.cuda.get_device_name(0)}")
    
    # Register signal handlers for graceful shutdown
    import signal
    signal.signal(signal.SIGTERM, handle_sigterm)
    signal.signal(signal.SIGINT, handle_sigterm)
    
    try:
        # Initialize server and servicer
        server = grpc.server(
            futures.ThreadPoolExecutor(
                max_workers=10,
                thread_name_prefix='grpc_worker'
            ),
            options=[
                ('grpc.max_send_message_length', 100 * 1024 * 1024),  # 100MB
                ('grpc.max_receive_message_length', 100 * 1024 * 1024),  # 100MB
                ('grpc.max_concurrent_rpcs', 10),
            ]
        )
        
        servicer = ImageGenerationServicer(
            model_dir=model_dir,
            max_models_in_memory=max_models_in_memory,
            max_disk_cache_gb=max_disk_cache_gb,
            cleanup_interval=cleanup_interval
        )
        
        # Add services
        add_ImageGenerationServiceServicer_to_server(servicer, server)
        
        # Add health checking service
        health_servicer = health.HealthServicer()
        health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)
        
        # Set health status
        health_servicer.set("", health_pb2.HealthCheckResponse.SERVING)
        health_servicer.set("starweave.ImageGeneration", health_pb2.HealthCheckResponse.SERVING)
        
        # Start the server
        server.add_insecure_port(f'[::]:{port}')
        server.start()
        
        # Log server info
        logger.info(f"Image generation server started on port {port}")
        logger.info(f"Default model: {DEFAULT_MODEL}")
        logger.info(f"Using device: {DEFAULT_DEVICE}")
        logger.info(f"Max models in memory: {max_models_in_memory}")
        logger.info(f"Max disk cache: {max_disk_cache_gb}GB")
        logger.info("Server is ready to handle requests")
        
        # Keep the main thread alive
        server.wait_for_termination()
        
    except Exception as e:
        logger.error(f"Server error: {e}", exc_info=True)
        if servicer:
            servicer.stop()
        if server:
            server.stop(0)
        raise
    finally:
        # Ensure cleanup on exit
        if servicer:
            servicer.stop()
        if server:
            server.stop(0)
        logger.info("Server has been shut down")

def GenerateImageVariations(self, request: ImageVariationsRequest, context):
    """Generate multiple variations of an image."""
    request_id = str(uuid.uuid4())
    
    try:
        # Validate the base request
        if not request.base_request:
            yield ImageResponse(
                request_id=request_id,
                error="Base request is required"
            )
            return
            
        # Validate the base image request
        is_valid, error_msg = self._validate_image_request(request.base_request)
        if not is_valid:
            yield ImageResponse(
                request_id=request_id,
                error=f"Invalid base request: {error_msg}"
            )
            return
        
        # Get model ID or use default
        model_id = request.base_request.model or DEFAULT_MODEL
        model_info = self._get_model_info(model_id)
        
        if not model_info or not model_info.loaded or not model_info.pipeline:
            yield ImageResponse(
                request_id=request_id,
                error=f"Model {model_id} is not available or failed to load"
            )
            return
        
        # Get the pipeline
        pipe = model_info.pipeline
        
        # Update last used timestamp
        model_info.last_used = time.time()
        
        # Generate variations
        num_variations = max(1, min(request.num_variations or 1, MAX_BATCH_SIZE))
        variation_strength = max(0.0, min(1.0, request.variation_strength or 0.5))
        
        # Generate each variation
        for i in range(num_variations):
            try:
                # Add variation strength to the prompt
                variation_prompt = f"{request.base_request.prompt} (variation {i+1}, strength: {variation_strength:.2f})"
                
                # Generate the image with a slightly modified seed
                settings = request.base_request.settings or ImageSettings()
                if settings.seed is not None:
                    settings.seed += i  # Vary the seed for each variation
                
                image, gen_metadata = self._generate_image(
                    pipe=pipe,
                    prompt=variation_prompt,
                    settings=settings,
                    num_images_per_prompt=1,
                    strength=variation_strength
                )
                
                # Convert to bytes
                img_byte_arr = BytesIO()
                image_format = "PNG"
                image.save(img_byte_arr, format=image_format)
                
                # Create response
                yield ImageResponse(
                    request_id=f"{request_id}-{i}",
                    image_data=img_byte_arr.getvalue(),
                    format=f"image/{image_format.lower()}",
                    metadata=GenerationMetadata(
                        model=model_id,
                        generation_time_ms=gen_metadata.get("generation_time_ms", 0),
                        seed=gen_metadata.get("seed", 0),
                        debug_info={
                            "variation_index": str(i),
                            "variation_strength": f"{variation_strength:.2f}",
                            **{k: str(v) for k, v in gen_metadata.items()}
                        }
                    )
                )
                
            except Exception as e:
                logger.error(f"Error generating variation {i}: {str(e)}")
                yield ImageResponse(
                    request_id=f"{request_id}-{i}",
                    error=f"Failed to generate variation {i+1}: {str(e)}"
                )
    
    except Exception as e:
        error_msg = f"Image variation generation failed: {str(e)}"
        logger.exception("Error in GenerateImageVariations")
        
        # Update error count for the model
        if 'model_info' in locals() and model_info:
            model_info.error_count += 1
        
        yield ImageResponse(
            request_id=request_id,
            error=error_msg
        )


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='STARWEAVE Image Generation Service')
    parser.add_argument('--port', type=int, default=50051, help='Port to listen on')
    parser.add_argument('--model-dir', type=str, default='./models', 
                       help='Directory to store downloaded models')
    
    args = parser.parse_args()
    
    # Configure logging
    logger.add("image_generation_{time:YYYY-MM-DD}.log", rotation="10 MB")
    
    serve(port=args.port, model_dir=args.model_dir)
