defmodule AprilWeb.Router do
  use AprilWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AprilWeb do
    pipe_through :api
  end
end
