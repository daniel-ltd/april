defmodule April.GroupPermission do
  use Ecto.Schema
  
  import Ecto.Changeset

  alias April.{
    Group,
    Permission
  }

  schema "groups_permissions" do
    belongs_to :group, Group
    belongs_to :permission, Permission

    timestamps()
  end

  @doc false
  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, [:group_id, :permission_id])
    |> validate_required([:group_id, :permission_id])
  end
end
