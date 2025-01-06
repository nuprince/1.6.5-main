defmodule Spades.Repo.Migrations.AddIsStartedToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :is_started, :boolean, default: false
    end
  end
end
