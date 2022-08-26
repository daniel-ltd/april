defmodule AprilWeb.TestController do
  use AprilWeb, :controller

  def test(conn, _) do
    start_time = :os.system_time(:millisecond)
    IO.inspect("start bulk")

    1..1_000_000
    |> Stream.map(fn i -> Mongo.BulkOps.get_insert_one(%{number: i}) end)
    |> Mongo.UnorderedBulk.write(:mongo, "bulk", 1_000)
    |> Stream.run()

    IO.inspect("end bulk")
    ((:os.system_time(:millisecond) - start_time) / 1000)
    |> IO.inspect(label: "run time")

    # Mongo.insert_one(:mongo, "users", %{first_name: "John", last_name: "Smith"})
    # |> IO.inspect()

    # Mongo.find(:mongo, "users", %{first_name: "John"}, limit: 20)
    # |> IO.inspect()

    json(conn, "test")
  end
end
