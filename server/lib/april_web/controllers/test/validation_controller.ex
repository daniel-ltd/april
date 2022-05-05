defmodule AprilWeb.ValidationController do
  use AprilWeb, :controller

  alias April.Validator

  @api_param_types %{
    year: [type: :intedfsdger, required: true],
    school_year: [type: :integer, required: true],
    school_textbooks: [
      type: {
        :map,
        %{
          subject_code: [type: :string, required: true],
          code: [type: :string, required: true]
        }
      },
      required: true
    ]
  }
  def validate(conn, params) do
    Validator.parse_nested_types("params", "sdf")
    %{
      year: year,
      school_year: school_year,
      school_textbooks: school_textbooks
    } = @api_param_types
    |> Validator.parse_nested_types(params)
    |> Validator.get_validated_changes!()
    # |> IO.inspect()

    json(conn, "success")
  end
end
