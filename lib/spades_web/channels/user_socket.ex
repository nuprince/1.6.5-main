defmodule SpadesWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias Spades.Users.User

  ## Channels
  # channel "room:*", SpadesWeb.RoomChannel
  # Example/Test (can/should be removed)
  channel "mytopic:*", SpadesWeb.MyTopicChannel
  # List of Games
  channel "lobby:lobby", SpadesWeb.LobbyChannel
  # Game State
  channel "room:*", SpadesWeb.RoomChannel
  # Chat Messages
  channel "chat:*", SpadesWeb.ChatChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(params, socket, _connect_info) do
    user = get_user_from_auth_token(params["token"])
     Logger.info("Socket Join")
     params |> IO.inspect(label: "UserSocket Params")
     user |> IO.inspect(label: "User from token")

    ## Let non-authenticated users still connect to websockets,
    ## but we mark their user_id as nil
    case user do
      %User{} ->
        {:ok, assign(socket, :user_id, user.id)}

      _ ->
        {:ok, assign(socket, :user_id, nil)}
    end
  end

  defp get_user_from_auth_token(token) do
    ## Warning: Hardcoded Config for Plug
    ## I don't know how to get this, because I need
    ## "conn" which doesn't exist in this context
    config = [mod: SpadesWeb.APIAuthPlug, plug: SpadesWeb.APIAuthPlug, otp_app: :spades]
    ## This APIAuthPlug probably shouldn't be hardcoded
    SpadesWeb.APIAuthPlug.fetch_from_token(config, token)
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     SpadesWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
