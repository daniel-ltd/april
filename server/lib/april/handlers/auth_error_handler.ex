defmodule April.AuthErrorHandler do
  import Plug.Conn

  alias April.Error

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(_conn, {type, _reason}, _opts) do
    raise Error, code: type
  end
end