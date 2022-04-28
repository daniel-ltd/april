# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :april,
  ecto_repos: [April.Repo]

# Configures the endpoint
config :april, AprilWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: AprilWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: April.PubSub,
  live_view: [signing_salt: "BLNaxL7F"]

config :guardian, April.UserManager.Guardian,
  issuer: "april",
  secret_key: "DqqpmlOiywSc+5t272OSlPY+sGVpcxHIYqLK5ufN/0oE/elsf/0D92vn1jffKXfg"

config :guardian, Guardian.DB,
  repo: April.Repo

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
