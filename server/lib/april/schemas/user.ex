defmodule April.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Argon2
  alias April.{
    Permission,
    Group,
    UserPermission,
    UserGroup
  }

  schema "users" do
    field :password, :string
    field :username, :string
    many_to_many :permissions, Permission, join_through: UserPermission
    many_to_many :groups, Group, join_through: UserGroup

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    change(changeset, password: Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
