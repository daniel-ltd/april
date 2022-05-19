defmodule April.Group do
  use Ecto.Schema

  import Ecto.Changeset

  alias April.{
    Permission,
    UserPermission
  }

  schema "groups" do
    field :name, :string
    many_to_many :permissions, Permission, join_through: UserPermission

    timestamps()
  end

  @doc false
  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
