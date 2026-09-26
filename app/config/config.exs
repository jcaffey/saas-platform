# config/config.exs
import Config

config :ex_aws,
  http_client: ExAws.Request.Req,
  security_token: [{:system, "AWS_SESSION_TOKEN"}]
