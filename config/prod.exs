use Mix.Config

config :spades, SpadesWeb.Endpoint,
 url: [host: System.get_env("RENDER_EXTERNAL_HOSTNAME") || "localhost", port: 80],
 cache_static_manifest: "priv/static/cache_manifest.json",
 check_origin: [
   "prospades.vercel.app",
   
   "http://localhost:3000"
 ],
 front_end_email_confirm_url: "http://starspades.com/confirm-email/{token}",
 front_end_reset_password_url: "http://starspades.com/reset-password/{token}"

# Do not print debug messages in production
config :logger, level: :info

# Force SSL
config :spades, SpadesWeb.Endpoint,
 force_ssl: [rewrite_on: [:x_forwarded_proto]],
 url: [scheme: "https", host: System.get_env("RENDER_EXTERNAL_HOSTNAME") || "localhost", port: 443]
#
# Check `Plug.SSL` for all available options in `force_ssl`.

# No longer using prod.secret.exs - Letting
# the release system check releases.exs at runtime
