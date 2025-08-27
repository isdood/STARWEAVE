defmodule StarweaveWeb.UserSocket do
  @moduledoc """
  Handles WebSocket connections and channel multiplexing.
  """
  use Phoenix.Socket

  ## Channels
  channel "pattern:*", StarweaveWeb.PatternChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels.
  @impl true
  def connect(params, socket, _connect_info) do
    # For now, we'll accept all connections. In a production app,
    # you would verify and authenticate the user here.
    {:ok, assign(socket, :user_id, params["user_id"] || "anonymous")}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.StarweaveWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
