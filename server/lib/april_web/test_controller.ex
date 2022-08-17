defmodule AprilWeb.TestController do
  use AprilWeb, :controller

  def test(conn, _) do
    # {:ok, _} =
    # Mongo.start_link(
    #   name: :mongo,
    #   database: "admin",
    #   hostname: "mongo",
    #   username: "april_admin",
    #   password: "april_admin"
    # )

    1..1_00
    |> Stream.map(fn i -> Mongo.BulkOps.get_insert_one(%{number: i}) end)
    |> Mongo.UnorderedBulk.write(:mongo, "bulk", 1_000)
    |> Stream.run()

    # Mongo.insert_one(:mongo, "users", %{first_name: "John", last_name: "Smith"})
    # |> IO.inspect()

    # Mongo.find(:mongo, "users", %{first_name: "John"}, limit: 20)
    # |> IO.inspect()

    json(conn, "test")
  end
end
