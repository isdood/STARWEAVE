defmodule StarweaveWeb.FaviconController do
  use StarweaveWeb, :controller

  def index(conn, _params) do
    send_file_if_exists(conn, "priv/static/favicon.ico", "image/x-icon")
  end

  def favicon16(conn, _params) do
    conn
    |> put_resp_content_type("image/png")
    |> send_file(200, "priv/static/favicon-16x16.png")
  end

  def favicon32(conn, _params) do
    conn
    |> put_resp_content_type("image/png")
    |> send_file(200, "priv/static/favicon-32x32.png")
  end

  def apple_touch_icon(conn, _params) do
    # Return a 1x1 transparent PNG if the file doesn't exist
    send_file_if_exists(conn, "priv/static/apple-touch-icon.png", "image/png") ||
      conn
      |> put_resp_content_type("image/png")
      |> send_resp(200, <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 55, 110, 246, 36, 0, 0, 0, 10, 73, 68, 65, 84, 8, 215, 99, 96, 0, 0, 0, 2, 0, 1, 226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>) # 1x1 transparent PNG
  end

  def webmanifest(conn, _params) do
    send_file_if_exists(conn, "priv/static/site.webmanifest", "application/manifest+json") ||
      conn
      |> put_resp_content_type("application/manifest+json")
      |> send_resp(200, "{}") # Empty JSON object if file doesn't exist
  end

  defp send_file_if_exists(conn, path, content_type) do
    if File.exists?(path) do
      conn
      |> put_resp_content_type(content_type)
      |> send_file(200, path)
    else
      nil
    end
  end
end
