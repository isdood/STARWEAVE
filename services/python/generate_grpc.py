import os
import grpc_tools.protoc

def generate_grpc_code():
    # Define paths
    proto_file = 'protos/starweave.proto'
    output_dir = 'generated'
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate gRPC code
    grpc_tools.protoc.main([
        'grpc_tools.protoc',
        f'--proto_path={os.path.dirname(proto_file)}',
        f'--python_out={output_dir}',
        f'--grpc_python_out={output_dir}',
        os.path.basename(proto_file)
    ])
    
    # Fix imports in generated files
    for filename in os.listdir(output_dir):
        if filename.endswith('.py'):
            filepath = os.path.join(output_dir, filename)
            with open(filepath, 'r+') as f:
                content = f.read()
                f.seek(0, 0)
                f.write('import sys\n')
                f.write('import os\n')
                f.write('sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))\n')
                f.write(content)

if __name__ == '__main__':
    generate_grpc_code()
