defmodule Spades.Repo.Migrations.Started do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :started, :boolean, default: false
    end
  end
end
