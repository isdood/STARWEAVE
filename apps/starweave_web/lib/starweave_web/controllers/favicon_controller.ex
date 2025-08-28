defmodule StarweaveWeb.FaviconController do
  use StarweaveWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("image/x-icon")
    |> send_file(200, "priv/static/favicon.ico")
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
    conn
    |> put_resp_content_type("image/png")
    |> send_file(200, "priv/static/apple-touch-icon.png")
  end

  def webmanifest(conn, _params) do
    conn
    |> put_resp_content_type("application/manifest+json")
    |> send_file(200, "priv/static/site.webmanifest")
  end
end
