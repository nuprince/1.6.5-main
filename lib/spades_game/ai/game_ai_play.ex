defmodule SpadesGame.GameAI.Play do
  @moduledoc """
  Functions for the AI figuring out which card to play.
  """
  alias SpadesGame.{Card, Deck, Game, TrickCard}
  alias SpadesGame.GameAI.PlayInfo

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

  # Enhanced play_pos1 with smarter lead strategy
  @spec play_pos1(PlayInfo.t()) :: Card.t()
  def play_pos1(%PlayInfo{
        hand: hand,
        valid_cards: valid_cards,
        me_nil: me_nil,
        partner_nil: partner_nil,
        left_nil: left_nil,
        right_nil: right_nil
      }) do
    {best_card, worst_card} = empty_trick_best_worst(valid_cards)

    cond do
      me_nil ->
        find_safest_card(valid_cards)
      
      partner_nil ->
        find_strongest_lead(valid_cards, hand)
      
      left_nil or right_nil ->
        find_nil_breaking_card(valid_cards)
      
      has_winning_sequence?(valid_cards) ->
        lead_from_sequence(valid_cards)
        
      should_lead_trump?(valid_cards, hand) ->
        find_best_spade(valid_cards)
        
      true ->
        lead_standard_card(valid_cards, hand)
    end
  end

  # New helper functions for improved lead play
  defp find_safest_card(cards) do
    non_face_cards = Enum.filter(cards, fn %Card{rank: rank} -> rank < 11 end)
    if Enum.empty?(non_face_cards), do: List.first(cards), else: List.first(non_face_cards)
  end

  defp find_strongest_lead(cards, hand) do
    spades = Enum.filter(cards, fn %Card{suit: suit} -> suit == :s end)
    if !Enum.empty?(spades), do: Enum.max_by(spades, & &1.rank), else: Enum.max_by(cards, & &1.rank)
  end

  defp find_nil_breaking_card(cards) do
    high_cards = Enum.filter(cards, fn %Card{rank: rank} -> rank >= 12 end)
    if !Enum.empty?(high_cards), do: Enum.max_by(high_cards, & &1.rank), else: Enum.max_by(cards, & &1.rank)
  end

  defp has_winning_sequence?(cards) do
    suits = Enum.group_by(cards, & &1.suit)
    Enum.any?(suits, fn {_suit, suit_cards} ->
      ranks = Enum.map(suit_cards, & &1.rank) |> Enum.sort(:desc)
      length(ranks) >= 2 and hd(ranks) - Enum.at(ranks, 1) == 1
    end)
  end

  defp lead_from_sequence(cards) do
    suits = Enum.group_by(cards, & &1.suit)
    {_suit, sequence} = 
      Enum.find(suits, fn {_suit, suit_cards} ->
        ranks = Enum.map(suit_cards, & &1.rank) |> Enum.sort(:desc)
        length(ranks) >= 2 and hd(ranks) - Enum.at(ranks, 1) == 1
      end)
    Enum.max_by(sequence, & &1.rank)
  end

  defp should_lead_trump?(cards, hand) do
    spades = Enum.filter(cards, fn %Card{suit: suit} -> suit == :s end)
    non_spades = Enum.filter(hand, fn %Card{suit: suit} -> suit != :s end)
    !Enum.empty?(spades) and length(non_spades) < 4
  end

  defp find_best_spade(cards) do
    spades = Enum.filter(cards, fn %Card{suit: suit} -> suit == :s end)
    if !Enum.empty?(spades), do: Enum.max_by(spades, & &1.rank), else: Enum.random(cards)
  end

  defp lead_standard_card(cards, hand) do
    suit_lengths = Enum.group_by(hand, & &1.suit) |> Map.new(fn {k, v} -> {k, length(v)} end)
    best_suit = Enum.max_by(Map.keys(suit_lengths), fn suit -> suit_lengths[suit] end)
    suit_cards = Enum.filter(cards, fn %Card{suit: suit} -> suit == best_suit end)
    
    if !Enum.empty?(suit_cards) do
      sorted = Enum.sort_by(suit_cards, & &1.rank, :desc)
      case length(sorted) do
        1 -> hd(sorted)
        2 -> hd(sorted)  # Lead high from doubleton
        _ -> Enum.at(sorted, 1)  # Lead second highest from 3+
      end
    else
      Enum.random(cards)
    end
  end

  @spec play_pos2(PlayInfo.t()) :: Card.t()
  def play_pos2(%PlayInfo{hand: hand, me_nil: me_nil, partner_nil: partner_nil} = info) do
    options = card_options(info.trick, info.valid_cards)
    trick_suit = List.last(info.trick).card.suit

    to_play = cond do
      me_nil ->
        find_safest_follow(info.valid_cards, trick_suit)
      
      partner_nil ->
        if can_win_cheaply?(options, trick_suit), do: options.worst_winner, else: options.best_winner
        
      should_win_trick?(info) ->
        options.worst_winner || options.best_loser
        
      true ->
        options.worst_loser || options.worst_winner
    end

    to_play || Enum.random(info.valid_cards)
  end

  defp can_win_cheaply?(options, trick_suit) do
    case options do
      %{worst_winner: %Card{suit: suit, rank: rank}} ->
        suit == trick_suit and rank <= 12
      _ -> false
    end
  end

  defp should_win_trick?(info) do
    trick_suit = List.last(info.trick).card.suit
    trick_rank = List.last(info.trick).card.rank
    trick_suit == :s or (trick_rank >= 12 and !info.partner_nil)
  end

  defp find_safest_follow(cards, trick_suit) do
    matching = Enum.filter(cards, fn %Card{suit: suit} -> suit == trick_suit end)
    if !Enum.empty?(matching) do
      Enum.min_by(matching, & &1.rank)
    else
      Enum.min_by(cards, & &1.rank)
    end
  end

  @spec play_pos3(PlayInfo.t()) :: Card.t()
  def play_pos3(%PlayInfo{me_nil: me_nil, partner_nil: partner_nil, partner_winning: partner_winning} = info) do
    options = card_options(info.trick, info.valid_cards)

    to_play = cond do
      me_nil ->
        find_safest_follow(info.valid_cards, List.last(info.trick).card.suit)
        
      partner_nil ->
        if partner_winning, do: options.worst_loser, else: options.best_winner
        
      partner_winning ->
        options.worst_loser
        
      true ->
        if should_win_trick?(info), do: options.worst_winner, else: options.best_loser
    end

    to_play || Enum.random(info.valid_cards)
  end

  @spec play_pos4(PlayInfo.t()) :: Card.t()
  def play_pos4(%PlayInfo{me_nil: me_nil, partner_winning: partner_winning, partner_nil: partner_nil} = info) do
    options = card_options(info.trick, info.valid_cards)
    trick_value = trick_max(info.trick)

    to_play = cond do
      me_nil ->
        find_safest_follow(info.valid_cards, List.last(info.trick).card.suit)
        
      partner_winning and not partner_nil ->
        if should_overtake_partner?(info, trick_value), do: options.worst_winner, else: options.worst_loser
        
      must_win_trick?(info) ->
        options.best_winner || options.best_loser
        
      true ->
        if can_win_cheaply?(options, List.last(info.trick).card.suit), do: options.worst_winner, else: options.worst_loser
    end

    to_play || Enum.random(info.valid_cards)
  end

  defp should_overtake_partner?(info, trick_value) do
    has_high_cards = Enum.any?(info.valid_cards, fn %Card{rank: rank} -> rank >= 13 end)
    trick_has_spades = Enum.any?(info.trick, fn %TrickCard{card: %Card{suit: suit}} -> suit == :s end)
    has_high_cards and trick_has_spades and trick_value < 213  # Ace of spades value
  end

  defp must_win_trick?(info) do
    trick_has_spades = Enum.any?(info.trick, fn %TrickCard{card: %Card{suit: suit}} -> suit == :s end)
    high_trick = Enum.any?(info.trick, fn %TrickCard{card: %Card{rank: rank}} -> rank >= 13 end)
    trick_has_spades or high_trick
  end

  # Rest of the helper functions remain the same...
  @spec first_non_nil(list(any)) :: any
  def first_non_nil(list) when length(list) > 0 do
    list
    |> Enum.filter(fn x -> x != nil end)
    |> List.first()
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
end
