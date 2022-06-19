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
        :array_map,
        %{
          id: [type: :string, required: true],
          class: [type: :integer, required: true]
        }
      },
      length: [min: 3]
    ],

    user: [type: {:schema, April.User}, required: true],
    username: [type: {:schema_field, April.User}],
    password_raw: [type: {:schema_field, April.User, :password}],

    perm: [
      type: {
        :map,
        %{
          name: [type: {:schema_field, April.Permission}],
          code: [type: {:schema_field, April.Permission, :codename}, required: true],
          temp: [type: :boolean]
        }
      }
    ],
    perm_name: [type: {:schema_field, April.Permission, :name}],
    perm_name2: [type: {:schema_field, April.Permission, :name}],
    codename: [type: {:schema_field, April.Permission}, required: true],

    array_perm: [
      type: {
        :array_map,
        %{
          name: [type: {:schema_field, April.Permission}],
          code: [type: {:schema_field, April.Permission, :codename}, required: true]
        }
      },
      required: true
    ],

    info: [
      type: {
        :map,
        %{
          user: [
            type: {
              :map,
              %{
                name: [type: {:schema_field, April.User, :username}, required: true],
              }
            },
            required: true
          ],
          perms: [
            type: {
              :array_map,
              %{
                name: [type: {:schema_field, April.Permission}],
                code: [type: {:schema_field, April.Permission, :codename}, required: true]
              },
            },
            required: true,
            length: [min: 1]
          ],
          schema_perms: [
            type: {
              :array_schema,
              April.Permission
            },
            required: true
          ],
          temp: [type: :boolean]
        }
      },
      required: true
    ],

    map_group: [
      type: {
        :map_schema,
        April.Group
      },
      required: true
    ],

    # joined_name: [type: :joined_string],
    # joined_name: [type: {:joined_string, :integer | ValidateType | {:schema_field, Schema, :field}}],

    # joined_id: [
    #   type: :joined_string,
    #   split: [pattern: [], parts: :infinity, trim: true],
    #   elem_validate: [
    #     length: [min: 10],
    #     number: [greater_than: 3, less_than: 5]
    #   ]
    # ]
  }
  @api_permissions ["add_user", "change_user"]
  def validate(conn, params) do
    @api_param_types
    |> Validator.parse(params)
    |> Validator.get_validated_changes!()
    |> then(fn params -> json(conn, params) end)
  end

  @api_param_types %{
    array_string: [
      type: {:array, :string},
      elem_validate: [
        length: [is: 3]
      ],
      required: true
    ],
    array_integer: [
      type: {:array, :integer},
      length: [min: 1, max: 3],
      required: true
    ],
    array_temp: [
      type: {:array_field, April.Room, :temp},
      length: [min: 1, max: 3],
      required: true
    ],
    array_color: [
      type: {:array_field, April.Room, :color},
      elem_validate: [
        length: [min: 4]
      ]
    ],
  }
  def validate_array(conn, params) do
    @api_param_types
    |> Validator.parse(params)
    |> Validator.get_validated_changes!()
    |> then(fn params -> json(conn, params) end)
  end
end
