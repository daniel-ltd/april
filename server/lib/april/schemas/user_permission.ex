defmodule April.UserPermission do
  use Ecto.Schema
  
  import Ecto.Changeset

  alias April.{
    User,
    Permission
  }

  schema "users_permissions" do
    belongs_to :user, User
    belongs_to :permission, Permission

    timestamps()
  end

  @doc false
  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, [:user_id, :permission_id])
    |> validate_required([:user_id, :permission_id])
  end
end
