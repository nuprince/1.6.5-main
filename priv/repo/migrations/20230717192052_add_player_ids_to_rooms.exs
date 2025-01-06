defmodule Spades.Repo.Migrations.AddPlayerIdsToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :player_ids, {:array, :integer}, default: []
    end
  end
end
