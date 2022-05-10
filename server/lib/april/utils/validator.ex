defmodule April.Validator do
  alias Ecto.Changeset

  alias April.{
    Error,
  }

  @type type_validate :: [
    type: atom() | {:array, atom()} | {:array, map()},
    acceptance: [],
    change: (atom(), term() -> [{atom(), String.t()} | {atom(), {String.t(), Keyword.t()}}]),
    confirmation: [] | [{:required, boolean()}],
    exclusion: Enum.t(),
    format: Regex.t(),
    inclusion: Enum.t(),
    length: [{:is, :number}, {:min, :number}, {:max, :number}, {:count, :graphemes | :codepoints}],
    number: [{:less_than, :number}, {:greater_than, :number}, {:less_than_or_equal_to, :number}, {:greater_than_or_equal_to, :number}, {:equal_to, :number}, {:not_equal_to, :number}],
    required: boolean(),
    subset: Enum.t()
  ]

  @type types :: %{atom() => type_validate()}

  @default_changeset_data %{}
  @supported_validations [:acceptance, :change, :confirmation, :exclusion, :format, :inclusion, :length, :number, :required, :subset]
  
  @doc """
  A wrapped function based on Ecto.Changeset customized for parse nested `types` to validate `params`

  ## Custom validate types
    * Validate array of map type
        params = %{
          "students" => [
            %{
              "id" => 1,
              "name" => "John",
              "score" => 7
            },
            ...
          ]
        }

        types = %{
          students: [
            type: {
              :array,
              %{
                id: [type: :integer, required: true],
                name: [type: :string, required: true],
                score: [type: :float, number: [min: 0, max: 10]]
              }
            }
          ]
        }

    * Validate map with pairs of key and value
        params = %{
          "user" => %{
            "id" => "st-001",
            "name" => "John",
            "email" => "example@example.com",
            "email_confirmation" => "example@example.com"
          }
        }

        types = %{
          user: [
            type: {
              :map,
              %{
                id: [type: :string, required: true],
                name: [type: :string, required: true, exclusion: ["admin", "superadmin"], length: [min: 3]],
                email: [type: :string, format: ~r/@/, confirmation: [required: true]]
              }
            },
            required: true
          ]
        }

    * Validate map value only
        params = %{
          "address" => %{
            "0" => %{
              "street" => "somewhere",
              "country" => "brazil"
            },
            "1" => %{
              "street" => "elsewhere",
              ...
            },
            ...
          }
        }

        types = %{
          address: [
            type: {
              :map_value,
              %{
                street: [type: :string, required: true],
                country: [type: :string, required: true],
                zipcode: [type: :string, length: [is: 6], change: &test_change/2]
              }
            },
            required: true
          ]
        }

  ## Ecto primitive types
    * :id
    * :binary_id
    * :integer
    * :float
    * :boolean
    * :string
    * :binary
    * {:array, inner_type}
    * :map
    * {:map, inner_type}
    * :decimal
    * :date
    * :time
    * :time_usec
    * :naive_datetime
    * :naive_datetime_usec
    * :utc_datetime
    * :utc_datetime_usec

  ## Examples
  params = %{"name" => "John", "age": 24}
  types = %{
    name: [type: :string, required: true],
    age: [type: :interger, required: true, inclusion: 1..150]
  }

  %{name, age} =
    types
    |> parse(params)
    |> get_validated_changes!()
  """
  @spec parse(types, map | Enum.t, Keyword.t) :: Ecto.Changeset.t
  def parse(types, params, opts \\ [])

  def parse(%{} = types, params, opts) when is_list(params) do
    result =
      Enum.reduce(params, {[], []}, fn el, {success, failure} ->
        nested_cs = parse(types, el, opts)
        if nested_cs.valid? do
          {[nested_cs.changes | success], failure}
        else
          {success, failure ++ nested_cs.errors}
        end
      end)

    case result do
      {_, [_|_] = failure} ->
        failure
        |> Enum.uniq_by(fn {k, {_mgs, opts}} -> {k, Keyword.get(opts, :validation)} end)
        |> Enum.reduce(%Changeset{},
            fn {k, {mgs, opts}}, changeset ->
              Changeset.add_error(changeset, k, mgs, opts)
            end
          )

      {success, _} ->
        %Changeset{changes: success, valid?: true}
    end
  end

  def parse(%{} = types, params, opts) when is_map(params) do
    {self_types, nested_types, validate_func} =
      Enum.reduce(types, {%{}, %{}, []},
        fn {field, type_validate}, {self_types, nested_types, validations} ->

          type = Keyword.get(type_validate, :type)
          validations = _get_validations(field, type_validate, validations)

          case type do
            # validate array of map
            {:array, %{} = _} ->
              {
                Map.put(self_types, field, {:array, :map}),
                Map.put(nested_types, field, type),
                validations
              }

            # validate map with pairs of key and value
            {:map, %{} = _} ->
              {
                Map.put(self_types, field, :map),
                Map.put(nested_types, field, type),
                validations
              }

            # validate map value only
            {:map_value, %{} = _} ->
              {
                Map.put(self_types, field, :map),
                Map.put(nested_types, field, type),
                validations
              }

            # validate ecto primitive types
            _ ->
              {
                Map.put(self_types, field, type),
                nested_types,
                validations
              }
          end
        end)

    changeset =
      Enum.reduce(
        validate_func,
        Changeset.cast({@default_changeset_data, self_types}, params, Map.keys(self_types), opts),
        fn {func, opts}, cs ->
          apply(Changeset, func, [cs | opts])
        end
      )

    Enum.reduce(nested_types, changeset, fn {field, types}, cs ->
      nested_cs =
        case types do
          {:map_value, %{} = types} ->
            parse(types, Map.values(Changeset.get_change(cs, field, %{})), opts)

          {_, types} ->
            parse(types, Changeset.get_change(cs, field), opts)

          _ ->
            raise(
              Error,
              code: Error.c_INTERNAL_SERVER_ERROR(),
              message: "Not yet supported for parsing type #{inspect(types)}"
            )
        end

      if nested_cs.valid? do
        Changeset.update_change(cs, field, fn _ -> nested_cs.changes end)
      else
        %{cs | errors: nested_cs.errors ++ cs.errors, valid?: false}
      end
    end)
  end

  def parse(%{} = _types, params, _opts) when is_nil(params), do: %Changeset{valid?: true}

  def parse(types, params, _opts) do
    raise(
      Error,
      code: Error.c_INTERNAL_SERVER_ERROR(),
      message: "Not yet supported for parsing #{inspect(params)} of type #{inspect(types)}"
    )
  end

  @spec _get_validations(atom, type_validate, Enum.t) :: Ecto.Changeset.t 
  defp _get_validations(field, type_validate, validations) do
    type_validate
    |> Keyword.take(@supported_validations)
    |> Enum.reduce(validations, fn {validate, opts}, validations ->
        case {validate, opts} do
          {:required, false} ->
            validations

          {:required, true} ->
            Keyword.update(validations, :validate_required, [[field]], fn [arr] -> [[field | arr]] end)

          _ ->
            [{String.to_atom("validate_#{validate}"), [field, opts]} | validations]
        end
      end)
  end

  # =======================================

  @spec get_validated_changes!(Ecto.Changeset.t) :: map
  def get_validated_changes!(%Changeset{} = changeset) do
    unless changeset.valid? do
      raise Ecto.InvalidChangesetError, changeset: changeset
    end

    changeset.changes
  end
end
