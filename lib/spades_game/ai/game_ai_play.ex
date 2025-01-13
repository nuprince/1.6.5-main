defmodule SpadesGame.GameAI.Play do
  @moduledoc """
  Functions for the AI figuring out which card to play.
  Enhanced with advanced strategy while maintaining core stability.
  """
  alias SpadesGame.{Card, Deck, Game, TrickCard}
  alias SpadesGame.GameAI.PlayInfo

  # Strategy constants
  @high_card_threshold 11    # J and above
  @safe_lead_threshold 7     # Safe to lead
  @spades_danger_threshold 3 # Minimum safe spades
  @endgame_threshold 10      # When to switch to endgame strategy

  # Simple GameState to track essential info
  defmodule GameState do
    @moduledoc """
    Tracks essential game state information for strategic decisions
    """
    defstruct [
      spades_played: [],      # Track spades played
      tricks_completed: 0,    # Number of tricks played
      high_cards_played: %{}, # High cards played by suit
      current_trick_value: 0  # Value of current trick
    ]
  end

  @spec play(Game.t()) :: Card.t()
  def play(%Game{turn: turn, trick: trick} = game) when turn != nil do
    {:ok, valid_cards} = Game.valid_cards(game, turn)

    if Enum.empty?(valid_cards) do
      raise "No valid cards available to play"
    end

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

    # Build game state for strategic decisions
    game_state = build_game_state(game)

    # Select card with fallback
    selected_card = case length(trick) do
      0 -> play_pos1(info, game_state)
      1 -> play_pos2(info, game_state)
      2 -> play_pos3(info, game_state)
      3 -> play_pos4(info, game_state)
    end

    selected_card || Enum.random(valid_cards)
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

  # Build game state for strategic decisions
  defp build_game_state(game) do
    spades_played =
      game.trick
      |> Enum.filter(fn %TrickCard{card: card} -> card.suit == :s end)
      |> Enum.map(fn %TrickCard{card: card} -> card end)

    high_cards_played =
      game.trick
      |> Enum.reduce(%{s: [], h: [], d: [], c: []}, fn %TrickCard{card: card}, acc ->
        if card.rank >= @high_card_threshold do
          Map.update!(acc, card.suit, fn cards -> [card | cards] end)
        else
          acc
        end
      end)

    tricks_completed = count_completed_tricks(game)

    %GameState{
      spades_played: spades_played,
      tricks_completed: tricks_completed,
      high_cards_played: high_cards_played,
      current_trick_value: calculate_trick_value(game.trick)
    }
  end

  # Enhanced play_pos1 with advanced strategy
  @spec play_pos1(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos1(%PlayInfo{valid_cards: valid_cards, hand: hand} = info, game_state) do
    {best_card, worst_card} = empty_trick_best_worst(valid_cards)
    spades_count = count_suit(hand, :s)

    result = cond do
      info.me_nil ->
        find_optimal_nil_lead(valid_cards, game_state)

      info.partner_nil ->
        find_partner_nil_support(valid_cards, hand)

      endgame?(game_state) ->
        play_endgame_lead(valid_cards, hand, game_state)

      has_winning_sequence?(hand) ->
        find_sequence_lead(valid_cards, hand)

      spades_count <= @spades_danger_threshold ->
        find_non_spade_lead(valid_cards)

      best_card.rank == 14 ->
        best_card

      true ->
        find_midrange_lead(valid_cards) || worst_card
    end

    result || worst_card
  end

  # Enhanced play_pos2 with advanced strategy
  @spec play_pos2(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos2(%PlayInfo{valid_cards: valid_cards} = info, game_state) do
    options = card_options(info.trick, valid_cards)
    trick_suit = get_trick_suit(info.trick)

    result = cond do
      info.me_nil ->
        find_optimal_nil_follow(valid_cards, trick_suit, game_state)

      info.partner_nil ->
        find_protective_follow(valid_cards, trick_suit, game_state)

      should_win_second?(info, game_state) ->
        find_winning_second(valid_cards, trick_suit, game_state)

      true ->
        find_conservative_follow(valid_cards, trick_suit)
    end

    result || Enum.random(valid_cards)
  end

  # Enhanced play_pos3 with advanced strategy
  @spec play_pos3(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos3(%PlayInfo{valid_cards: valid_cards} = info, game_state) do
    options = card_options(info.trick, valid_cards)
    trick_suit = get_trick_suit(info.trick)

    result = cond do
      info.me_nil ->
        find_optimal_nil_follow(valid_cards, trick_suit, game_state)

      info.partner_nil ->
        find_protective_follow(valid_cards, trick_suit, game_state)

      info.partner_winning and not critical_trick?(game_state) ->
        find_conservative_follow(valid_cards, trick_suit)

      should_win_third?(info, game_state) ->
        find_winning_third(valid_cards, trick_suit, game_state)

      true ->
        first_non_nil([options.worst_winner, options.worst_loser])
    end

    result || Enum.random(valid_cards)
  end

  # Enhanced play_pos4 with advanced strategy
  @spec play_pos4(PlayInfo.t(), GameState.t()) :: Card.t()
  def play_pos4(%PlayInfo{valid_cards: valid_cards} = info, game_state) do
    options = card_options(info.trick, valid_cards)
    trick_suit = get_trick_suit(info.trick)

    result = cond do
      info.me_nil ->
        find_optimal_nil_follow(valid_cards, trick_suit, game_state)

      info.partner_winning and not info.partner_nil ->
        if should_overtake_partner?(info, game_state) do
          find_winning_fourth(valid_cards, trick_suit, game_state)
        else
          find_conservative_follow(valid_cards, trick_suit)
        end

      true ->
        find_winning_fourth(valid_cards, trick_suit, game_state) ||
        first_non_nil([options.worst_winner, options.worst_loser])
    end

    result || Enum.random(valid_cards)
  end

  # Advanced strategy helper functions
  defp find_optimal_nil_lead(cards, game_state) do
    non_spades = Enum.filter(cards, &(&1.suit != :s))
    low_cards = Enum.filter(cards, &(&1.rank <= @safe_lead_threshold))

    cond do
      !Enum.empty?(low_cards) -> Enum.min_by(low_cards, &(&1.rank))
      !Enum.empty?(non_spades) -> Enum.min_by(non_spades, &card_value/1)
      true -> Enum.min_by(cards, &card_value/1)
    end
  end

  defp find_partner_nil_support(cards, hand) do
    high_cards = Enum.filter(cards, &(&1.rank >= @high_card_threshold))

    cond do
      !Enum.empty?(high_cards) -> Enum.max_by(high_cards, &card_value/1)
      true -> find_midrange_lead(cards) || Enum.random(cards)
    end
  end

  defp has_winning_sequence?(hand) do
    hand
    |> Enum.group_by(&(&1.suit))
    |> Map.values()
    |> Enum.any?(fn suit_cards ->
      suit_cards
      |> Enum.sort_by(&(&1.rank), :desc)
      |> cards_in_sequence?()
    end)
  end

  defp cards_in_sequence?([first, second | _rest]) do
    first.rank == second.rank + 1
  end
  defp cards_in_sequence?(_), do: false

  defp find_sequence_lead(cards, hand) do
    cards
    |> Enum.filter(fn card ->
      suit_cards = Enum.filter(hand, &(&1.suit == card.suit))
      length(suit_cards) >= 2 and cards_in_sequence?(Enum.sort_by(suit_cards, &(&1.rank), :desc))
    end)
    |> Enum.max_by(&card_value/1, fn -> nil end)
  end

  defp endgame?(game_state) do
    game_state.tricks_completed >= @endgame_threshold
  end

  defp play_endgame_lead(cards, hand, game_state) do
    spades = Enum.filter(cards, &(&1.suit == :s))
    winning_spades = winning_spades?(spades, game_state.spades_played)

    cond do
      winning_spades -> Enum.max_by(spades, &(&1.rank))
      true -> find_safe_high_card(cards, game_state) || Enum.random(cards)
    end
  end

  defp winning_spades?(spades, spades_played) do
    case {spades, spades_played} do
      {[], _} -> false
      {_, []} -> true
      {my_spades, played} ->
        my_highest = Enum.max_by(my_spades, &(&1.rank)).rank
        played_highest = Enum.max_by(played, &(&1.rank)).rank
        my_highest > played_highest
    end
  end

  defp find_safe_high_card(cards, game_state) do
    cards
    |> Enum.filter(fn card ->
      high_cards_played = get_in(game_state.high_cards_played, [card.suit]) || []
      card.rank >= @high_card_threshold and length(high_cards_played) >= 2
    end)
    |> Enum.max_by(&card_value/1, fn -> nil end)
  end

  defp should_win_second?(info, game_state) do
    current_rank = List.last(info.trick).card.rank
    current_rank >= @high_card_threshold or critical_trick?(game_state)
  end

  defp should_win_third?(info, game_state) do
    !info.partner_winning and
    (critical_trick?(game_state) or current_winner_opponent?(info))
  end

  defp current_winner_opponent?(info) do
    winner_index = Game.trick_winner_index(info.trick)
    winner_index in [1, 3]  # East or West (opponents)
  end

  defp should_overtake_partner?(info, game_state) do
    critical_trick?(game_state) and
    length(game_state.spades_played) >= 8
  end

  defp critical_trick?(game_state) do
    game_state.current_trick_value >= 10 or
    game_state.tricks_completed >= @endgame_threshold
  end

  defp calculate_trick_value(trick) do
    trick
    |> Enum.map(fn %TrickCard{card: card} -> card_value(card) end)
    |> Enum.max(fn -> 0 end)
  end

  defp count_completed_tricks(game) do
    game.north.tricks_won + game.south.tricks_won +
    game.east.tricks_won + game.west.tricks_won
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

  defp find_midrange_lead(cards) do
    cards
    |> Enum.filter(&(&1.rank <= 10 and &1.rank >= 6))
    |> Enum.sort_by(&(&1.rank))
    |> List.first()
  end

  defp find_non_spade_lead(cards) do
    cards
    |> Enum.filter(&(&1.suit != :s))
    |> Enum.min_by(&card_value/1, fn -> nil end)
  end

  defp find_optimal_nil_follow(cards, trick_suit, game_state) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    cond do
      !Enum.empty?(following) ->
        Enum.min_by(following, &(&1.rank))
      true ->
        find_safe_sluff(cards, game_state)
    end
  end

  defp find_protective_follow(cards, trick_suit, game_state) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    cond do
      !Enum.empty?(following) ->
        Enum.max_by(following, &(&1.rank))
      true ->
        find_safe_sluff(cards, game_state)
    end
  end

  defp find_safe_sluff(cards, game_state) do
    non_spades = Enum.filter(cards, &(&1.suit != :s))

    cond do
      !Enum.empty?(non_spades) ->
        Enum.min_by(non_spades, &card_value/1)
      true ->
        Enum.min_by(cards, &card_value/1)
    end
  end

  defp find_conservative_follow(cards, trick_suit) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    if !Enum.empty?(following) do
      Enum.min_by(following, &(&1.rank))
    else
      find_non_spade_lead(cards) || Enum.min_by(cards, &card_value/1)
    end
  end

  defp find_winning_second(cards, trick_suit, _game_state) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))

    if !Enum.empty?(following) do
      Enum.max_by(following, &(&1.rank))
    else
      find_safe_sluff(cards, _game_state)
    end
  end

  defp find_winning_third(cards, trick_suit, game_state) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    current_winner = get_winning_card(game_state)

    cond do
      !Enum.empty?(following) and current_winner ->
        winners = Enum.filter(following, &(&1.rank > current_winner.rank))
        if !Enum.empty?(winners), do: Enum.min_by(winners, &(&1.rank))
      true ->
        find_safe_sluff(cards, game_state)
    end
  end

  defp find_winning_fourth(cards, trick_suit, game_state) do
    following = Enum.filter(cards, &(&1.suit == trick_suit))
    current_winner = get_winning_card(game_state)

    cond do
      !Enum.empty?(following) and current_winner ->
        winners = Enum.filter(following, &(&1.rank > current_winner.rank))
        if !Enum.empty?(winners), do: Enum.min_by(winners, &(&1.rank))
      true ->
        find_safe_sluff(cards, game_state)
    end
  end

  defp get_winning_card(game_state) do
    game_state.trick
    |> Enum.max_by(fn %TrickCard{card: card} -> card_value(card) end, fn -> nil end)
    |> case do
      nil -> nil
      trick_card -> trick_card.card
    end
  end

  defp get_trick_suit(trick) do
    case List.last(trick) do
      %TrickCard{card: %Card{suit: suit}} -> suit
      _ -> nil
    end
  end

  defp count_suit(hand, suit) do
    Enum.count(hand, &(&1.suit == suit))
  end

  @spec first_non_nil(list(any)) :: any
  def first_non_nil(list) do
    list
    |> Enum.filter(&(&1 != nil))
    |> List.first()
  end

  def card_value(%Card{rank: rank, suit: suit}) do
    base_value = rank * 10
    suit_bonus = case suit do
      :s -> 1000  # Spades are highest priority
      :h -> 500   # Hearts second
      :d -> 250   # Diamonds third
      :c -> 0     # Clubs lowest
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


