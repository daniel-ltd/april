defmodule April.Error do
  @derive {Jason.Encoder, only: [:code, :reason]}
  defexception [:code, :reason, :message]

  @type error_code :: String.t
  @type t :: %__MODULE__{code: error_code, reason: String.t, message: String.t}

  def c_NOT_FOUND, do: "not_found"
  def c_REQUIRED_FIELD, do: "required"
  def c_NO_RESULT_FOUND, do: "no_results_error"
  def c_IS_INVALID, do: "is_invalid"
  def c_VALIDATE_FORMAT, do: "invalid_validate_format"
  def c_UNIQUE_CONSTRAINT, do: "unique_constraint"
  def c_FOREIGN_KEY_WRONG, do: "foreign_key_wrong"
  def c_VALIDATE_ACCEPTANCE, do: "validate_acceptance"
  def c_VALIDATE_SUBSET, do: "validate_subset"
  def c_VALIDATE_EXCLUSION, do: "validate_exclusion"
  def c_VALIDATE_CONFIRMATION, do: "validate_confirmation"
  def c_NO_ASSOC_CONSTRAINT, do: "no_assoc_contraint"
  def c_VALIDATE_LENGTH, do: "validate_length"
  def c_VALIDATE_NUMBER,  do: "validate_number"
  def c_AT_LEAST_ITEM, do: "at_least_item"
  def c_AT_LEAST_CHARACTER, do: "at_least_character"
  def c_AT_MOST_CHARACTER, do: "at_most_character"
  def c_AT_MOST_ITEM, do: "at_most_item"
  def c_LESS_THAN_NUMBER, do: "less_than_number"
  def c_GREATE_THAN_NUMBER, do: "greate_than_number"
  def c_LESS_THAN_OR_EQUAL, do: "less_than_or_equal"
  def c_GREATE_THAN_OR_EQUAL, do: "greater_than_or_equal_to"
  def c_EQUAL, do: "equal_to"
  def c_NOT_EQUAL, do: "not_equal_to"

  def c_INTERNAL_SERVER_ERROR, do: "internal_server_error"
  def c_TEMPLATE_NOT_FOUND, do: "template_not_found"
  def c_UNKNOWN_ERROR, do: "unknow_error"

  @impl true
  def message(%{code: code, reason: reason, message: mgs}) do
    """
    an error was raised with message: #{inspect(mgs)}

    code: #{inspect(code)}
    reason: #{inspect(reason)}
    """
  end

  @impl true
  def exception(opts) do
    code  = Keyword.get(opts, :code, c_INTERNAL_SERVER_ERROR())
    reason = Keyword.get(opts, :reason)
    msg = Keyword.get(opts, :message)
    %__MODULE__{code: code, reason: reason, message: msg}
  end

  @spec transform(t | Exception.t) :: {atom, t}
  def transform(%__MODULE__{code: code} = reason) do
    err_500 = c_INTERNAL_SERVER_ERROR()
    case code do
      ^err_500 -> {:internal_server_error, reason}
      :unauthenticated -> {:unauthorized, reason}
      :invalid_token -> {:unauthorized, reason}
      :already_authenticated -> {:unauthorized, reason}
      :no_resource_found -> {:unauthorized, reason}
      _ -> {:ok, reason}
    end
  end

  def transform(reason) do
    case reason do
      %Ecto.InvalidChangesetError{} ->
        {:ok, _transform_changeset_errors(reason.changeset)}

      %Ecto.NoResultsError{} ->
        {:ok, %__MODULE__{code: c_NO_RESULT_FOUND()}}

      %Ecto.ConstraintError{} ->
        {:ok, %__MODULE__{code: c_FOREIGN_KEY_WRONG()}}

      %Ecto.StaleEntryError{} ->
        {:internal_server_error, %__MODULE__{code: c_NO_RESULT_FOUND()}}

      %MyXQL.Error{} ->
        {:internal_server_error, %__MODULE__{code: _get_mysql_error_code(reason.mysql.code)}}

      %Phoenix.Router.NoRouteError{} ->
        {:not_found, %__MODULE__{code: c_NOT_FOUND()}}

      _ ->
        {:internal_server_error, %__MODULE__{code: c_INTERNAL_SERVER_ERROR()}}
    end
  end

  @spec _transform_changeset_errors(Ecto.Changeset.t) :: [t]
  defp _transform_changeset_errors(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Enum.reverse()
    |> Enum.map(fn {k, {_, opts}} -> %__MODULE__{code: _get_changset_error_code(opts), reason: k} end)
  end

  @spec _get_changset_error_code(Enum.t) :: error_code
  defp _get_changset_error_code(opts) do
    validation = Keyword.get(opts, :validation)
    kind = Keyword.get(opts, :kind)
    type = Keyword.get(opts, :type)

    case {validation, kind, type} do
      {:required, _, _} ->
        c_REQUIRED_FIELD()

      {:unsafe_unique, _, _} ->
        c_UNIQUE_CONSTRAINT()

      {:inclusion, _, _} ->
        c_IS_INVALID()

      {:cast, _, :utc_datetime} ->
        c_VALIDATE_FORMAT()

      {:cast, _, _} ->
        c_IS_INVALID()

      {:acceptance, _, _} ->
        c_VALIDATE_ACCEPTANCE()

      {:format, _, _} ->
        c_VALIDATE_FORMAT()

      {:subset, _, _} ->
        c_VALIDATE_SUBSET()

      {:exclusion, _, _} ->
        c_VALIDATE_EXCLUSION()

      {:confirmation, _, _} ->
        c_VALIDATE_CONFIRMATION()

      # FIXME I couldn't test this error case so I commented here to waiting for help
      # "is still associated with this entry" ->
      #   c_NO_ASSOC_CONSTRAINT()

      {:length, :is, :string} ->
        c_VALIDATE_LENGTH()

      {:length, :is, :list} ->
        c_VALIDATE_NUMBER()

      {:length, :min, :string} ->
        c_AT_LEAST_CHARACTER()

      {:length, :min, :list} ->
        c_AT_LEAST_ITEM()

      {:length, :max, :string} ->
        c_AT_MOST_CHARACTER()

      {:length, :max, :list} ->
        c_AT_MOST_ITEM()

      {_, :less_than, _} ->
        c_LESS_THAN_NUMBER()

      {_, :greater_than, _} ->
        c_GREATE_THAN_NUMBER()

      {_, :less_than_or_equal_to, _} ->
        c_LESS_THAN_OR_EQUAL()

      {_, :greater_than_or_equal_to, _} ->
        c_GREATE_THAN_OR_EQUAL()

      {_, :equal_to, _} ->
        c_EQUAL()

      {_, :not_equal_to, _} ->
        c_NOT_EQUAL()
        
      _ ->
        c_UNKNOWN_ERROR()
    end
  end

  @spec _get_mysql_error_code(number) :: error_code
  defp _get_mysql_error_code(code) do
    case code do
      1452 ->
        c_FOREIGN_KEY_WRONG()
      _ ->
        c_INTERNAL_SERVER_ERROR()
    end
  end
end
