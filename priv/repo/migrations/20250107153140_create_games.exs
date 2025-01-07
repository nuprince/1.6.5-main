defmodule Spades.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :is_started, :boolean, default: false
      timestamps()
    end
  end
end
