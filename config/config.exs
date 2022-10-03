import Config

config :eakins, env: config_env()

import_config "#{config_env()}.exs"
