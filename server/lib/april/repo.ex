defmodule April.Repo do
  use Ecto.Repo,
    otp_app: :april,
    adapter: Ecto.Adapters.MyXQL
end
