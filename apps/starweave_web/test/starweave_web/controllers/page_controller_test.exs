defmodule StarweaveWeb.PageControllerTest do
  use StarweaveWeb.ConnCase
  import Phoenix.LiveViewTest

  test "GET /", %{conn: conn} do
    # Test the initial page load
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "STARWEAVE"
    
    # Test the LiveView directly
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Welcome to STARWEAVE"
    assert html =~ "I can help you recognize and learn patterns"
  end
end
