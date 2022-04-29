defmodule AprilWeb.Router do
  use AprilWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug April.Auth.Pipeline
  end

  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/api/v1", AprilWeb do
    pipe_through :api
    # post "/sign_up", SessionController, :sign_up
    post "/sign_in", SessionController, :sign_in

    pipe_through :ensure_auth
    post "/sign_out", SessionController, :sign_out
    get "/info", SessionController, :info
  end
end
