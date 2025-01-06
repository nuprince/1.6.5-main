defmodule SpadesWeb.API.V1.PlayerController do
  use SpadesWeb, :controller

  # Action to handle a player quitting the game
  @spec quit(Conn.t(), map()) :: Conn.t()
  def quit(conn, %{"game_id" => game_id, "user_id" => user_id}) do
    case Games.quit(game_id, user_id) do
      {:ok, %{"updated_game" => updated_game, "user_replaced" => user_replaced}} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: %{message: "Player successfully quit the game"},
          updated_game: updated_game,
          user_replaced: user_replaced
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{status: 400, message: reason}})
    end
  end
end
