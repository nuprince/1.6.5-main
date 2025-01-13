defmodule SpadesGame.GameAI.Play do
  @moduledoc """
  Functions for the AI figuring out which card to play.
  Enhanced with master-level strategies.
  """
  alias SpadesGame.{Card, Deck, Game, TrickCard}
  alias SpadesGame.GameAI.PlayInfo

  defmodule GameState do
    @moduledoc """
    Tracks game state for informed decision making
    """
    defstruct [
      spades_played: [],       # Track spades played
      tricks_won: %{},         # Tricks won by each player
      nil_bids: %{},           # Track nil bids
      high_cards_played: %{},  # Track high cards (A,K,Q) played by suit
      void_suits: %{}          # Track which players might be void
    ]
  end

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

    game_state = build_game_state(game)

    case length(trick) do
      0 -> play_pos1(info, game_state)
      1 -> play_pos2(info, game_state)
      2 -> play_pos3(info, game_state)
      3 -> play_pos4(info, game_state)
    end
  end

  defp build_game_state(game) do
    @type game_state :: %GameState{
      spades_played: list(Card.t()),
      tricks_won: %{optional(atom()) => integer()},
      nil_bids: %{optional(atom()) => boolean()},
      high_cards_played: %{optional(atom()) => list(integer())},
      void_suits: %{optional(atom()) => list(atom())}
    }
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

  defp track_spades_played(game) do
    game.trick
    |> Enum.filter(fn %TrickCard{card: %Card{suit: suit}} -> suit == :s end)
    |> Enum.map(fn %TrickCard{card: card} -> card end)
  end

  defp count_tricks_won(game) do
    %{
      north: game.north.tricks_won,
      south: game.south.tricks_won,
      east: game.east.tricks_won,
      west: game.west.tricks_won
    }
  end

  defp get_nil_bids(game) do
    %{
      north: game.north.bid == 0,
      south: game.south.bid == 0,
      east: game.east.bid == 0,
      west: game.west.bid == 0
    }
  end

  defp track_high_cards(game) do
    trick_cards = Enum.map(game.trick, & &1.card)

    initial_map = %{
      s: [],  # spades
      h: [],  # hearts
      d: [],  # diamonds
      c: []   # clubs
    }

    Enum.reduce(trick_cards, initial_map, fn %Card{rank: rank, suit: suit}, acc ->
      if rank >= 12 do  # Track Ace(14), King(13), Queen(12)
        Map.update!(acc, suit, fn cards -> [rank | cards] end)
      else
        acc
      end
    end)
  end

  defp track_void_suits(game) do
    players = [:north, :south, :east, :west]

    initial_map = Enum.reduce(players, %{}, fn player, acc ->
      Map.put(acc, player, [])
    end)

    analyze_trick_history(game.trick, initial_map)
  end

  defp analyze_trick_history(trick_history, void_map) do
    Enum.reduce(trick_history, void_map, fn trick_card, acc ->
      %TrickCard{card: %Card{suit: played_suit}, seat: player} = trick_card
      led_suit = get_led_suit(trick_history)

      if played_suit != led_suit do
        Map.update!(acc, player, fn voids ->
          if led_suit not in voids, do: [led_suit | voids], else: voids
        end)
      else
        acc
      end
    end)
  end

  defp get_led_suit(trick_history) when length(trick_history) > 0 do
    List.last(trick_history).card.suit
  end
  defp get_led_suit(_), do: nil

  # Position-specific play logic
  @spec play_pos1(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos1(%PlayInfo{hand: hand, valid_cards: cards} = info, game_state) do
    cond do
      info.me_nil ->
        find_optimal_nil_lead(cards, game_state)

      info.partner_nil ->
        find_partner_nil_support(cards, game_state)

      endgame?(info, game_state) ->
        play_endgame_lead(cards, hand, game_state)

      should_lead_trump?(hand, game_state) ->
        lead_trump_strategically(cards, game_state)

      has_establishment_potential?(hand) ->
        lead_for_establishment(cards, hand, game_state)

      true ->
        lead_standard(cards, hand, game_state)
    end
  end

  @spec play_pos2(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos2(%PlayInfo{valid_cards: cards} = info, game_state) do
    trick_suit = List.last(info.trick).card.suit
    current_rank = List.last(info.trick).card.rank

    cond do
      info.me_nil ->
        play_lowest_valid(cards, trick_suit)

      info.partner_nil ->
        play_to_help_nil(cards, trick_suit, current_rank, game_state)

      should_win_second?(info, current_rank, game_state) ->
        play_winning_second(cards, trick_suit, current_rank)

      true ->
        play_passively(cards, trick_suit)
    end
  end

  @spec play_pos3(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos3(%PlayInfo{valid_cards: cards} = info, game_state) do
    trick_suit = List.last(info.trick).card.suit

    cond do
      info.me_nil ->
        play_lowest_valid(cards, trick_suit)

      info.partner_nil ->
        play_to_protect_nil(cards, info, game_state)

      info.partner_winning and not critical_trick?(info, game_state) ->
        play_passively(cards, trick_suit)

      should_win_third?(info, game_state) ->
        play_winning_third(cards, info, game_state)

      true ->
        play_passively(cards, trick_suit)
    end
  end

  @spec play_pos4(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos4(%PlayInfo{valid_cards: cards} = info, game_state) do
    trick_suit = List.last(info.trick).card.suit

    cond do
      info.me_nil ->
        play_lowest_valid(cards, trick_suit)

      info.partner_winning and not info.partner_nil ->
        handle_partner_winning_fourth(cards, trick_suit, info, game_state)

      should_win_fourth?(info, game_state) ->
        play_winning_fourth(cards, info, game_state)

      true ->
        play_lowest_valid(cards, trick_suit)
    end
  end

  # Helper functions
  defp endgame?(info, game_state) do
    total_tricks = Enum.sum(Map.values(game_state.tricks_won))
    total_tricks >= 10
  end

  defp should_lead_trump?(hand, game_state) do
    spades = get_spades(hand)
    remaining_spades = 13 - length(game_state.spades_played)
    length(spades) > 0 and remaining_spades >= 3
  end

  defp get_spades(cards) do
    Enum.filter(cards, &(&1.suit == :s))
  end

  defp has_establishment_potential?(hand) do
    suits = Enum.group_by(hand, & &1.suit)
    Enum.any?(suits, fn {suit, cards} ->
      suit != :s and length(cards) >= 4 and has_high_cards?(cards)
    end)
  end

  defp has_high_cards?(cards) do
    Enum.any?(cards, &(&1.rank >= 12))
  end

  defp lead_trump_strategically(cards, game_state) do
    spades = get_spades(cards)
    if !Enum.empty?(spades) do
      if length(game_state.spades_played) <= 6 do
        Enum.max_by(spades, &(&1.rank))  # Lead high early
      else
        Enum.min_by(spades, &(&1.rank))  # Lead low late
      end
    else
      Enum.random(cards)
    end
  end

  defp lead_for_establishment(cards, hand, game_state) do
    establishable_suit = find_establishable_suit(hand, game_state)
    suit_cards = Enum.filter(cards, &(&1.suit == establishable_suit))

    if !Enum.empty?(suit_cards) do
      Enum.max_by(suit_cards, &(&1.rank))
    else
      Enum.random(cards)
    end
  end

  defp find_establishable_suit(hand, game_state) do
    suits = Enum.group_by(hand, & &1.suit)

    {suit, _} = Enum.max_by(suits, fn {suit, cards} ->
      if suit == :s, do: -1,
      else: establishment_value(cards, game_state)
    end)

    suit
  end

  defp establishment_value(cards, game_state) do
    length(cards) +
    Enum.count(cards, &(&1.rank >= 12)) * 2 -
    length(game_state.high_cards_played[hd(cards).suit] || [])
  end

  defp find_optimal_nil_lead(cards, game_state) do
    safe_cards = get_safe_cards(cards, game_state)
    lowest = Enum.min_by(safe_cards, &card_value/1)
    fallback = Enum.min_by(cards, &card_value/1)
    lowest || fallback
  end

  defp get_safe_cards(cards, game_state) do
    high_cards_played = game_state.high_cards_played

    Enum.filter(cards, fn card ->
      is_safe_card?(card, high_cards_played)
    end)
  end

  defp is_safe_card?(card, high_cards_played) do
    suit_high_cards = high_cards_played[card.suit] || []
    higher_cards = Enum.count(suit_high_cards, fn rank -> rank > card.rank end)

    higher_cards >= 2 or card.rank <= 7
  end

  defp find_partner_nil_support(cards, game_state) do
    high_cards = Enum.filter(cards, &(&1.rank >= 12))
    best_high = Enum.max_by(high_cards, &card_value/1)
    fallback = Enum.max_by(cards, &card_value/1)
    best_high || fallback
  end

  defp play_endgame_lead(cards, hand, game_state) do
    cond do
      winning_spades_left?(hand, game_state) ->
        play_highest_spade(cards)

      safe_high_card_available?(cards, game_state) ->
        play_safe_high_card(cards, game_state)

      true ->
        play_defensive_endgame(cards, game_state)
    end
  end

  defp winning_spades_left?(hand, game_state) do
    spades = Enum.filter(hand, fn card -> card.suit == :s end)
    highest_played = highest_spade_played(game_state.spades_played)

    Enum.any?(spades, fn card -> card.rank > highest_played end)
  end

  defp highest_spade_played(spades_played) do
    if Enum.empty?(spades_played), do: 0,
    else: Enum.max_by(spades_played, & &1.rank).rank
  end

  defp play_highest_spade(cards) do
    spades = get_spades(cards)
    if !Enum.empty?(spades), do: Enum.max_by(spades, &(&1.rank)), else: Enum.random(cards)
  end

  defp safe_high_card_available?(cards, game_state) do
    high_cards = Enum.filter(cards, &(&1.rank >= 12))
    !Enum.empty?(high_cards) and
      Enum.any?(high_cards, fn card -> is_safe_high_card?(card, game_state) end)
  end

  defp play_safe_high_card(cards, game_state) do
    high_cards = Enum.filter(cards, &(&1.rank >= 12))
    safe_cards = Enum.filter(high_cards, &is_safe_high_card?(&1, game_state))
    Enum.max_by(safe_cards, &card_value/1)
  end

  defp is_safe_high_card?(card, game_state) do
    higher_played = game_state.high_cards_played[card.suit] || []
    length(higher_played) >= 2
  end

  defp play_defensive_endgame(cards, game_state) do
    lowest = Enum.min_by(cards, &card_value/1)
    highest = Enum.max_by(cards, &card_value/1)

    if can_cost_trick?(highest, game_state), do: highest, else: lowest
  end

  defp lead_standard(cards, hand, game_state) do
    if should_lead_high?(game_state) do
      Enum.max_by(cards, &card_value/1)
    else
      mid_value_card(cards)
    end
  end

  defp should_lead_high?(game_state) do
    total_tricks = Enum.sum(Map.values(game_state.tricks_won))
    total_tricks >= 8
  end

  defp mid_value_card(cards) do
    sorted = Enum.sort_by(cards, &card_value/1)
    mid_index = div(length(sorted), 2)
    Enum.at(sorted, mid_index)
  end

  defp card_value(%Card{rank: rank, suit: suit}) do
    base_value = rank
    suit_bonus = if suit == :s, do: 100, else: 0
    base_value + suit_bonus
  end

  defp can_cost_trick?(card, game_state) do
    high_cards_played = game_state.high_cards_played[card.suit] || []
    card.rank >= 12 and length(high_cards_played) <= 1
  end

  # Position-specific play helpers
  defp play_lowest_valid(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    if !Enum.empty?(following),
      do: Enum.min_by(following, &(&1.rank)),
      else: Enum.min_by(cards, &(&1.rank))
  end

  defp play_to_help_nil(cards, trick_suit, current_rank, game_state) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    winners = Enum.filter(following, &(&1.rank > current_rank))

    cond do
      !Enum.empty?(winners) -> Enum.min_by(winners, &(&1.rank))
      !Enum.empty?(following) -> Enum.min_by(following, &(&1.rank))
      can_trump_safely?(cards, trick_suit, game_state) -> get_safe_trump(cards, game_state)
      true -> Enum.min_by(cards, &(&1.rank))
    end
  end

  defp should_win_second?(info, current_rank, game_state) do
    current_rank >= 12 or
    critical_trick?(info, game_state)
  end

  defp play_winning_second(cards, trick_suit, current_rank) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    winners = Enum.filter(following, &(&1.rank > current_rank))
    spades = get_spades(cards)

    cond do
      !Enum.empty?(winners) -> Enum.min_by(winners, &(&1.rank))
      !Enum.empty?(following) -> Enum.min_by(following, &(&1.rank))
      !Enum.empty?(spades) -> Enum.min_by(spades, &(&1.rank))
      true -> Enum.min_by(cards, &(&1.rank))
    end
  end

  defp play_passively(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    if !Enum.empty?(following),
      do: Enum.min_by(following, &(&1.rank)),
      else: discard_optimal(cards)
  end

  defp discard_optimal(cards) do
    non_spades = Enum.filter(cards, &(&1.suit != :s))
    if !Enum.empty?(non_spades),
      do: Enum.max_by(non_spades, &(&1.rank)),
      else: Enum.min_by(cards, &(&1.rank))
  end

  defp play_to_protect_nil(cards, info, game_state) do
    if info.partner_winning,
      do: play_passively(cards, List.last(info.trick).card.suit),
      else: play_winning_third(cards, info, game_state)
  end

  defp should_win_third?(info, game_state) do
    !info.partner_winning and
    (critical_trick?(info, game_state) or current_winner_opponent?(info))
  end

  defp current_winner_opponent?(info) do
    winner_seat = Game.trick_winner_index(info.trick)
    winner_seat in [1, 3]  # East or West (opponents)
  end

  defp play_winning_third(cards, info, game_state) do
    trick_suit = List.last(info.trick).card.suit
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    current_winner = get_current_winning_card(info.trick)

    cond do
      can_win_with_following?(following, current_winner) ->
        win_with_following(following, current_winner)
      can_trump_safely?(cards, trick_suit, game_state) ->
        get_safe_trump(cards, game_state)
      true ->
        play_passively(cards, trick_suit)
    end
  end

  defp handle_partner_winning_fourth(cards, trick_suit, info, game_state) do
    if should_overtake_partner?(info, game_state),
      do: play_winning_fourth(cards, info, game_state),
      else: play_passively(cards, trick_suit)
  end

  defp should_win_fourth?(info, game_state) do
    !info.partner_winning and critical_trick?(info, game_state)
  end

  defp play_winning_fourth(cards, info, game_state) do
    trick_suit = List.last(info.trick).card.suit
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    current_winner = get_current_winning_card(info.trick)

    cond do
      can_win_with_following?(following, current_winner) ->
        win_with_following(following, current_winner)
      can_trump_safely?(cards, trick_suit, game_state) ->
        get_safe_trump(cards, game_state)
      true ->
        play_passively(cards, trick_suit)
    end
  end

  defp get_current_winning_card(trick) do
    trick
    |> Enum.max_by(fn %TrickCard{card: card} -> card_value(card) end)
    |> Map.get(:card)
  end

  defp can_win_with_following?(following, current_winner) do
    !Enum.empty?(following) and
    Enum.any?(following, &(&1.rank > current_winner.rank))
  end

  defp win_with_following(following, current_winner) do
    winners = Enum.filter(following, &(&1.rank > current_winner.rank))
    Enum.min_by(winners, &(&1.rank))
  end

  defp should_overtake_partner?(info, game_state) do
    critical_trick?(info, game_state) and
    length(game_state.spades_played) >= 8
  end

  defp critical_trick?(info, game_state) do
    trick_value = calculate_trick_value(info.trick)
    total_tricks = Enum.sum(Map.values(game_state.tricks_won))

    trick_value >= 10 or total_tricks >= 10
  end

  defp calculate_trick_value(trick) do
    trick
    |> Enum.map(fn %TrickCard{card: card} -> card_value(card) end)
    |> Enum.max(fn -> 0 end)
  end

  defp can_trump_safely?(cards, trick_suit, game_state) do
    spades = get_spades(cards)
    !Enum.empty?(spades) and trick_suit != :s and
      length(game_state.spades_played) <= 8
  end

  defp get_safe_trump(cards, game_state) do
    spades = get_spades(cards)
    highest_played = highest_spade_played(game_state.spades_played)

    safe_spades = Enum.filter(spades, &(&1.rank > highest_played))
    if !Enum.empty?(safe_spades),
      do: Enum.min_by(safe_spades, &(&1.rank)),
      else: Enum.min_by(spades, &(&1.rank))
  end
end
