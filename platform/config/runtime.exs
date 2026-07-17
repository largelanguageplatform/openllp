import Config
import Dotenvy

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand(".")

source!([
  Path.absname(".env", env_dir_prefix),
  System.get_env()
])

# API keys
llm_api_key = env!("LLM_API_KEY", :string?, nil)
turnstile_site_key = env!("TURNSTILE_SITE_KEY", :string?, nil)
turnstile_secret_key = env!("TURNSTILE_SECRET_KEY", :string?, nil)
bucket_name = env!("BUCKET_NAME", :string?, nil)
aws_access_key_id = env!("AWS_ACCESS_KEY_ID", :string?, nil)
aws_region = env!("AWS_REGION", :string?, "auto")
aws_endpoint_url = env!("AWS_ENDPOINT_URL_S3", :string?, nil)
aws_secret_access_key = env!("AWS_SECRET_ACCESS_KEY", :string?, nil)
pdf_agent_base_url = env!("PDF_AGENT_BASE_URL", :string?, nil)
ga4_measurement_id = env!("GA4_MEASUREMENT_ID", :string?, nil)
llm_model = env!("LLM_MODEL", :string?, "gpt-oss:120b")
llm_url = env!("LLM_URL", :string?, "https://ollama.com/api")

if config_env() == :prod do
  vars =
    [
      {"TURNSTILE_SECRET_KEY", turnstile_secret_key},
      {"TURNSTILE_SITE_KEY", turnstile_site_key},
      {"LLM_API_KEY", llm_api_key},
      {"BUCKET_NAME", bucket_name},
      {"AWS_ACCESS_KEY_ID", aws_access_key_id},
      {"AWS_ENDPOINT_URL_S3", aws_endpoint_url},
      {"AWS_SECRET_ACCESS_KEY", aws_secret_access_key}
    ]
    |> Enum.filter(fn {_, v} -> v == nil end)
    |> Enum.map(fn {n, _} -> n end)

  case length(vars) do
    1 ->
      [name] = vars
      raise "environment variable " <> name <> " is missing!"

    n when n > 1 ->
      names = Enum.join(vars, ", ")
      raise "environment variables " <> names <> " are missing!"

    _else ->
      :ok
  end
end

if config_env() in [:prod, :debug] do
  # Phoenix configs
  phx_server? = env!("PHX_SERVER", :boolean, true)
  use_http? = env!("USE_HTTP", :boolean, false)
  port = env!("PORT", :integer!, 4000)
  host = env!("PHX_HOST", :string, "example.com")
  secret_key_base = env!("SECRET_KEY_BASE", :string, "")
  dns_cluster_query = env!("DNS_CLUSTER_QUERY", :string?, nil)
  ecto_ipv6 = env!("ECTO_IPV6", :boolean, true)

  # DB configs
  db_url = env!("DATABASE_URL")
  db_pool_size = env!("POOL_SIZE", :integer, 10)

  database_url =
    db_url ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if ecto_ipv6, do: [:inet6], else: []

  config :platform, Platform.Repo,
    # ssl: true,
    url: database_url,
    pool_size: db_pool_size,
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    secret_key_base ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  endpoint_url =
    if use_http?,
      do: [host: host, port: 80, scheme: "http"],
      else: [host: host, port: 443, scheme: "https"]

  config :platform, :dns_cluster_query, dns_cluster_query

  config :platform, PlatformWeb.Endpoint,
    url: endpoint_url,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :platform, PlatformWeb.Endpoint, server: phx_server?

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :platform, PlatformWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :platform, PlatformWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end

if llm_api_key do
  config :platform, Platform.Chaos.Agent,
    llm_model: llm_model,
    llm_url: llm_url,
    llm_api_key: llm_api_key
end

# Optional analytics (Google Analytics 4) — disabled unless GA4_MEASUREMENT_ID is set
if ga4_measurement_id do
  config :platform, :ga4_measurement_id, ga4_measurement_id
end

# Optional external PDF document-processing agent
if pdf_agent_base_url do
  config :platform, Platform.PDFAgent,
    invoice_url: pdf_agent_base_url <> "/invoice",
    w2_url: pdf_agent_base_url <> "/w2",
    receipt_url: pdf_agent_base_url <> "/receipt",
    nec1099_url: pdf_agent_base_url <> "/1099-nec",
    bank_statement_url: pdf_agent_base_url <> "/bank-statement"
end

if turnstile_secret_key && turnstile_site_key do
  config :platform, :turnstile,
    site_key: turnstile_site_key,
    secret_key: turnstile_secret_key
end

if bucket_name &&
     aws_access_key_id &&
     aws_region &&
     aws_endpoint_url &&
     aws_secret_access_key do
  %URI{scheme: scheme, host: host, port: port} = URI.parse(aws_endpoint_url)

  config :platform, Platform.StorageBucket,
    bucket: bucket_name,
    location_prefix: "public/uploads"

  config :ex_aws, :s3,
    scheme: scheme <> "://",
    host: host,
    port: port

  config :ex_aws,
    access_key_id: aws_access_key_id,
    secret_access_key: aws_secret_access_key
end
