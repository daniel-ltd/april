defmodule AprilWeb.Router do
  use AprilWeb, :router
  use Plug.ErrorHandler

  alias April.Error
  alias AprilWeb.ErrorView

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

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    with {status, error} when not is_nil(error) <- Error.transform(reason) do
      conn
      |> put_status(status)
      |> put_view(ErrorView)
      |> render("error.json", error: error)
    else
      {status, nil} -> send_resp(conn, status, "")
      _ -> send_resp(conn, :internal_server_error, "")
    end
  end
end
