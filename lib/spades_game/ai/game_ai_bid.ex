defmodule SpadesGame.GameAI.Bid do
  @moduledoc """
  Functions for determining a bid.
  """
  alias SpadesGame.{Card, Deck}

  @spec bid(Deck.t(), nil | integer) :: integer
  def bid(hand, partner_bid) do
    soft_bid = soft_bid(hand)
    hard_bid = hard_bid(hand)

    if should_nil?(hand, partner_bid) do
      0
    else
      soft_bid
      |> pick_bid(hard_bid, partner_bid)
      |> bag_adjust(partner_bid)
      |> adjust_for_distribution(hand)
      |> clamp_bid()
    end
  end

  defp adjust_for_distribution(bid, hand) do
    void_bonus = count_voids(hand) * 0.5
    singleton_bonus = count_singletons(hand) * 0.25
    doubleton_bonus = count_doubletons(hand) * 0.15
    
    total_adjustment = void_bonus + singleton_bonus + doubleton_bonus
    bid + round(total_adjustment)
  end

  defp count_voids(hand) do
    [:h, :d, :c, :s]
    |> Enum.count(fn suit -> suit_count(hand, suit) == 0 end)
  end

  defp count_singletons(hand) do
    [:h, :d, :c, :s]
    |> Enum.count(fn suit -> suit_count(hand, suit) == 1 end)
  end

  defp count_doubletons(hand) do
    [:h, :d, :c, :s]
    |> Enum.count(fn suit -> suit_count(hand, suit) == 2 end)
  end

  @spec pick_bid(integer, integer, nil | integer) :: integer
  def pick_bid(soft_bid, hard_bid, partner_bid) do
    cond do
      partner_bid != nil and partner_bid >= 7 -> hard_bid
      partner_bid != nil and partner_bid <= 2 -> max(soft_bid + 1, hard_bid)
      true -> soft_bid
    end
  end

  @spec bag_adjust(integer, nil | integer) :: integer
  def bag_adjust(bid, partner_bid) do
    if partner_bid != nil and bid + partner_bid >= 12 and bid >= 1 do
      max(11 - partner_bid, 1)
    else
      bid
    end
  end

  @spec clamp_bid(integer) :: integer
  def clamp_bid(bid) when bid < 1, do: 1
  def clamp_bid(bid) when bid > 7, do: 7
  def clamp_bid(bid), do: bid

  def should_nil?(hand, partner_bid) do
    partner_bid_ok = partner_bid == nil or partner_bid >= 4
    hard_bid_ok = hard_bid(hand) == 0
    soft_bid_ok = soft_bid(hand) <= 3
    spade_count_ok = Deck.count_suit(hand, :s) <= 3
    no_aces = Deck.count_rank(hand, 14) == 0
    no_kings = Deck.count_rank(hand, 13) == 0
    good_distribution = count_singletons(hand) + count_voids(hand) >= 2

    [partner_bid_ok, hard_bid_ok, soft_bid_ok, spade_count_ok, no_aces, no_kings, good_distribution]
    |> Enum.all?(& &1)
  end

  @spec hard_bid(Deck.t()) :: integer
  def hard_bid(hand) do
    spades = hand |> Enum.filter(fn %Card{suit: suit} -> suit == :s end)
    high_spades = spades |> Enum.filter(fn %Card{rank: rank} -> rank >= 10 end)
    
    consecutive_count = count_consecutive_high_spades(high_spades)
    remaining_count = count_remaining_high_spades(high_spades)
    
    consecutive_count + div(remaining_count, 2)
  end

  defp count_consecutive_high_spades(spades) do
    ranks = spades 
            |> Enum.map(& &1.rank) 
            |> Enum.sort(:desc)

    ranks
    |> Enum.reduce({0, nil}, fn rank, {count, prev} ->
      cond do
        prev == nil and rank == 14 -> {1, rank}
        prev != nil and rank == prev - 1 -> {count + 1, rank}
        true -> {count, nil}
      end
    end)
    |> elem(0)
  end

  defp count_remaining_high_spades(spades) do
    spades
    |> Enum.count(fn %Card{rank: rank} -> rank >= 10 end)
  end

  @spec soft_bid(Deck.t()) :: integer
  def soft_bid(hand) do
    bid =
      hard_bid(hand) + 
      low_spade_points(hand) + 
      offsuit_high_card_points(hand, :d) +
      offsuit_high_card_points(hand, :c) + 
      offsuit_high_card_points(hand, :h)

    (bid + 1.0)
    |> round()
  end

  @spec low_spade_points(Deck.t()) :: integer
  def low_spade_points(hand) do
    low_spades = hand
    |> Enum.filter(fn %Card{rank: rank, suit: suit} -> 
      suit == :s and rank < 10 
    end)
    
    count = length(low_spades)
    sequence_bonus = count_consecutive_low_spades(low_spades)
    
    base_points = (Float.ceil(count / 2.0) - 0.2)
    total_points = base_points + sequence_bonus
    
    max(0, trunc(total_points))
  end

  defp count_consecutive_low_spades(spades) do
    ranks = spades 
            |> Enum.map(& &1.rank) 
            |> Enum.sort(:desc)

    case length(ranks) do
      0 -> 0
      1 -> 0
      _ -> 
        consecutive = ranks
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [a, b] -> a - b == 1 end)
        consecutive * 0.25
    end
  end

  def high_card_flags(hand, suit) do
    hand_suit = hand |> Enum.filter(fn %Card{suit: card_suit} -> card_suit == suit end)

    has_ace =
      hand_suit
      |> Enum.any?(fn %Card{rank: rank} -> rank == 14 end)

    has_king =
      hand_suit
      |> Enum.any?(fn %Card{rank: rank} -> rank == 13 end)

    has_queen =
      hand_suit
      |> Enum.any?(fn %Card{rank: rank} -> rank == 12 end)

    has_jack =
      hand_suit
      |> Enum.any?(fn %Card{rank: rank} -> rank == 11 end)

    [has_ace, has_king, has_queen, has_jack]
  end

  def suit_count(hand, suit) do
    hand
    |> Enum.filter(fn %Card{suit: card_suit} -> card_suit == suit end)
    |> Enum.count()
  end

  @spec offsuit_high_card_points(Deck.t(), :h | :d | :c) :: float
  def offsuit_high_card_points(hand, suit) do
    count = suit_count(hand, suit)
    [has_ace, has_king, has_queen, has_jack] = high_card_flags(hand, suit)

    cond do
      has_ace and has_king ->
        ak_offsuit_hcp(count)

      has_ace and has_queen ->
        aq_offsuit_hcp(count)

      has_king and has_queen and has_jack ->
        kqj_offsuit_hcp(count)

      has_king and has_queen ->
        kq_offsuit_hcp(count)

      has_ace ->
        a_offsuit_hcp(count)

      has_king ->
        k_offsuit_hcp(count)

      has_queen and has_jack ->
        qj_offsuit_hcp(count)

      has_queen ->
        q_offsuit_hcp(count)

      true ->
        0.0
    end
  end

  defp ak_offsuit_hcp(count) do
    cond do
      count == 2 -> 2.5
      count == 3 -> 2.2
      count == 4 -> 1.8
      count == 5 -> 1.5
      count >= 6 -> 1.0
    end
  end

  defp aq_offsuit_hcp(count) do
    cond do
      count == 2 -> 2.0
      count == 3 -> 1.8
      count == 4 -> 1.5
      count == 5 -> 1.2
      count >= 6 -> 0.8
    end
  end

  defp kqj_offsuit_hcp(count) do
    cond do
      count == 3 -> 2.0
      count == 4 -> 1.7
      count >= 5 -> 1.3
    end
  end

  defp kq_offsuit_hcp(count) do
    cond do
      count == 2 -> 1.6
      count == 3 -> 1.4
      count == 4 -> 1.1
      count == 5 -> 0.8
      count >= 6 -> 0.5
    end
  end

  defp qj_offsuit_hcp(count) do
    cond do
      count == 2 -> 1.0
      count == 3 -> 0.8
      count >= 4 -> 0.5
    end
  end

  defp a_offsuit_hcp(count) do
    cond do
      count == 1 -> 1.2
      count == 2 -> 1.1
      count == 3 -> 1.0
      count == 4 -> 0.9
      count == 5 -> 0.7
      count == 6 -> 0.5
      count >= 7 -> 0.3
    end
  end

  defp k_offsuit_hcp(count) do
    cond do
      count == 1 -> 0.3
      count == 2 -> 0.8
      count == 3 -> 0.7
      count == 4 -> 0.5
      count >= 5 -> 0.2
    end
  end

  defp q_offsuit_hcp(count) do
    cond do
      count == 1 -> 0.2
      count == 2 -> 0.5
      count == 3 -> 0.4
      count >= 4 -> 0.1
    end
  end
end
