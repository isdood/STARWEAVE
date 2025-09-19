defmodule StreamingTest do
  use ExUnit.Case, async: false
  alias StarweaveLlm.LLM.OllamaClient
  import ExUnit.CaptureLog
  
  # Set up Bypass with a custom response
  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end


  test "streaming test", %{bypass: bypass} do
    # Set up the Bypass server with the expected response
    Bypass.expect(bypass, "POST", "/api/generate", fn conn ->
      # Send SSE headers
      conn = 
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
        |> Plug.Conn.send_chunked(200)
      
      # Send the chunks with a small delay between them
      chunks = [
        "data: {\"response\":\"Chunk 1\",\"done\":false}\n\n",
        "data: {\"response\":\"Chunk 2\",\"done\":false}\n\n",
        "data: {\"done\":true}\n\n"
      ]
      
      # Send each chunk
      Enum.reduce_while(chunks, conn, fn chunk, conn ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> 
            Process.sleep(10)
            {:cont, conn}
          _ -> 
            {:halt, conn}
        end
      end)
    end)


    # Set the base URL to point to our Bypass server
    Application.put_env(:starweave_llm, :ollama_base_url, "http://localhost:#{bypass.port}")
    
    # Ensure we clean up after the test
    on_exit(fn ->
      Application.delete_env(:starweave_llm, :ollama_base_url)
    end)
    
    # Test the streaming
    stream = OllamaClient.stream_complete("test")
    assert is_function(stream)  # Should be a stream function
    
    IO.puts("\n=== Starting to process stream ===")
    
    # Process the stream and collect chunks with logging
    chunks = 
      stream
      |> Stream.take(5)  # Prevent infinite streams
      |> Stream.each(fn chunk -> 
        IO.inspect(chunk, label: "Processing chunk") 
      end)
      |> Enum.to_list()
    
    IO.puts("\n=== Collected chunks ===")
    IO.inspect(chunks, label: "All collected chunks")
    
    # Verify the results
    assert length(chunks) == 2
    assert "Chunk 1" in chunks
    assert "Chunk 2" in chunks
  end
end
