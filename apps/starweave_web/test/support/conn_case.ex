defmodule StarweaveWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      
      # The default endpoint for testing
      @endpoint StarweaveWeb.Endpoint
      
      # Import test helpers
      import StarweaveWeb.ConnCase
    end
  end

  setup _tags do
    # Configure the endpoint for testing
    Application.put_env(:starweave_web, StarweaveWeb.Endpoint,
      http: [port: 4002],
      server: true,
      secret_key_base: "test_secret_key_123456789012345678901234567890123456789012345678901234567890",
      live_view: [signing_salt: "test_signing_salt"]
    )
    
    # Start the endpoint if it's not already started
    {:ok, _} = Application.ensure_all_started(:phoenix)
    {:ok, _} = Application.ensure_all_started(:phoenix_live_view)
    
    # Start the endpoint if it's not already running
    case Process.whereis(StarweaveWeb.Endpoint) do
      nil -> start_supervised!(StarweaveWeb.Endpoint)
      _pid -> :ok
    end
    
    # Build a connection for testing
    conn = Phoenix.ConnTest.build_conn()
    
    # Return the connection
    {:ok, conn: conn}
  end
end
