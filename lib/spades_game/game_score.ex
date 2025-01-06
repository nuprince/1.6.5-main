defmodule SpadesGame.GameScore do
  @moduledoc """
  Represents the score of a team.
  """

  @derive Jason.Encoder
  defstruct [
    :north_south_rounds,
    :north_south_score,
    :east_west_rounds,
    :east_west_score,
    :win_score
  ]

  use Accessible
  alias SpadesGame.{Game, GameScore, GameScoreRoundTeam}

  @type t :: %GameScore{
          north_south_rounds: list(GameScoreRoundTeam.t()),
          north_south_score: integer,
          east_west_rounds: list(GameScoreRoundTeam.t()),
          east_west_score: integer,
          win_score: integer
        }

  @spec new() :: GameScore.t()
  def new(win_score \\ 100) do
    %GameScore{
      north_south_rounds: [],
      north_south_score: 0,
      east_west_rounds: [],
      east_west_score: 0,
      win_score: win_score
    }
  end

  @spec update(GameScore.t(), Game.t()) :: GameScore.t()
  def update(score, game) do
    {ns_before_score, ns_before_bags} = get_befores(score.north_south_rounds)
    {ew_before_score, ew_before_bags} = get_befores(score.east_west_rounds)

    new_ns_round = GameScoreRoundTeam.new(ns_before_score, ns_before_bags, game.north, game.south)
    new_ew_round = GameScoreRoundTeam.new(ew_before_score, ew_before_bags, game.east, game.west)

    %GameScore{
      north_south_rounds: score.north_south_rounds ++ [new_ns_round],
      north_south_score: new_ns_round.after_score,
      east_west_rounds: score.east_west_rounds ++ [new_ew_round],
      east_west_score: new_ew_round.after_score,
      win_score: score.win_score
    }
  end

  @spec get_befores(list(GameScoreRoundTeam.t())) :: {integer, integer}
  def get_befores([]) do
    {0, 0}
  end

  def get_befores(rounds) do
    last_round = List.last(rounds)
    {last_round.after_score, last_round.after_bags}
  end

  @spec won_game?(GameScore.t()) :: boolean
  def won_game?(%GameScore{} = score) do
    above_threshold = score.north_south_score >= score.win_score || score.east_west_score >= score.win_score
    different_scores = score.north_south_score != score.east_west_score
    above_threshold && different_scores
  end

  @spec winner(GameScore.t()) :: nil | :north_south | :east_west
  def winner(%GameScore{} = score) do
    if won_game?(score) do
      if score.north_south_score > score.east_west_score do
        :north_south
      else
        :east_west
      end
    else
      nil
    end
  end
end
