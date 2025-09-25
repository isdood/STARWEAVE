#!/usr/bin/env python3
"""
STARWEAVE gRPC Server

This is the main gRPC server that combines all STARWEAVE services.
"""

import os
import signal
import threading
import time
from concurrent import futures
from typing import Optional

import grpc
from grpc_health.v1 import health_pb2, health_pb2_grpc

# Import service implementations
from server.pattern_server import PatternService, HealthServicer as PatternHealthServicer
from server.image_generation_servicer import ImageGenerationServicer

# Import generated protobuf code
import starweave_pb2_grpc

class ServerManager:
    """Manages the gRPC server lifecycle."""
    
    def __init__(self, port: int = 50051, max_workers: int = 10, model_dir: str = "./models"):
        """Initialize the server manager.
        
        Args:
            port: Port to listen on
            max_workers: Maximum number of worker threads
            model_dir: Directory to store downloaded models
        """
        self.port = port
        self.max_workers = max_workers
        self.model_dir = model_dir
        self.server = None
        self.health_servicer = None
        self._stop_event = threading.Event()
        self._setup_signal_handlers()
    
    def _setup_signal_handlers(self):
        """Set up signal handlers for graceful shutdown."""
        signal.signal(signal.SIGINT, self._handle_signal)
        signal.signal(signal.SIGTERM, self._handle_signal)
    
    def _handle_signal(self, signum, frame):
        """Handle OS signals for graceful shutdown."""
        print(f"\nReceived signal {signum}, shutting down...")
        self.stop()
    
    def start(self):
        """Start the gRPC server with all services."""
        # Create server with thread pool
        self.server = grpc.server(
            futures.ThreadPoolExecutor(max_workers=self.max_workers),
            options=[
                ('grpc.max_send_message_length', 50 * 1024 * 1024),  # 50MB
                ('grpc.max_receive_message_length', 50 * 1024 * 1024),  # 50MB
            ]
        )
        
        # Initialize health service
        self.health_servicer = PatternHealthServicer()
        health_pb2_grpc.add_HealthServicer_to_server(self.health_servicer, self.server)
        
        # Add Pattern Service
        pattern_service = PatternService()
        starweave_pb2_grpc.add_PatternServiceServicer_to_server(pattern_service, self.server)
        
        # Add Image Generation Service
        image_service = ImageGenerationServicer(model_dir=self.model_dir)
        starweave_pb2_grpc.add_ImageGenerationServiceServicer_to_server(image_service, self.server)
        
        # Start the server
        self.server.add_insecure_port(f'[::]:{self.port}')
        self.server.start()
        
        # Set health status to serving
        self.health_servicer.set("", health_pb2.HealthCheckResponse.SERVING)
        
        print(f"STARWEAVE server started on port {self.port}")
        print("Services:")
        print("  - PatternService")
        print("  - ImageGenerationService")
        print("  - Health Service")
        
        # Keep the main thread alive
        try:
            while not self._stop_event.is_set():
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
    
    def stop(self, grace: float = 5.0):
        """Stop the gRPC server.
        
        Args:
            grace: Grace period in seconds for existing RPCs to complete
        """
        if self.server:
            if self.health_servicer:
                self.health_servicer.set("", health_pb2.HealthCheckResponse.NOT_SERVING)
            
            # Give existing RPCs time to complete
            stopped = self.server.stop(grace).wait()
            print(f"Server stopped gracefully: {stopped}")
        
        self._stop_event.set()
    
    def wait_for_termination(self):
        """Wait until the server is terminated."""
        if self.server:
            self.server.wait_for_termination()


def serve(port: int = 50051, max_workers: int = 10, model_dir: str = "./models"):
    """Start the STARWEAVE gRPC server.
    
    Args:
        port: Port to listen on
        max_workers: Maximum number of worker threads
        model_dir: Directory to store downloaded models
    """
    # Create models directory if it doesn't exist
    os.makedirs(model_dir, exist_ok=True)
    
    # Configure logging
    import logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('starweave_server.log')
        ]
    )
    
    # Start the server
    server = ServerManager(port=port, max_workers=max_workers, model_dir=model_dir)
    server.start()


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='STARWEAVE gRPC Server')
    parser.add_argument('--port', type=int, default=50051, help='Port to listen on')
    parser.add_argument('--workers', type=int, default=10, 
                       help='Maximum number of worker threads')
    parser.add_argument('--model-dir', type=str, default='./models',
                       help='Directory to store downloaded models')
    
    args = parser.parse_args()
    
    serve(port=args.port, max_workers=args.workers, model_dir=args.model_dir)
