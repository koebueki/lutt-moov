import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :luttmoov, Luttmoov.Repo,
  database: Path.expand("../db/luttmoov_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :luttmoov, LuttmoovWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ISs4FxmtEUz7SQKy8NlWs01k5A8DGhQwImftmDfsCYKJ+ibtvJnginhv3/BH2+WX",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Route Geofox API calls to a Req.Test stub instead of the network
config :luttmoov, Luttmoov.Geofox, req_options: [plug: {Req.Test, Luttmoov.Geofox}]
