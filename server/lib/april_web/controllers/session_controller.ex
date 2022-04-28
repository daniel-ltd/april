defmodule AprilWeb.SessionController do
  use AprilWeb, :controller

  alias April.{UserManager, UserManager.User, UserManager.Guardian}

  # def sign_up(conn, _) do
  #   changeset = UserManager.change_user(%User{})
  #   maybe_user = Guardian.Plug.current_resource(conn)
  #   if maybe_user do
  #     redirect(conn, to: "/protected")
  #   else
  #     render(conn, "new.html", changeset: changeset, action: Routes.session_path(conn, :login))
  #   end
  # end

  def sign_in(conn, params) do
    case UserManager.authenticate_user(params["username"], params["password"]) do
      {:ok, user} ->
        case Guardian.encode_and_sign(user) do
          {:ok, token, claims} ->
            json(conn, %{
              id: user.id,
              username: user.username,
              token: token,
              claims: claims
            })

          {:error, reason} ->
            json(conn, reason)
        end

      {:error, reason} ->
        json(conn, reason)
    end
  end

  def sign_out(conn, _) do
    conn
    |> Guardian.Plug.sign_out()
    |> json("success")
  end

end