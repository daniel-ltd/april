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

  def parse(_types, params, _opts) when is_nil(params), do: %Changeset{valid?: true}

  def parse(%{} = types, params, opts) when is_map(params) do
    {delegate_types, self_types, nested_types, validate_funcs, params} =
      Enum.reduce(types, {%{}, %{}, %{}, [], params},
        fn {field, type_validate}, {delegate_types, self_types, nested_types, validations, params} ->

          type = Keyword.get(type_validate, :type)
          validations = _get_validations(field, type_validate, validations)

          case type do
            # validate a schema
            {:schema, _} ->
              {
                delegate_types,
                Map.put(self_types, field, :map),
                Map.put(nested_types, field, type),
                validations,
                params
              }

            # validate a schema's field
            {:schema_field, _} ->
              {
                Map.put(delegate_types, field, type),
                self_types,
                nested_types,
                validations,
                params
              }
            {:schema_field, _, _} ->
              {
                Map.put(delegate_types, field, type),
                self_types,
                nested_types,
                validations,
                params
              }

            # validate array of map
            {:array, %{} = _} ->
              {
                delegate_types,
                Map.put(self_types, field, {:array, :map}),
                Map.put(nested_types, field, type),
                validations,
                params
              }

            # validate array of schema
            {:array_schema, _} ->
              {
                delegate_types,
                Map.put(self_types, field, {:array, :map}),
                Map.put(nested_types, field, type),
                validations,
                params
              }

            # validate map with pairs of key and value
            {:map, %{} = _} ->
              {
                delegate_types,
                Map.put(self_types, field, :map),
                Map.put(nested_types, field, type),
                validations,
                params
              }

            # validate map value only
            {:map_value, %{} = _} ->
              {
                delegate_types,
                Map.put(self_types, field, {:array, :map}),
                Map.put(nested_types, field, type),
                validations,
                Map.replace(
                  params,
                  Atom.to_string(field),
                  Map.values(
                    Map.get(
                      params,
                      Atom.to_string(field)
                    )
                  )
                )
              }

            # validate map value is a schema
            {:map_schema, _} ->
              {
                delegate_types,
                Map.put(self_types, field, {:array, :map}),
                Map.put(nested_types, field, type),
                validations,
                Map.replace(
                  params,
                  Atom.to_string(field),
                  Map.values(
                    Map.get(
                      params,
                      Atom.to_string(field)
                    )
                  )
                )
              }

            # validate ecto primitive types
            _ ->
              {
                delegate_types,
                Map.put(self_types, field, type),
                nested_types,
                validations,
                params
              }
          end
        end)

    delegate_types
    |> _parse_delegate_types(params)
    |> then(fn cs -> _parse_self_types(self_types, params, cs, opts) end)
    |> then(fn cs -> _parse_nested_types(nested_types, cs, opts) end)
    |> then(fn cs -> _validate_parsed_type(validate_funcs, cs, opts) end)
  end

  def parse(schema_or_types, params, opts) when is_list(params) do
    result =
      Enum.reduce(params, {[], []}, fn el, {success, failure} ->
        nested_cs = parse(schema_or_types, el, opts)
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

  def parse(schema, params, _opts) when is_atom(schema) and is_map(params) do
    apply(schema, :changeset, [struct(schema), params])
  end

  def parse(types, params, _opts) when is_map(params) or is_list(params) do
    raise(
      Error,
      code: Error.c_INTERNAL_SERVER_ERROR(),
      message: "Not yet supported for parsing #{inspect(params)} of type #{inspect(types)}"
    )
  end

  defp _parse_delegate_types(delegate_types, _) when map_size(delegate_types) == 0 do
    Changeset.change({%{}, %{}})
  end

  defp _convert_delegate_types(%{} = delegate_types) do
    delegate_types
    |> Enum.group_by(
        fn {_field, types} -> elem(types, 1) end,
        fn
          {param_name, {_, _}} ->
            {param_name, param_name}

          {param_name, {_, _, field}} ->
            {field, param_name}
        end
      )
    |> Enum.map(
        fn {schema, schema_fields} ->
          _uniq_split_schema_fields(schema, schema_fields)
        end
      )
    |> List.flatten()
  end

  defp _convert_delegate_types_to_data_types(delegate_types) do
    Enum.map(
      delegate_types,
      fn {schema, schema_fields} ->
        Enum.map(
          schema_fields,
          fn {field, param_name} ->
            {param_name, _get_field_type!(schema, field)}
          end
        )
      end
    )
    |> List.flatten()
    |> Enum.into(%{})
  end

  defp _get_field_type!(schema, field) do
    case apply(schema, :__schema__, [:type, field]) do
      nil ->
        raise(
          Error,
          code: Error.c_INTERNAL_SERVER_ERROR(),
          message: "Can not get data type of field #{schema}.#{field}"
        )

      field_type -> field_type
    end
  end

  defp _parse_delegate_types(%{} = delegate_types, %{} = params) do
    converted_types = _convert_delegate_types(delegate_types)
    delegate_data_types = _convert_delegate_types_to_data_types(converted_types)

    Enum.reduce(
      converted_types,
      Changeset.change({%{}, delegate_data_types}),
      fn {schema, fields}, cs ->

        params =
          Enum.into(fields, %{}, fn {field, param_name} ->
            {field, Map.get(params, Atom.to_string(param_name))}
          end)

        %{changes: changes, errors: errors} = apply(schema, :changeset, [struct(schema), params])

        cs =
          changes
          |> Map.new(fn {field, change_data} -> {Keyword.get(fields, field), change_data} end)
          |> then(fn changes -> Changeset.change(cs, changes) end)

        errors =
          Enum.reduce(
            errors,
            [],
            fn
              {_field, {_mgs, [validation: :required]}}, acc ->
                acc

              {field, err}, acc ->
                [{Keyword.get(fields, field), err} | acc]
            end
          )

        %{cs | errors: errors ++ cs.errors, valid?: errors == [] and cs.valid?}
      end
    )
  end

  defp _uniq_split_schema_fields(_schema, []), do: []

  defp _uniq_split_schema_fields(schema, schema_fields) do
    uniq = Enum.uniq_by(schema_fields, fn {field, _param_name} -> field end)

    [{schema, uniq} | _uniq_split_schema_fields(schema, schema_fields -- uniq)]
  end

  defp _parse_self_types(%{} = self_types, params, %Changeset{} = changeset, opts) do
    {%{}, self_types}
    |> Changeset.cast(params, Map.keys(self_types), opts)
    |> then(fn cs -> _merge_changeset(changeset, cs) end)
  end

  defp _merge_changeset(%Changeset{types: cs1_types} = cs1, %Changeset{types: cs2_types} = cs2) do
    new_types = Map.merge(cs1_types, cs2_types)
    Changeset.merge(%{cs1 | types: new_types}, %{cs2 | types: new_types})
  end

  defp _parse_nested_types(%{} = nested_types, %Changeset{} = changeset, opts) do
    Enum.reduce(nested_types, changeset, fn {field, {field_type, types}}, cs ->
      nested_cs = parse(types, Changeset.get_change(cs, field), opts)

      case nested_cs do
        %{valid?: true} ->
          Changeset.update_change(cs, field, fn _ -> nested_cs.changes end)

        %{valid?: false, errors: errors} ->
          errors = Enum.map(errors, fn {nested_field, error} -> {"#{_get_reason_field(field_type, field)}.#{nested_field}", error} end)
          %{cs | errors: errors ++ cs.errors, valid?: false}

        _ -> cs
      end
    end)
  end

  @array_types [:array, :array_schema, :map_value, :map_schema]
  defp _get_reason_field(field_type, field) do
    if Enum.member?(@array_types, field_type) do
      "#{field}[]"
    else
      field
    end
  end

  defp _validate_parsed_type(validate_funcs, %Changeset{} = changeset, opts) do
    Enum.reduce(
      validate_funcs,
      changeset,
      fn {func, opts}, cs ->
        apply(Changeset, func, [cs | opts])
      end
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
