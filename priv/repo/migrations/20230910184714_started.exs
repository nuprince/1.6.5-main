defmodule Spades.Repo.Migrations.Started do
  use Ecto.Migration

  def change do
    # Create games table first
    create table(:games) do
      add :is_started, :boolean, default: false
      timestamps()
    end
  end
end
