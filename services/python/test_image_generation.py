import grpc
import argparse
import time
from PIL import Image
import io
import os
import sys

# Add the current directory to the path to find generated protobuf files
sys.path.append(os.path.dirname(__file__))

# Import the generated gRPC code
try:
    from generated import starweave_pb2 as starweave_pb2
    from generated import starweave_pb2_grpc as starweave_pb2_grpc
except ImportError:
    print("Error: Could not import generated protobuf files. Please run 'python -m grpc_tools.protoc' to generate them.")
    sys.exit(1)

def test_image_generation(port=50051, output_dir="test_output"):
    """Test the image generation service with a sample prompt."""
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Set up gRPC channel and stub
    channel = grpc.insecure_channel(f'localhost:{port}')
    stub = starweave_pb2_grpc.ImageGenerationServiceStub(channel)
    
    # Test prompt
    test_prompt = "A beautiful sunset over a mountain lake, digital art, highly detailed, 4k"
    
    # Create request
    settings = starweave_pb2.ImageSettings(
        width=512,
        height=512,
        steps=20,
        guidance_scale=7.5,
        seed=42
    )
    
    request = starweave_pb2.ImageRequest(
        prompt=test_prompt,
        settings=settings
    )
    
    print(f"Sending request with prompt: {test_prompt}")
    start_time = time.time()
    
    try:
        # Call the service with a 5-minute timeout
        try:
            response = stub.GenerateImage(request, timeout=300)  # 5 minutes timeout
            
            if not response.image_data:
                print("\n❌ Error: No image data received in response")
                if hasattr(response, 'status') and hasattr(response.status, 'message'):
                    print(f"Server message: {response.status.message}")
                return False
                
            # Save the generated image
            image = Image.open(io.BytesIO(response.image_data))
            timestamp = int(time.time())
            output_path = os.path.join(output_dir, f"generated_image_{timestamp}.png")
            image.save(output_path, format='PNG')
            
            print(f"\n✅ Success! Image generated and saved to: {output_path}")
            print(f"Time taken: {time.time() - start_time:.2f} seconds")
            
            if hasattr(response, 'model_id'):
                print(f"Model used: {response.model_id}")
                
            print(f"Image size: {image.size[0]}x{image.size[1]} pixels")
            print(f"File size: {os.path.getsize(output_path) / 1024:.1f} KB")
            
            # Show some basic image info
            print("\nImage info:")
            print(f"- Format: {image.format}")
            print(f"- Mode: {image.mode}")
            
            return True
            
        except grpc.RpcError as e:
            print(f"\n❌ gRPC Error ({e.code()}): {e.details()}")
            if e.code() == grpc.StatusCode.DEADLINE_EXCEEDED:
                print("The request took too long to complete. Try reducing the number of steps or image size.")
            return False
            
    except grpc.RpcError as e:
        print(f"\n❌ gRPC Error: {e.code()} - {e.details()}")
        return False
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Test Image Generation Service')
    parser.add_argument('--port', type=int, default=50051, help='gRPC server port')
    parser.add_argument('--output-dir', type=str, default="test_output", 
                       help='Directory to save generated images')
    args = parser.parse_args()
    
    test_image_generation(port=args.port, output_dir=args.output_dir)
