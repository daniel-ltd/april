defmodule AprilWeb.ValidationController do
  use AprilWeb, :controller

  alias April.Validator

  def test_change(_title, title) do
    if title == "foo" do
      [title: {"cannot be foo", [validation: :change, kind: :not_equal_to, type: :string]}]
    else
      []
    end
  end

  @api_param_types %{
    temp: [type: :boolean, acceptance: []],

    title: [type: :string, change: &AprilWeb.ValidationController.test_change/2],

    email: [type: :string, format: ~r/@/, confirmation: [required: true]],

    name: [type: :string, required: true, exclusion: ["admin", "superadmin"], length: [is: 6]],
    age: [type: :integer, inclusion: 0..99],
    pi: [type: :float, required: true, number: [greater_than: 3, less_than: 5]],

    pets: [type: {:array, :string}, subset: ["cat", "dog", "parrot"]],

    student: [
      type: {
        :map,
        %{
          id: [type: :string, required: true],
          class: [type: :integer, required: true]
        }
      },
      required: true
    ],

    address: [
      type: {
        :map_value,
        %{
          street: [type: :string, required: true],
          country: [type: :string, required: true]
        }
      },
      required: true
    ],

    array_integer: [type: {:array, :integer}, required: true],
    array_string: [type: {:array, :string}, required: true],

    array_map: [
      type: {
        :array,
        %{
          id: [type: :string, required: true],
          class: [type: :integer, required: true]
        }
      }
    ]
  }
  def validate(conn, params) do
    @api_param_types
    |> Validator.parse(params)
    |> Validator.get_validated_changes!()
    # |> IO.inspect()

    json(conn, "success")
  end
end
