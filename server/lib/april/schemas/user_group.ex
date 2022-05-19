defmodule April.UserGroup do
  use Ecto.Schema
  
  import Ecto.Changeset

  alias April.{
    User,
    Group
  }

  schema "users_groups" do
    belongs_to :user, User
    belongs_to :group, Group

    timestamps()
  end

  @doc false
  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, [:user_id, :group_id])
    |> validate_required([:user_id, :group_id])
  end
end
