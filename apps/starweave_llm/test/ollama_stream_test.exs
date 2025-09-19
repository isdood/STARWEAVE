defmodule OllamaStreamTest do
  use ExUnit.Case, async: false
  alias StarweaveLlm.LLM.OllamaClient
  import ExUnit.CaptureLog

  setup do
    # Start a simple HTTP server to handle the request
    parent = self()
    
    # Start a simple HTTP server in a separate process
    server_pid = spawn_link(fn ->
      {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen_socket)
      
      # Send the port back to the test process
      send(parent, {:port, port})
      
      # Accept a single connection
      {:ok, socket} = :gen_tcp.accept(listen_socket)
      
      # Read the request
      {:ok, _request} = :gen_tcp.recv(socket, 0, 5000)
      
      # Send SSE response
      :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n\r\n")
      
      # Send test chunks
      chunks = [
        "data: {\"response\":\"Chunk 1\",\"done\":false}\n\n",
        "data: {\"response\":\"Chunk 2\",\"done\":false}\n\n",
        "data: {\"done\":true}\n\n"
      ]
      
      Enum.each(chunks, fn chunk ->
        :ok = :gen_tcp.send(socket, chunk)
        Process.sleep(10)
      end)
      
      # Close the connection
      :gen_tcp.close(socket)
      :gen_tcp.close(listen_socket)
    end)
    
    # Wait for the server to start and get the port
    receive do
      {:port, port} -> {:ok, port: port, server_pid: server_pid}
    after
      1000 -> {:error, :server_timeout}
    end
  end

  test "streams chunks from Ollama API", %{port: port} do
    # Set the base URL to our test server
    Application.put_env(:starweave_llm, :ollama_base_url, "http://localhost:#{port}")
    
    # Ensure we clean up after the test
    on_exit(fn ->
      Application.delete_env(:starweave_llm, :ollama_base_url)
    end)
    
    # Call the function under test
    stream = OllamaClient.stream_complete("test")
    assert is_function(stream)
    
    # Process the stream and collect chunks
    chunks = 
      stream
      |> Stream.take(5)  # Prevent infinite streams
      |> Enum.to_list()
    
    # Verify the results
    assert length(chunks) == 2
    assert "Chunk 1" in chunks
    assert "Chunk 2" in chunks
  end
end
