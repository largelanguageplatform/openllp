defmodule PlatformWeb.Router do
  use PlatformWeb, :router

  import PlatformWeb.OrganizationAuth
  import PlatformWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlatformWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :assign_bootstrap_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Separate pipeline for admin panel (no organization auth)
  pipeline :admin_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlatformWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "script-src 'self' 'unsafe-inline'; " <>
          "frame-src 'self'; " <>
          "connect-src 'self'; " <>
          "style-src 'self' 'unsafe-inline'; "
    }

    plug :fetch_current_admin
  end

  scope "/api/v1", PlatformWeb do
    pipe_through :api
    get "/bundle/:id", BundleController, :show
    delete "/bundle/:id", BundleController, :delete
    post "/bundle", BundleController, :create
    post "/attachment", AttachmentController, :create
    get "/attachment/:file", AttachmentController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:platform, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PlatformWeb.Telemetry
    end
  end

  ## Admin panel routes (non-guessable path)
  # Public admin routes - login page and POST
  scope "/admin", PlatformWeb do
    pipe_through [:admin_browser]

    live_session :redirect_if_admin_authenticated,
      on_mount: [{PlatformWeb.AdminAuth, :redirect_if_authenticated}] do
      live "/login", AdminLive.Login
    end

    post "/login", AdminSessionController, :create
  end

  # Admin auth routes - requires login, no password change requirement
  scope "/admin", PlatformWeb do
    pipe_through [:admin_browser, :require_authenticated_admin]

    live_session :require_authenticated_admin,
      on_mount: [{PlatformWeb.AdminAuth, :require_authenticated_admin}] do
      live "/change-password", AdminLive.ChangePassword
    end

    delete "/logout", AdminSessionController, :delete
  end

  # Admin routes - requires login AND password changed
  scope "/admin", PlatformWeb do
    pipe_through [:admin_browser, :require_authenticated_admin]

    live_session :require_admin_password_changed,
      on_mount: [
        {PlatformWeb.AdminAuth, :require_authenticated_admin},
        {PlatformWeb.AdminAuth, :require_password_changed}
      ] do
      live "/prompts", AdminLive.Prompts
    end
  end

  ## Single-tenant bootstrap routes (no login; see PlatformWeb.OrganizationAuth)
  scope "/", PlatformWeb do
    pipe_through [:browser]

    live_session :bootstrap,
      on_mount: [{PlatformWeb.OrganizationAuth, :bootstrap_scope}] do
      # SetupApiKey redirects to /portal when a key already exists,
      # so "/" lands new installs on key generation and everyone else
      # on the dashboard.
      live "/", HomeLive.SetupApiKey
      live "/setup/api-key", HomeLive.SetupApiKey
      live "/portal", Portal.DashboardLive
      live "/portal/agents/:agent_name/logs", Portal.AgentLogsLive
      live "/settings", HomeLive.Settings, :profile
      live "/settings/api-keys", HomeLive.Settings, :api_keys
      live "/docs", Guides.QuickstartLive
    end

    get "/uploads/:agent_name/:attachment", AttachmentController, :download
  end
end
