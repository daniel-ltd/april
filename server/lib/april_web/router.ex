defmodule AprilWeb.Router do
  use AprilWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Our pipeline implements "maybe" authenticated. We'll use the `:ensure_auth` below for when we need to make sure someone is logged in.
  pipeline :auth do
    plug April.UserManager.Pipeline
  end

  # We use ensure_auth to fail if there is no one logged in
  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/api/v1", AprilWeb do
    pipe_through [:api, :auth]
    # post "/sign_up", SessionController, :sign_up
    post "/sign_in", SessionController, :sign_in

    pipe_through :ensure_auth
    post "/sign_out", SessionController, :sign_out
  end
end
