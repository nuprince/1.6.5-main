defmodule Spades.Rooms.Room do
  @moduledoc """
  Represents a room where people join and play a game.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias SpadesUtil.Slugify

  # Automatically convert to JSON when broadcasting %Room{}
  # Objects over channel messages
  @derive {Jason.Encoder, only: [:id, :name, :slug, :west, :east, :south, :north]}

  schema "rooms" do
    field :is_started, :boolean, default: false # New field

    field :name, :string
    field :slug, :string
    field :west, :integer
    field :east, :integer
    field :south, :integer
    field :north, :integer

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :is_started]) # Add status here

    |> validate_required([:name])
    |> put_slug()
  end

  def put_slug(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{name: name}} ->
        put_change(changeset, :slug, Slugify.slugify(name))

      _ ->
        changeset
    end
  end
end
