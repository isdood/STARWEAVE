defmodule StarweaveWeb.Router do
  use StarweaveWeb, :router
  import Phoenix.LiveView.Router

  # Serve static files from the priv/static directory
  scope "/" do
    pipe_through :browser
    get "/favicon.ico", StarweaveWeb.FaviconController, :index
    get "/favicon-16x16.png", StarweaveWeb.FaviconController, :favicon16
    get "/favicon-32x32.png", StarweaveWeb.FaviconController, :favicon32
    get "/apple-touch-icon.png", StarweaveWeb.FaviconController, :apple_touch_icon
    get "/site.webmanifest", StarweaveWeb.FaviconController, :webmanifest
  end

  # Define the browser pipeline
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StarweaveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Add this pipeline for LiveView pages
  pipeline :live_view do
    plug :put_root_layout, html: {StarweaveWeb.Layouts, :root}
  end

  # Define the API pipeline
  pipeline :api do
    plug :accepts, ["json"]
  end

  # Define the browser scope
  scope "/", StarweaveWeb do
    pipe_through [:browser, :live_view]
    live "/", PatternLive.Index, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", StarweaveWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:starweave_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: StarweaveWeb.Telemetry
    end
  end
end
