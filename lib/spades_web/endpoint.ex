defmodule SpadesWeb.Endpoint do
 use Phoenix.Endpoint, otp_app: :spades

 socket "/socket", SpadesWeb.UserSocket,
   websocket: true,
   longpoll: false

 plug Plug.Static,
   at: "/",
   from: :spades, 
   gzip: false,
   only: ~w(css fonts images js favicon.ico robots.txt)

 if code_reloading? do
   socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
   plug Phoenix.LiveReloader
   plug Phoenix.CodeReloader
 end

 plug Plug.RequestId
 plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

 plug Plug.Parsers,
   parsers: [:urlencoded, :multipart, :json],
   pass: ["*/*"],
   json_decoder: Phoenix.json_library()

 plug Plug.MethodOverride
 plug Plug.Head

 plug Plug.Session,
   store: :cookie,
   key: "_spades_key", 
   signing_salt: "4mzmXX6h"

 plug CORSPlug, origin: [
   "http://localhost:3000",
   "http://prospades.vercel.app",
 ]

 plug SpadesWeb.Router
end
