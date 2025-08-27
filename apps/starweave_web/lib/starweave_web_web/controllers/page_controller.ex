defmodule StarweaveWebWeb.PageController do
  use StarweaveWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
