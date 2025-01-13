defmodule SpadesGame.GameAI.Play do
  @moduledoc """
  Functions for the AI figuring out which card to play.
  Enhanced with improved strategic gameplay while maintaining core stability.
  """
  alias SpadesGame.{Card, Deck, Game, TrickCard}
  alias SpadesGame.GameAI.PlayInfo

  # Add strategic constants
  @high_card_threshold 11  # Consider J and above as high cards
  @safe_lead_threshold 7   # Cards below this are generally safe to lead
  @spades_danger_threshold 3  # Be cautious leading spades with less than this

  @spec play(Game.t()) :: Card.t()
  def play(%Game{turn: turn, trick: trick} = game) when turn != nil do
    {:ok, valid_cards} = Game.valid_cards(game, turn)

    info = %PlayInfo{
      hand: Game.hand(game, turn),
      valid_cards: valid_cards,
      trick: trick,
      me_nil: player_nil?(game, turn),
      partner_nil: player_nil?(game, Game.partner(turn)),
      left_nil: player_nil?(game, Game.rotate(turn)),
      right_nil: player_nil?(game, turn |> Game.partner() |> Game.rotate()),
      partner_winning: partner_winning?(game)
    }

    case length(trick) do
      0 -> play_pos1(info)
      1 -> play_pos2(info)
      2 -> play_pos3(info)
      3 -> play_pos4(info)
    end
  end

  def partner_winning?(%Game{trick: trick}) do
    winner_index = Game.trick_winner_index(trick)
    is_pos3 = length(trick) == 2
    is_pos4 = length(trick) == 3
    is_pos1_winning = winner_index == 0
    is_pos2_winning = winner_index == 1

    (is_pos3 and is_pos1_winning) or (is_pos4 and is_pos2_winning)
  end

  @spec player_nil?(Game.t(), :west | :north | :east | :south) :: boolean
  def player_nil?(game, turn) do
    game[turn].bid == 0
  end

  # Enhanced play_pos1 with better leading strategy
  @spec play_pos1(PlayInfo.t()) :: Card.t()
  def play_pos1(%PlayInfo{
        valid_cards: valid_cards,
        hand: hand,
        me_nil: me_nil,
        partner_nil: partner_nil,
        left_nil: left_nil,
        right_nil: right_nil
      }) do
    {best_card, worst_card} = empty_trick_best_worst(valid_cards)
    spades_count = count_suit(hand, :s)

    cond do
      # Nil bid strategies
      me_nil or left_nil or right_nil ->
        find_safest_lead(valid_cards)

      partner_nil ->
        find_protective_lead(valid_cards, hand)

      # Normal play strategies
      has_winning_sequence?(hand) ->
        find_sequence_lead(valid_cards)

      spades_count <= @spades_danger_threshold ->
        find_non_spade_lead(valid_cards) || worst_card

      best_card.rank == 14 ->
        # Cash an ace if we have it
        best_card

      true ->
        find_midrange_lead(valid_cards) || worst_card
    end
  end

  # Helper functions for enhanced leading strategy
  defp find_safest_lead(cards) do
    non_spades = Enum.filter(cards, &(&1.suit != :s))

    if Enum.empty?(non_spades) do
      Enum.min_by(cards, &card_value/1)
    else
      Enum.min_by(non_spades, &card_value/1)
    end
  end

  defp find_protective_lead(cards, hand) do
    high_cards = Enum.filter(cards, &(&1.rank >= @high_card_threshold))

    cond do
      !Enum.empty?(high_cards) -> Enum.max_by(high_cards, &card_value/1)
      true -> find_midrange_lead(cards)
    end
  end

  defp find_sequence_lead(cards) do
    grouped = Enum.group_by(cards, &(&1.suit))

    sequence = Enum.find(Map.values(grouped), fn suit_cards ->
      sorted = Enum.sort_by(suit_cards, &(&1.rank), :desc)
      has_sequence?(sorted)
    end)

    case sequence do
      nil -> nil
      cards -> Enum.max_by(cards, &(&1.rank))
    end
  end

  defp has_sequence?(cards) do
    cards
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [c1, c2] -> c1.rank == c2.rank + 1 end)
  end

  defp find_non_spade_lead(cards) do
    cards
    |> Enum.filter(&(&1.suit != :s))
    |> Enum.sort_by(&card_value/1, :desc)
    |> List.first()
  end

  defp find_midrange_lead(cards) do
    cards
    |> Enum.filter(&(&1.rank <= 10 and &1.rank >= 6))
    |> Enum.sort_by(&card_value/1)
    |> List.first()
  end

  # Enhanced play_pos2 with better following strategy
  @spec play_pos2(PlayInfo.t()) :: Card.t()
  def play_pos2(%PlayInfo{me_nil: me_nil, partner_nil: partner_nil, hand: hand} = info) do
    options = card_options(info.trick, info.valid_cards)
    trick_suit = List.last(info.trick).card.suit

    to_play =
      cond do
        me_nil ->
          [
            find_safest_follow(info.valid_cards, trick_suit),
            options.best_loser,
            options.worst_winner
          ]

        partner_nil ->
          [
            find_protective_follow(info.valid_cards, trick_suit, hand),
            options.best_winner,
            options.worst_loser
          ]

        should_win_trick?(info) ->
          [
            options.worst_winner,
            find_high_follow(info.valid_cards, trick_suit),
            options.best_loser
          ]

        true ->
          [
            options.worst_winner,
            options.worst_loser,
            find_midrange_follow(info.valid_cards, trick_suit)
          ]
      end

    first_non_nil(to_play ++ [Enum.random(info.valid_cards)])
  end

  defp find_safest_follow(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    if Enum.empty?(following) do
      Enum.min_by(cards, &card_value/1)
    else
      Enum.min_by(following, &(&1.rank))
    end
  end

  defp find_protective_follow(cards, trick_suit, hand) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    cond do
      Enum.empty?(following) -> find_safe_sluff(cards, hand)
      true -> Enum.max_by(following, &(&1.rank))
    end
  end

  defp find_safe_sluff(cards, hand) do
    # Prefer discarding from short suits
    suits_count = count_suits(hand)

    cards
    |> Enum.sort_by(fn card ->
      {suits_count[card.suit], -card_value(card)}
    end)
    |> List.first()
  end

  defp find_high_follow(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    if !Enum.empty?(following) do
      Enum.max_by(following, &(&1.rank))
    end
  end

  defp find_midrange_follow(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    if !Enum.empty?(following) do
      following
      |> Enum.filter(&(&1.rank <= 10 and &1.rank >= 6))
      |> Enum.sort_by(&(&1.rank))
      |> List.first()
    end
  end

  # Enhanced play_pos3 with improved strategy
  @spec play_pos3(PlayInfo.t()) :: Card.t()
  def play_pos3(
        %PlayInfo{me_nil: me_nil, partner_nil: partner_nil, partner_winning: partner_winning} = info
      ) do
    options = card_options(info.trick, info.valid_cards)
    trick_suit = List.last(info.trick).card.suit
    current_winning_rank = get_winning_rank(info.trick)

    to_play =
      cond do
        me_nil ->
          [
            find_safest_follow(info.valid_cards, trick_suit),
            options.best_loser
          ]

        partner_nil ->
          [
            find_protective_third(info.valid_cards, trick_suit, current_winning_rank),
            options.worst_winner,
            options.worst_loser
          ]

        partner_winning and not critical_trick?(info) ->
          [
            find_conservative_play(info.valid_cards, trick_suit),
            options.worst_loser
          ]

        true ->
          [
            options.worst_winner,
            find_aggressive_play(info.valid_cards, trick_suit, current_winning_rank)
          ]
      end

    first_non_nil(to_play ++ [Enum.random(info.valid_cards)])
  end

  # Enhanced play_pos4 with smarter endgame strategy
  @spec play_pos4(PlayInfo.t()) :: Card.t()
  def play_pos4(
        %PlayInfo{me_nil: me_nil, partner_winning: partner_winning, partner_nil: partner_nil} = info
      ) do
    options = card_options(info.trick, info.valid_cards)
    trick_suit = List.last(info.trick).card.suit

    to_play =
      cond do
        me_nil ->
          [
            find_safest_follow(info.valid_cards, trick_suit),
            options.best_loser
          ]

        partner_winning and not partner_nil ->
          if should_overtake_partner?(info) do
            [options.worst_winner]
          else
            [
              find_conservative_play(info.valid_cards, trick_suit),
              options.worst_loser
            ]
          end

        true ->
          [
            find_winning_play(info.valid_cards, trick_suit, info),
            options.worst_winner,
            options.worst_loser
          ]
      end

    first_non_nil(to_play ++ [Enum.random(info.valid_cards)])
  end

  # Helper functions for enhanced gameplay

  defp should_win_trick?(info) do
    current_rank = List.last(info.trick).card.rank
    current_rank >= @high_card_threshold
  end

  defp critical_trick?(info) do
    trick_value = calculate_trick_value(info.trick)
    trick_value >= 10
  end

  defp calculate_trick_value(trick) do
    trick
    |> Enum.map(fn %TrickCard{card: card} -> card_value(card) end)
    |> Enum.max(fn -> 0 end)
  end

  defp should_overtake_partner?(info) do
    current_winner = get_current_winning_card(info.trick)
    current_winner.rank <= 10 and critical_trick?(info)
  end

  defp get_current_winning_card(trick) do
    trick
    |> Enum.max_by(fn %TrickCard{card: card} -> card_value(card) end)
    |> Map.get(:card)
  end

  defp get_winning_rank(trick) do
    trick
    |> Enum.max_by(fn %TrickCard{card: card} -> card_value(card) end)
    |> Map.get(:card)
    |> Map.get(:rank)
  end

  defp find_protective_third(cards, trick_suit, current_winning_rank) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    winners = Enum.filter(following, &(&1.rank > current_winning_rank))

    cond do
      !Enum.empty?(winners) -> Enum.min_by(winners, &(&1.rank))
      !Enum.empty?(following) -> Enum.min_by(following, &(&1.rank))
      true -> find_safe_sluff(cards, [])
    end
  end

  defp find_conservative_play(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    if !Enum.empty?(following) do
      Enum.min_by(following, &(&1.rank))
    end
  end

  defp find_aggressive_play(cards, trick_suit, current_winning_rank) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    winners = Enum.filter(following, &(&1.rank > current_winning_rank))

    cond do
      !Enum.empty?(winners) -> Enum.min_by(winners, &(&1.rank))
      true -> find_safe_sluff(cards, [])
    end
  end

  defp find_winning_play(cards, trick_suit, info) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    current_winning_rank = get_winning_rank(info.trick)

    winners = Enum.filter(following, &(&1.rank > current_winning_rank))

    if !Enum.empty?(winners), do: Enum.min_by(winners, &(&1.rank))
  end

  # Utility functions

  defp count_suit(hand, suit) do
    Enum.count(hand, &(&1.suit == suit))
  end

  defp count_suits(hand) do
    Enum.reduce(hand, %{s: 0, h: 0, d: 0, c: 0}, fn card, acc ->
      Map.update(acc, card.suit, 1, &(&1 + 1))
    end)
  end

  defp has_winning_sequence?(hand) do
    hand
    |> Enum.group_by(&(&1.suit))
    |> Map.values()
    |> Enum.any?(fn suit_cards ->
      suit_cards
      |> Enum.sort_by(&(&1.rank), :desc)
      |> has_sequence?()
    end)
  end

  # Core mechanics from original (keeping these to ensure stability)
  @spec empty_trick_best_worst(Deck.t()) :: {Card.t(), Card.t()}
  def empty_trick_best_worst(valid_cards) when length(valid_cards) > 0 do
    priority_map = priority_map([])

    sorted_cards =
      valid_cards
      |> Enum.map(fn %Card{rank: rank, suit: suit} = card ->
        val = rank + priority_map[suit]
        {card, val}
      end)
      |> Enum.sort_by(fn {_card, val} -> val end)
      |> Enum.map(fn {card, _val} -> card end)

    worst_card = List.first(sorted_cards)
    best_card = List.last(sorted_cards)
    {best_card, worst_card}
  end

  @spec card_options(list(TrickCard.t()), Deck.t()) :: map
  def card_options([], _valid_cards) do
    %{
      worst_winner: nil,
      best_winner: nil,
      worst_loser: nil,
      best_loser: nil
    }
  end

  def card_options(trick, valid_cards) when length(trick) > 0 do
    priority_map = priority_map(trick)
    trick_max = trick_max(trick)

    sort_cards =
      valid_cards
      |> Enum.map(fn %Card{rank: rank, suit: suit} = card ->
        val = rank + priority_map[suit]
        {card, val}
      end)
      |> Enum.sort_by(fn {_card, val} -> val end)

    winners =
      sort_cards
      |> Enum.filter(fn {_card, val} -> val >= trick_max end)
      |> Enum.map(fn {card, _val} -> card end)

    losers =
      sort_cards
      |> Enum.filter(fn {_card, val} -> val < trick_max end)
      |> Enum.map(fn {card, _val} -> card end)

    %{
      worst_winner: List.first(winners),
      best_winner: List.last(winners),
      worst_loser: List.first(losers),
      best_loser: List.last(losers)
    }
  end

  @spec first_non_nil(list(any)) :: any
  def first_non_nil(list) when length(list) > 0 do
    list
    |> Enum.filter(fn x -> x != nil end)
    |> List.first()
  end

  # Core card value and priority functions
  def card_value(%Card{rank: rank, suit: suit}) do
    base_value = rank
    suit_bonus = case suit do
      :s -> 100  # Spades are highest priority
      :h -> 50   # Hearts second
      :d -> 25   # Diamonds third
      :c -> 0    # Clubs lowest
    end
    base_value + suit_bonus
  end

  @spec trick_max(list(TrickCard.t())) :: non_neg_integer
  def trick_max(trick) when length(trick) > 0 do
    priority_map = priority_map(trick)

    trick
    |> Enum.map(fn %TrickCard{card: %Card{rank: rank, suit: suit}} ->
      rank + priority_map[suit]
    end)
    |> Enum.max()
  end

  def trick_max([]), do: 0

  @spec priority_map(list(TrickCard.t())) :: map
  def priority_map(trick) when length(trick) > 0 do
    List.last(trick).card.suit
    |> Game.suit_priority()
  end

  def priority_map([]) do
    %{s: 200, h: 100, c: 100, d: 100}
  end
end

