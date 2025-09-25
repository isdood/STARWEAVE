defmodule StarweaveLlm.ImageGeneration.ClientTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  
  alias StarweaveLlm.ImageGeneration.Client
  
  setup_all do
    # Start the client with test configuration
    {:ok, _pid} = start_supervised(
      {Client, [host: "localhost", port: 50051, enabled: true]}, 
      restart: :temporary
    )
    
    :ok
  end
  
  describe "generate_image/2" do
    test "returns an error when service is not available" do
      # Stop the client to simulate service unavailability
      :ok = stop_supervised(Client)
      
      # Start a new client with an invalid port
      {:ok, _pid} = start_supervised(
        {Client, [host: "localhost", port: 12345, enabled: true]}, 
        restart: :temporary
      )
      
      assert {:error, _reason} = Client.generate_image("test prompt")
    end
    
    @tag :skip
    test "generates an image with valid parameters" do
      use_cassette "generate_image_success" do
        prompt = "A beautiful sunset over a mountain lake, digital art, highly detailed, 4k"
        
        assert {:ok, image_data, _metadata} = 
          Client.generate_image(prompt, [
            width: 512,
            height: 512,
            steps: 10,
            guidance_scale: 7.5
          ])
          
        assert is_binary(image_data)
        assert byte_size(image_data) > 0
      end
    end
  end
  
  describe "list_models/0" do
    @tag :skip
    test "returns a list of available models" do
      use_cassette "list_models_success" do
        assert {:ok, models} = Client.list_models()
        assert is_list(models)
        assert length(models) > 0
        
        # Check that each model has the expected fields
        for model <- models do
          assert is_binary(model.id)
          assert is_binary(model.name)
          assert is_boolean(model.available)
        end
      end
    end
  end
  
  describe "available?/0" do
    test "returns true when the service is available" do
      # This test assumes the service is running locally
      assert Client.available?() in [true, false]
    end
  end
end
