defmodule April.Validator do
  alias Ecto.Changeset

  alias April.{
    Error
  }

  @type type_validate :: [
          type: atom() | {:array, atom()} | {:array, map()},
          acceptance: [],
          change:
            (atom(), term() -> [{atom(), String.t()} | {atom(), {String.t(), Keyword.t()}}]),
          confirmation: [] | [{:required, boolean()}],
          exclusion: Enum.t(),
          format: Regex.t(),
          inclusion: Enum.t(),
          length: [
            {:is, :number},
            {:min, :number},
            {:max, :number},
            {:count, :graphemes | :codepoints}
          ],
          number: [
            {:less_than, :number},
            {:greater_than, :number},
            {:less_than_or_equal_to, :number},
            {:greater_than_or_equal_to, :number},
            {:equal_to, :number},
            {:not_equal_to, :number}
          ],
          required: boolean(),
          subset: Enum.t()
        ]

  @type types :: %{atom() => type_validate()}

  @supported_validations [
    :acceptance,
    :change,
    :confirmation,
    :exclusion,
    :format,
    :inclusion,
    :length,
    :number,
    :required,
    :subset
  ]

  @item_property :__item__

  @default_split_opts [pattern: [" ", ","]]

  @doc """
  A wrapped function based on Ecto.Changeset customized for parse nested `types` to validate `params`

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
  params = %{"name" => "pi", "age": 24}
  types = %{
    name: [type: :string, required: true],
    age: [type: :interger, required: true, inclusion: 1..150]
  }

  %{name, age} =
    types
    |> parse(params)
    |> get_validated_changes!()

  ## Custom validate types
    - Validate properties (pairs of key and value) of a map
      types = %{
        map: [
          type: :map,
          properties: %{},
          length: ...
          number: ...
          required: ...
        ]
      }

    - Validate values of a map
      types = %{
        map_value: [
          type: {:map, :map},
          length: ...
          number: ...
          required: ...

          items: [
            type: :map,
            properties: %{},
            length: ...
            number: ...
            required: ...
          ]
        ]
      }

    - Validate items of an array
      types = %{
        array_item: [
          type: {:array, :string | :integer | :boolean},
          items: [
            number: [min: 0, max: 6]
          ]
        ]
      }

    - Validate an array of map
      types = %{
        array_map: [
          type: {:array, :map},
          length: ...
          number: ...
          required: ...

          items: [
            type: :map,
            properties: %{},
            length: ...
            number: ...
            required: ...
          ]
        ]
      }
  """
  @spec parse(types, map | Enum.t(), Keyword.t()) :: Ecto.Changeset.t() | nil
  def parse(types, params, opts \\ [])

  def parse(nil, [_ | _] = params, _opts), do: %Changeset{valid?: true, changes: params}
  def parse(nil, _params, _opts), do: nil
  def parse(_types, nil, _opts), do: %Changeset{valid?: true, changes: nil}
  def parse(_types, [], _opts), do: nil

  # parse a map
  def parse(%{} = types, params, opts) when is_map(params) do
    {self_types, nested_types, validate_funcs} =
      Enum.reduce(
        types,
        {%{}, %{}, []},
        fn {field, meta_type}, {self_types, nested_types, validations} ->
          field_type = Keyword.get(meta_type, :type)
          validations = _get_validations(field, meta_type, validations)

          case field_type do
            :map ->
              {
                Map.put(self_types, field, field_type),
                Map.put(nested_types, field, meta_type),
                validations
              }

            {:map, _} ->
              {
                Map.put(self_types, field, field_type),
                Map.put(nested_types, field, meta_type),
                validations
              }

            {:array, _} ->
              {
                Map.put(self_types, field, field_type),
                Map.put(nested_types, field, meta_type),
                validations
              }

            {:joined_string, _} ->
              {
                Map.put(self_types, field, :string),
                Map.put(nested_types, field, meta_type),
                validations
              }

            # validate ecto primitive types
            _ ->
              {
                Map.put(self_types, field, field_type),
                nested_types,
                validations
              }
          end
        end
      )

    self_types
    |> _parse_self_types(params, opts)
    |> _parse_nested_types(nested_types, opts)
    |> _validate_parsed_type(validate_funcs)
  end

  # parse map values
  def parse(%{} = types, [{key, _value} | rest] = params, opts) do
    result =
      Enum.reduce(params, {%{}, []}, fn
        {field, nil}, {success, failure} ->
          {success, failure}

        {field, el}, {success, failure} ->
          case parse(types, el, opts) do
            %Changeset{valid?: true, changes: changes} ->
              {Map.put(success, field, changes), failure}

            %Changeset{valid?: false, errors: errors} ->
              {success, failure ++ Enum.map(errors, fn error -> {field, error} end)}

            _ ->
              {success, failure}
          end
      end)

    case result do
      {_, [_ | _] = failure} ->
        Enum.reduce(
          failure,
          %Changeset{},
          fn {field, {k, {mgs, opts}}}, changeset ->
            field_name = if is_nil(k), do: "[#{field}]", else: "[#{field}].#{k}"
            Changeset.add_error(changeset, field_name, mgs, opts)
          end
        )

      {success, _} ->
        %Changeset{changes: success, valid?: true}
    end
  end

  # parse an array
  def parse(%{} = types, params, opts) when is_list(params) do
    result =
      Enum.reduce(params, {[], [], 0}, fn
        nil, {success, failure, index} ->
          {success, failure, index + 1}

        el, {success, failure, index} ->
          case parse(types, el, opts) do
            %Changeset{valid?: true, changes: %{@item_property => changes}} ->
              {success ++ [changes], failure, index + 1}

            # %Changeset{valid?: true, changes: changes} when changes == %{} ->
            #   {success, failure, index + 1}

            %Changeset{valid?: true, changes: changes} ->
              {success ++ [changes], failure, index + 1}

            %Changeset{valid?: false, errors: errors} ->
              {success,
               failure ++
                 Enum.map(errors, fn
                   {@item_property, err} -> {index, {nil, err}}
                   error -> {index, error}
                 end), index + 1}

            _ ->
              {success, failure, index + 1}
          end
      end)

    case result do
      {_, [_ | _] = failure, _} ->
        failure
        |> Enum.reduce(
          %Changeset{},
          fn {field, {k, {mgs, opts}}}, changeset ->
            field_name = if is_nil(k), do: "[#{field}]", else: "[#{field}].#{k}"
            Changeset.add_error(changeset, field_name, mgs, opts)
          end
        )

      {success, _, _} ->
        %Changeset{changes: success, valid?: true}
    end
  end

  # raise error invalid parse types
  def parse(types, params, _opts) do
    raise(
      Error,
      code: Error.c_INTERNAL_SERVER_ERROR(),
      message: "Not yet supported for parsing #{inspect(params)} of type #{inspect(types)}"
    )
  end

  defp _parse_self_types(%{} = self_types, params, opts) do
    Changeset.cast({%{}, self_types}, params, Map.keys(self_types), opts)
  end

  defp _parse_nested_types(%Changeset{} = changeset, %{} = nested_types, opts) do
    Enum.reduce(nested_types, changeset, fn {field, meta_type}, cs ->
      field_type = _get_nested_type(meta_type)
      field_value = _get_nested_change(meta_type, changeset, field)

      case parse(field_type, field_value, opts) do
        %Changeset{valid?: true, changes: changes} ->
          Changeset.update_change(cs, field, fn _ -> changes end)

        %Changeset{valid?: false, errors: errors} ->
          errors =
            Enum.map(errors, fn {nested_field, error} ->
              {"#{_get_reason_field(Keyword.get(meta_type, :type), field)}#{nested_field}", error}
            end)

          cs = %{cs | errors: errors ++ cs.errors, valid?: errors == [] and cs.valid?}

          case Keyword.get(meta_type, :type) do
            {:joined_string, item_type} ->
              Changeset.add_error(
                cs,
                field,
                "is invalid",
                type: :joined_string,
                validation: :cast
              )

            _ ->
              cs
          end

        _ ->
          cs
      end
    end)
  end

  defp _get_nested_type(meta_type) do
    case Keyword.get(meta_type, :type) do
      :map ->
        _get_properties_type(meta_type)

      {:map, :map} ->
        _get_properties_type(Keyword.get(meta_type, :values))

      {:array, :map} ->
        _get_properties_type(Keyword.get(meta_type, :items))

      {:array, item_type} ->
        with item_types when is_list(item_types) <- Keyword.get(meta_type, :items) do
          %{@item_property => item_types ++ [type: item_type]}
        else
          _ -> nil
        end

      {:joined_string, item_type} ->
        with item_types when is_list(item_types) <- Keyword.get(meta_type, :items) do
          %{@item_property => item_types ++ [type: item_type]}
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp _get_properties_type(nil), do: nil
  defp _get_properties_type(meta_type), do: Keyword.get(meta_type, :properties)

  defp _get_nested_change(meta_type, changeset, field) do
    with change when not is_nil(change) <- Changeset.get_change(changeset, field) do
      case Keyword.get(meta_type, :type) do
        {:map, :map} ->
          Map.to_list(change)

        {:array, :map} ->
          change

        {:array, item_type} ->
          with item_types when is_list(item_types) <- Keyword.get(meta_type, :items) do
            Enum.map(change, fn
              nil -> nil
              el -> %{@item_property => el}
            end)
          else
            _ -> change
          end

        {:joined_string, item_type} ->
          split = Keyword.get(meta_type, :splitter, []) ++ @default_split_opts

          change =
            apply(String, :split, [
              change,
              Keyword.get(split, :pattern),
              [trim: true] ++ Keyword.take(split, [:parts])
            ])

          with item_types when is_list(item_types) <- Keyword.get(meta_type, :items) do
            Enum.map(change, fn
              nil -> nil
              el -> %{@item_property => el}
            end)
          else
            _ -> change
          end

        _ ->
          change
      end
    else
      change -> change
    end
  end

  @array_types [:array, :map, :joined_string]
  defp _get_reason_field({field_type, _}, field) when field_type in @array_types, do: field

  defp _get_reason_field(_, field), do: "#{field}."

  defp _validate_parsed_type(%Changeset{} = changeset, validate_funcs) do
    Enum.reduce(
      validate_funcs,
      changeset,
      fn {func, opts}, cs ->
        apply(Changeset, func, [cs | opts])
      end
    )
  end

  @spec _get_validations(atom, type_validate, Enum.t()) :: Ecto.Changeset.t()
  defp _get_validations(field, type_validate, validations) do
    type_validate
    |> Keyword.take(@supported_validations)
    |> Enum.reduce(validations, fn {validate, opts}, validations ->
      case {validate, opts} do
        {:required, false} ->
          validations

        {:required, true} ->
          Keyword.update(validations, :validate_required, [[field]], fn [arr] ->
            [[field | arr]]
          end)

        _ ->
          [{String.to_atom("validate_#{validate}"), [field, opts]} | validations]
      end
    end)
  end

  # =======================================

  @spec get_validated_changes!(Ecto.Changeset.t()) :: map
  def get_validated_changes!(%Changeset{} = changeset) do
    unless changeset.valid? do
      raise Ecto.InvalidChangesetError, changeset: changeset
    end

    changeset.changes
  end
end
