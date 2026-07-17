import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :platform, Platform.Repo,
  url:
    "postgres://platform:localdev@localhost:5432/platform_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :platform, PlatformWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  # Test-only throwaway key. Generate your own with: mix phx.gen.secret
  secret_key_base: "o85DscuGKR1KUdR636ishu1zaiDgmc3EOzfk01vBZF3ATciG1AxvuWalolAxsVFh",
  server: false

# In test we don't send emails
# Print only warnings and errors during test
config :logger, level: :error

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :platform, Platform.Chaos.Agent,
  llm_model: "gpt-oss:120b",
  llm_url: "http://localhost:11434/api",
  plug: {Req.Test, LLM.Test}

config :platform, Platform.StorageBucket,
  bucket: "localtest#{System.get_env("MIX_TEST_PARTITION")}",
  location_prefix: "public/uploads"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000

config :ex_aws,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin"
