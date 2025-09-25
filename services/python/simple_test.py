import grpc
import os
import sys
import time
from PIL import Image
import io
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Add the current directory to the path to find generated protobuf files
sys.path.append(os.path.dirname(__file__))

# Import the generated gRPC code
from generated.starweave_pb2_grpc import ImageGenerationServiceStub
from generated.starweave_pb2 import ImageRequest, ImageSettings

def main():
    # Set up the gRPC channel and stub
    logger.info("Creating insecure channel to localhost:50051")
    channel = grpc.insecure_channel('localhost:50051')
    
    # Test the connection
    try:
        logger.info("Testing channel connectivity...")
        grpc.channel_ready_future(channel).result(timeout=5)
        logger.info("Successfully connected to gRPC server")
    except grpc.FutureTimeoutError:
        logger.error("Failed to connect to gRPC server: timeout")
        return
    except Exception as e:
        logger.error(f"Failed to connect to gRPC server: {e}")
        return
        
    stub = ImageGenerationServiceStub(channel)
    
    # Create a test request
    settings = ImageSettings(
        width=512,
        height=512,
        steps=10,  # Reduced steps for faster testing
        guidance_scale=7.5,
        seed=42
    )
    
    request = ImageRequest(
        prompt="A beautiful sunset over a mountain lake, digital art, highly detailed, 4k",
        settings=settings,
        model="runwayml/stable-diffusion-v1-5"  # Explicitly specify the working model
    )
    
    logger.info("Sending request to image generation service...")
    logger.info(f"Request details: {request}")
    
    try:
        # Make the gRPC call with a 5-minute timeout
        logger.info("Initiating gRPC call to GenerateImage...")
        start_time = time.time()
        response = stub.GenerateImage(request, timeout=300)
        logger.info(f"Received response in {time.time() - start_time:.2f} seconds")
        
        if hasattr(response, 'image_data') and response.image_data:
            # Save the generated image
            image_size = len(response.image_data)
            logger.info(f"Received image data: {image_size} bytes")
            
            try:
                image = Image.open(io.BytesIO(response.image_data))
                output_path = "test_output.png"
                image.save(output_path)
                logger.info(f"✅ Image successfully generated and saved to: {os.path.abspath(output_path)}")
                logger.info(f"Image size: {image.size[0]}x{image.size[1]} pixels")
                logger.info(f"File size: {os.path.getsize(output_path) / 1024:.1f} KB")
            except Exception as e:
                logger.error(f"Failed to process image data: {e}")
                # Save the raw bytes for debugging
                with open("debug_image.bin", "wb") as f:
                    f.write(response.image_data)
                logger.info("Saved raw image data to debug_image.bin for inspection")
        else:
            logger.error("❌ No image data received in response")
            logger.info(f"Response object: {response}")
            if hasattr(response, 'status') and hasattr(response.status, 'message'):
                logger.error(f"Server status: {response.status.message}")
            if hasattr(response, 'error'):
                logger.error(f"Error details: {response.error}")
                
    except grpc.RpcError as e:
        logger.error(f"❌ gRPC Error ({e.code()}): {e.details()}")
        if e.code() == grpc.StatusCode.DEADLINE_EXCEEDED:
            logger.error("The request took too long to complete. Try reducing the number of steps or image size.")
        # Print debug information
        logger.error(f"RPC debug information: {e.debug_error_string()}")
    except Exception as e:
        logger.error(f"❌ Unexpected error: {str(e)}")
        import traceback
        logger.error(f"Stack trace: {traceback.format_exc()}")
    finally:
        # Clean up
        if 'channel' in locals():
            channel.close()

if __name__ == "__main__":
    main()
