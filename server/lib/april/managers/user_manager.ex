defmodule April.UserManager do
  import Ecto.Query, warn: false

  alias April.{
    Repo,
    User,
    Permission,
    UserPermission,
    UserGroup,
    GroupPermission
  }
  alias Argon2

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def authenticate_user(username, plain_text_password) do
    query = from u in User, where: u.username == ^username
    case Repo.one(query) do
      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
      user ->
        if Argon2.verify_pass(plain_text_password, user.password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def get_all_user_perm(id) do
    # Permission
    # |> join(:inner, [perm], u_perm in UserPermission, on: u_perm.permission_id == perm.id and u_perm.user_id == ^id)
    # |> join(:inner, [perm, u_perm], u_gr in UserGroup, on: u_gr.user_id == u_perm.user_id)
    # |> join(:left, [perm, u_perm, u_gr], gr_perm in GroupPermission, on: gr_perm.group_id == u_gr.id)
    # |> select([perm, user, group], map(perm, [:id, :codename]))
    # |> Repo.all()

    User
    |> join(:left, [user], perm in assoc(user, :permissions))
    |> join(:left, [user], group in assoc(user, :groups))
    |> join(:left, [user, perm, user_gr], gr_perm in GroupPermission, on: gr_perm.group_id == user_gr.group_id)
    |> where([user], user.id == 2)
    |> select([user, perm], map(perm, [:id, :codename]))
    |> Repo.all()
  end

  def has_perm(id, perm) do
  end
end
