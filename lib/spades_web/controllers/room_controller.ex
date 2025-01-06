defmodule SpadesWeb.RoomController do
  use SpadesWeb, :controller

  alias Spades.Rooms
  alias Spades.Rooms.Room

  # alias SpadesUtil.{NameGenerator, Slugify}
  # alias SpadesGame.GameSupervisor

  action_fallback SpadesWeb.FallbackController

  def index(conn, _params) do
    rooms = Rooms.list_rooms() # Assuming this function returns rooms with the 'is_started' field
    render(conn, "index.json", rooms: rooms)
  end


  # Create: Removed, users no longer able to create rooms by API
  # Possibly this entire controller should be removed

  def show(conn, %{"id" => id}) do
    room = Rooms.get_room!(id)
    render(conn, "show.json", room: room)
  end

  def update(conn, %{"id" => id, "room" => room_params}) do
    room = Rooms.get_room!(id)

    with {:ok, %Room{} = room} <- Rooms.update_room(room, Map.put(room_params, :status, :playing)) do
      render(conn, "show.json", room: room)
    end
  end



  def delete(conn, %{"id" => id}) do
    room = Rooms.get_room!(id)

    with {:ok, %Room{}} <- Rooms.delete_room(room) do
      send_resp(conn, :no_content, "")
    end
  end

  def join(conn, %{"id" => id, "player_id" => player_id}) do
    with {:ok, room} <- Spades.Rooms.Room.get_room!(id),
         {:ok, _} <- Spades.Rooms.Room.join_or_leave(room, player_id, "join") do
      json(conn, %{message: "Successfully joined the room."})
    else
      {:error, reason} ->
        json(conn, %{error: reason})
    end
  end
#leave
  def leave(conn, %{"id" => id, "player_id" => player_id}) do
    with {:ok, room} <- Spades.Rooms.Room.get_room!(id),
         {:ok, _} <- Spades.Rooms.Room.join_or_leave(room, player_id, "leave") do
      json(conn, %{message: "Successfully left the room."})
    else
      {:error, reason} ->
        json(conn, %{error: reason})
    end
  end
end
