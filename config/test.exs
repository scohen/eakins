import Config

config :eakins, ecto_repos: [Eakins.Repo]

config :eakins, Eakins.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "127.0.0.1",
  database: "eakins_test",
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

config :eakins, Eakins, imgproxy_host: "proxy.eakins.test"

config :logger, level: :error
