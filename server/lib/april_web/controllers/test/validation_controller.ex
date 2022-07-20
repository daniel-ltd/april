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
    # temp: [type: :boolean, acceptance: []],
    # title: [type: :string, change: &AprilWeb.ValidationController.test_change/2],
    # email: [type: :string, format: ~r/@/, confirmation: [required: true]],
    # name: [type: :string, required: true, exclusion: ["admin", "superadmin"], length: [is: 6]],
    # age: [type: :integer, inclusion: 0..99],
    # pi: [type: :float, required: true, number: [greater_than: 3, less_than: 5]],
    # pets: [type: {:array, :string}, subset: ["cat", "dog", "parrot"]],
    # student: [
    #   type: :map,
    #   properties: %{
    #     id: [type: :string, required: true],
    #     class: [type: :integer, required: true]
    #   },
    #   required: true
    # ],
    # address: [
    #   type: {:map, :map},
    #   values: [
    #     properties: %{
    #       street: [type: :string, required: true],
    #       country: [type: :string, required: true]
    #     }
    #   ],
    #   required: true
    # ],
    # array_integer: [type: {:array, :integer}, required: true],
    # array_string: [type: {:array, :string}, required: true],
    # array_map: [
    #   type: {:array, :map},
    #   items: [
    #     properties: %{
    #       id: [type: :string, required: true],
    #       class: [type: :integer, required: true]
    #     }
    #   ],
    #   length: [min: 3]
    # ],
    # array_item: [
    #   type: {:array, :integer},
    #   items: [
    #     number: [greater_than: 2, less_than: 15],
    #     required: true
    #   ],
    #   required: true
    # ],
    info: [
      type: :map,
      properties: %{
        user: [
          type: :map,
          properties: %{
            name: [type: :string, required: true]
          },
          required: true
        ],
        perms: [
          type: {:array, :map},
          items: [
            properties: %{
              name: [type: :string],
              code: [type: :string, required: true]
            }
          ],
          required: true,
          length: [min: 1]
        ],
        temp: [type: :boolean],
        joined_id: [
          type: {:joined_string, :integer},
          items: [
            number: [greater_than: 3, less_than: 15]
          ],
          length: [min: 3],
          required: true
        ],
        joined_name: [
          type: {:joined_string, :string},
          splitter: [pattern: ~r{,}],
          length: [min: 3],
          required: true
        ]
      },
      required: true
    ]

    # joined_name: [type: :joined_string],
    # joined_name: [type: {:joined_string, :integer | ValidateType | {:schema_field, Schema, :field}}],

    # joined_id: [
    #   type: {:joined_string, :integer},
    #   splitter: [pattern: [], parts: :infinity, trim: true],
    #   items: [
    #     number: [greater_than: 3, less_than: 15]
    #   ],
    #   length: [min: 10],
    #   required: true
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
    ]
  }
  def validate_array(conn, params) do
    @api_param_types
    |> Validator.parse(params)
    |> Validator.get_validated_changes!()
    |> then(fn params -> json(conn, params) end)
  end

  @api_param_types %{
    student: [
      type: :map,
      properties: %{
        id: [type: :integer, required: true],
        name: [type: :string, required: true],
        class_code: [type: :string, required: true],
        address: [
          type: :map,
          properties: %{
            street: [type: :string, required: true],
            country: [type: :string, required: true]
          }
        ]
      },
      required: true
    ]
  }
  def validate_map(conn, params) do
    @api_param_types
    |> Validator.parse(params)
    |> Validator.get_validated_changes!()
    |> then(fn params -> json(conn, params) end)
  end
end
