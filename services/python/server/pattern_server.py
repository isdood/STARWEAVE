#!/usr/bin/env python3
"""
STARWEAVE Pattern Recognition gRPC Server

This server implements the PatternService defined in protos/starweave.proto.
It handles pattern recognition requests and streams responses back to clients.
"""

import logging
import time
import sys
import os
import signal
import threading
from concurrent import futures
from typing import Dict, Any, Optional

import grpc
from grpc_health.v1 import health_pb2
from grpc_health.v1 import health_pb2_grpc

import starweave_pb2
import starweave_pb2_grpc
# Use standard logging throughout (avoid loguru-specific methods in mixed setup)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class HealthServicer(health_pb2_grpc.HealthServicer):
    """gRPC health check servicer."""
    
    def __init__(self):
        self._server_status = health_pb2.HealthCheckResponse.SERVING
        self._lock = threading.Lock()
    
    def Check(self, request, context):
        with self._lock:
            return health_pb2.HealthCheckResponse(status=self._server_status)
    
    def set_status(self, status):
        """Update the server status."""
        with self._lock:
            self._server_status = status
    
    def get_status(self):
        """Get the current server status."""
        with self._lock:
            return self._server_status


class PatternService(starweave_pb2_grpc.PatternServiceServicer):
    """Implementation of the PatternService."""
    
    def __init__(self, health_servicer: Optional[HealthServicer] = None):
        self.start_time = time.time()
        self.request_count = 0
        self.health_servicer = health_servicer or HealthServicer()
        logger.info("PatternService initialized")
    
    def RecognizePattern(self, request, context):
        """Handle a single pattern recognition request."""
        self.request_count += 1
        pattern_id = request.pattern.id
        logger.info(f"Processing pattern: {pattern_id}")
        
        # TODO: Implement actual pattern recognition logic
        # For now, return a mock response
        return starweave_pb2.PatternResponse(
            request_id=str(self.request_count),
            labels=["mock_label_1", "mock_label_2"],
            confidences={"mock_label_1": 0.95, "mock_label_2": 0.75},
            metadata={"processed_by": "python-server"}
        )
    
    def StreamPatterns(self, request_iterator, context):
        """Handle a stream of pattern recognition requests."""
        logger.info("Starting pattern stream processing")
        
        for request in request_iterator:
            self.request_count += 1
            pattern_id = request.pattern.id
            pattern_data = request.pattern.data
            logger.debug(f"Processing streamed pattern: {pattern_id}")
            
            # Process the pattern (mock implementation)
            # Return response matching the expected PatternResponse proto
            yield starweave_pb2.PatternResponse(
                request_id=f"stream-{self.request_count}",
                labels=["stream_label_1", "stream_label_2"],
                confidences={
                    "stream_label_1": 0.9,
                    "stream_label_2": 0.7
                },
                metadata={
                    "processed_by": "python-stream-server",
                    "pattern_id": pattern_id,
                    "original_data": pattern_data.decode("utf-8", errors="ignore") if isinstance(pattern_data, (bytes, bytearray)) else str(pattern_data)
                }
            )
    
    def GetStatus(self, request, context):
        """Return the current status of the service."""
        current_time = time.time()
        uptime = int(current_time - self.start_time)
        
        metrics = {
            "requests_processed": str(self.request_count),
            "uptime_seconds": str(uptime),
            "status": "SERVING"
        }
        
        if request.detailed:
            metrics.update({
                "python_version": "3.13",  # This should be dynamic in production
                "grpc_version": grpc.__version__,
                "memory_usage_mb": "0"  # Add actual memory usage in production
            })
        
        return starweave_pb2.StatusResponse(
            status="SERVING",
            version="0.1.0",
            uptime=uptime,
            metrics=metrics
        )

class ServerManager:
    """Manages the gRPC server lifecycle."""
    
    def __init__(self, port: int = 50052, max_workers: int = 10):
        self.port = port
        self.max_workers = max_workers
        self.server = None
        self.health_servicer = None
        self.pattern_service = None
        self._stop_event = threading.Event()
    
    def start(self) -> None:
        """Start the gRPC server."""
        # Create server with thread pool
        self.server = grpc.server(
            futures.ThreadPoolExecutor(max_workers=self.max_workers),
            options=[
                ('grpc.max_send_message_length', 100 * 1024 * 1024),  # 100MB
                ('grpc.max_receive_message_length', 100 * 1024 * 1024),  # 100MB
                ('grpc.so_reuseport', 1),
            ]
        )
        
        # Create and register services
        self.health_servicer = HealthServicer()
        self.pattern_service = PatternService(health_servicer=self.health_servicer)
        
        # Add services to the server
        starweave_pb2_grpc.add_PatternServiceServicer_to_server(
            self.pattern_service, self.server)
        health_pb2_grpc.add_HealthServicer_to_server(
            self.health_servicer, self.server)
        
        # Add reflection service for debugging
        from grpc_reflection.v1alpha import reflection
        SERVICE_NAMES = (
            starweave_pb2.DESCRIPTOR.services_by_name['PatternService'].full_name,
            health_pb2.DESCRIPTOR.services_by_name['Health'].full_name,
            reflection.SERVICE_NAME,
        )
        reflection.enable_server_reflection(SERVICE_NAMES, self.server)
        
        # Start the server
        endpoint = f'[::]:{self.port}'
        self.server.add_insecure_port(endpoint)
        self.server.start()
        
        # Update health status
        self.health_servicer.set_status(health_pb2.HealthCheckResponse.SERVING)
        
        logger.info(f"gRPC server started on port {self.port}")
        
        # Register signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)
    
    def stop(self, grace: float = 5.0) -> None:
        """Stop the gRPC server."""
        if self.health_servicer:
            self.health_servicer.set_status(health_pb2.HealthCheckResponse.NOT_SERVING)
        
        if self.server:
            logger.info("Shutting down gRPC server...")
            self.server.stop(grace)
            logger.info("gRPC server stopped")
        
        self._stop_event.set()
    
    def wait_for_termination(self) -> None:
        """Wait until the server is terminated."""
        try:
            while not self._stop_event.is_set():
                self._stop_event.wait(1)
        except KeyboardInterrupt:
            self.stop()
    
    def _handle_signal(self, signum, frame):
        """Handle OS signals for graceful shutdown."""
        logger.info(f"Received signal {signal.Signals(signum).name}, shutting down...")
        self.stop()


def serve(port: int = 50052, max_workers: int = 10) -> None:
    """Start the gRPC server."""
    # Logging already configured via logging.basicConfig; no special setup needed
    
    # Set up process title
    try:
        import setproctitle
        setproctitle.setproctitle("starweave-grpc-server")
    except ImportError:
        pass  # setproctitle not available
    
    # Create and start server
    server = ServerManager(port=port, max_workers=max_workers)
    server.start()
    
    try:
        server.wait_for_termination()
    except Exception as e:
        logger.error(f"Server error: {e}")
        server.stop()
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Shutdown requested, exiting...")
        server.stop()
        sys.exit(0)

if __name__ == '__main__':
    serve()
