defmodule April.Room do
  use Ecto.Schema

  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :temp, :float
    field :area, :integer
    field :color, :string

    timestamps()
  end

  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, [:name, :temp, :area, :color])
    |> validate_length(:name, min: 3, max: 45)
    |> validate_number(:temp, greater_than: 15, less_than: 30)
    |> validate_inclusion(:color, ["red", "green", "yellow"])
    |> validate_required([:name, :color])
  end
end
