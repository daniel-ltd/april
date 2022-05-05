defmodule April.Validator do
  alias Ecto.Changeset

  alias April.{
    Error,
  }

  # =============================================
  # parse(%Changeset{} changeset, %{__struct__} struct, %{} params, [] permitted, [] opts)
  # parse(%Changeset{} changeset, %{} types, %{} params, [] opts)
  # parse(%{__struct__} struct, %{} params, [] permitted, [] opts)
  # parse(%{} types, %{} params, [] opts)
  # =============================================
  @default_changeset_data %{}

  def parse(%Changeset{} = changeset, %{__struct__: module} = struct, %{} = params, permitted, opts) when is_list(opts) do
    cs1 = %{changeset | data: @default_changeset_data}
    cs2 = %{module.validate_fields(struct, params, permitted, opts) | data: @default_changeset_data}
    %{Changeset.merge(cs1, cs2) | types: _merge_changeset_types(cs1.types, cs2.types)}
  end

  def parse(data, types, params, opts \\ [])

  def parse(%Changeset{} = changeset, %{__struct__: _} = struct, %{} = params, permitted) do
    parse(changeset, struct, params, permitted, [])
  end

  def parse(%Changeset{} = changeset, %{} = types, %{} = params, opts) do
    cs1 = %{changeset | data: @default_changeset_data}
    cs2 = Changeset.cast({@default_changeset_data, types}, params, Map.keys(types), opts)
    %{Changeset.merge(cs1, cs2) | types: _merge_changeset_types(cs1.types, cs2.types)}
  end

  def parse(%{__struct__: module} = struct, %{} = params, permitted, opts) when is_list(permitted) do
    module.validate_fields(struct, params, permitted, opts)
  end

  def parse(%{} = types, %{} = params, opts, _) when is_list(opts) do
    Changeset.cast({@default_changeset_data, types}, params, Map.keys(types), opts)
  end

  def parse(%{} = types, %{} = params) do
    Changeset.cast({@default_changeset_data, types}, params, Map.keys(types))
  end

  defp _merge_changeset_types(type1, type2) do
    Map.merge(type1, type2, fn k, v1, v2 ->
      if v1 == v2 do
        v1
      else
        raise(
          Error,
          code: Error.c_INTERNAL_SERVER_ERROR(),
          message: "conflict merge changeset types on field #{inspect(k)} with type #{inspect(v1)} and #{inspect(v2)}"
        )
      end
    end)
  end

  # =================

  def parse_nested_types(types, params, opts \\ [])

  def parse_nested_types(%{} = types, params, opts) when is_list(params) do
    result =
      Enum.reduce(params, {[], []}, fn elm, {success, failure} ->
        nested_cs = parse_nested_types(types, elm, opts)
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

  def parse_nested_types(%{} = types, params, opts) when is_map(params) do
    {self_types, nested_types, self_validations} =
      Enum.reduce(types, {%{}, %{}, []},
        fn {field, type_validate}, {self_types, nested_types, validations} ->

          type = Keyword.get(type_validate, :type)
          validations = _get_validations(validations, field, type_validate)

          case type do
            {:array, %{} = _} ->
              {
                Map.put(self_types, field, {:array, :map}),
                Map.put(nested_types, field, type),
                validations
              }

            {:map, %{} = _} ->
              {
                Map.put(self_types, field, :map),
                Map.put(nested_types, field, type),
                validations
              }

            {:object, %{} = _} ->
              {
                Map.put(self_types, field, :map),
                Map.put(nested_types, field, type),
                validations
              }

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
        self_validations,
        parse(self_types, params, opts),
        fn {validate_func, opts}, cs ->
          apply(Changeset, validate_func, [cs | opts])
        end
      )

    Enum.reduce(nested_types, changeset, fn {field, types}, cs ->
      nested_cs =
        case types do
          {:map, %{} = types} ->
            parse_nested_types(types, Map.values(Changeset.get_change(cs, field, %{})), opts)

          {_, types} ->
            parse_nested_types(types, Changeset.get_change(cs, field), opts)

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

  def parse_nested_types(%{} = _types, params, _opts) when is_nil(params), do: %Changeset{valid?: true}

  def parse_nested_types(types, params, _opts) do
    raise(
      Error,
      code: Error.c_INTERNAL_SERVER_ERROR(),
      message: "Not yet supported for parsing #{inspect(params)} of type #{inspect(types)}"
    )
  end

  @supported_validations [:acceptance, :change, :confirmation, :exclusion, :format, :inclusion, :length, :number, :required, :subset]
  defp _get_validations(validations, field, validate) do
    validate
    |> Keyword.take(@supported_validations)
    |> Enum.reduce(validations, fn {v, opts}, validations ->
        case v do
          :required ->
            if Keyword.get(validate, :required, false) do
              Keyword.update(validations, :validate_required, [[field]], fn [arr] -> [[field | arr]] end)
            else
              validations
            end

          _ ->
            [{String.to_atom("validate_#{v}"), [field, opts]} | validations]
        end
      end)
  end

  # =======================================

  def get_validated_changes!(%Changeset{} = changeset) do
    unless changeset.valid? do
      raise Ecto.InvalidChangesetError, changeset: changeset
    end

    changeset.changes
  end
end
