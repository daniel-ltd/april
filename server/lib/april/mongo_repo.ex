defmodule April.MongoRepo do
  use Mongo.Repo,
    otp_app: :april,
    topology: :mongo
end
