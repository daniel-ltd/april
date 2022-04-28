defmodule April.UserManagerFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `April.UserManager` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        password: "some password",
        username: "some username"
      })
      |> April.UserManager.create_user()

    user
  end
end
