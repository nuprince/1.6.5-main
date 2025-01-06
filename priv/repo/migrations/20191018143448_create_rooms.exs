defmodule Spades.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add(:name, :string)
      add :status, :string, default: "waiting"

      timestamps()
    end
  end
end
