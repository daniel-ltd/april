defmodule April.Permission do
  use Ecto.Schema
  
  import Ecto.Changeset

  alias April.{
    User,
    UserPermission,
    Group,
    GroupPermission
  }

  schema "permissions" do
    field :name, :string
    field :codename, :string
    many_to_many :users, User, join_through: UserPermission
    many_to_many :groups, Group, join_through: GroupPermission

    timestamps()
  end

  @doc false
  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, [:name, :codename])
    |> validate_required([:name, :codename])
  end
end
