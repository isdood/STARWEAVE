#!/usr/bin/env python3
"""
Simple gRPC client for testing the PatternService.
"""

import grpc
import starweave_pb2
import starweave_pb2_grpc
from loguru import logger

def run():
    """Run the test client."""
    # Connect to the server
    with grpc.insecure_channel('localhost:50051') as channel:
        stub = starweave_pb2_grpc.PatternServiceStub(channel)
        
        # Test single pattern recognition
        try:
            logger.info("Testing single pattern recognition...")
            response = stub.RecognizePattern(
                starweave_pb2.PatternRequest(
                    pattern=starweave_pb2.Pattern(
                        id="test-pattern-1",
                        data=b"test data",
                        metadata={"source": "test-client"}
                    )
                )
            )
            logger.info(f"Response: {response}")
            
            # Test status check
            logger.info("\nTesting status check...")
            status = stub.GetStatus(starweave_pb2.StatusRequest(detailed=True))
            logger.info(f"Status: {status}")
            
            # Test streaming
            logger.info("\nTesting streaming...")
            def generate_requests():
                for i in range(3):
                    yield starweave_pb2.PatternRequest(
                        pattern=starweave_pb2.Pattern(
                            id=f"stream-pattern-{i}",
                            data=f"stream data {i}".encode(),
                            metadata={"stream": "test"}
                        )
                    )
            
            for response in stub.StreamPatterns(generate_requests()):
                logger.info(f"Stream response: {response}")
                
        except grpc.RpcError as e:
            logger.error(f"RPC failed: {e.code()}: {e.details()}")
            raise

if __name__ == '__main__':
    run()
