defmodule PrepMechWeb.Router do
  use PrepMechWeb, :router

  import PrepMechWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PrepMechWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :customer do
    plug :require_role, :customer
  end

  ## Authenticated-only routes
  scope "/", PrepMechWeb do
    pipe_through [:browser, :ensure_authenticated]

    get "/", PageController, :home
    delete "/logout", SessionController, :logout
  end

  ## Customer-only routes
  scope "/", PrepMechWeb do
    pipe_through [:browser, :ensure_authenticated, :customer]

    get "/orders/new", OrderController, :new
    post "/orders", OrderController, :create
    get "/orders/:id", OrderController, :show
  end

  ## Guest-only routes — redirect logged-in users to "/"
  scope "/", PrepMechWeb do
    pipe_through [:browser, :non_authenticated]

    get "/login", SessionController, :login
    post "/login", SessionController, :validate_login
    get "/signup", SessionController, :signup
    post "/signup", SessionController, :create_user
  end

  # Other scopes may use custom stacks.
  # scope "/api", PrepMechWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:prep_mech, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PrepMechWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
