defmodule SpadesWeb.API.V1.GameView do
  use SpadesWeb, :view

  def render("index.json", %{rooms: rooms}) do
    %{rooms: render_many(rooms, SpadesWeb.API.V1.RoomView, "room.json")}
  end
end
