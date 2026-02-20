// lib/models/playing_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single playing card used in Blackjack.
///
/// [value] holds the Blackjack point value (Ace = 11 initially; the game
/// engine reduces it to 1 when holding both values would bust the hand).
class PlayingCard {
  final String rank;
  final String suit; // Unicode suit symbol: ♠ ♥ ♦ ♣
  final int value;

  PlayingCard(this.rank, this.suit, this.value);

  bool get isAce => rank == 'A';

  /// Full display string, e.g. "A♠" or "10♥".
  String get display => '$rank$suit';

  /// Red suits (hearts and diamonds) need a different text colour for legibility.
  bool get isRed => suit == '♥' || suit == '♦';

  Color get suitColor => isRed ? Colors.red : AppColors.primaryNavyDark;

  @override
  String toString() => '$rank$suit';
}

/// A standard 52-card deck (or multi-deck shoe) for Blackjack.
///
/// Cards are shuffled on construction and reshuffled automatically when the
/// draw index reaches the end of the shoe, simulating a continuous shuffler.
class CardDeck {
  final List<PlayingCard> _cards = [];
  int _index = 0;

  CardDeck({int numDecks = 1}) {
    _init(numDecks);
  }

  void _init(int numDecks) {
    _cards.clear();
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = ['♠', '♥', '♦', '♣'];

    for (var i = 0; i < numDecks; i++) {
      for (var suit in suits) {
        for (var rank in ranks) {
          // Aces start at 11; the game engine handles the soft/hard conversion.
          // All face cards are worth 10.
          final value = rank == 'A'
              ? 11
              : (['J', 'Q', 'K'].contains(rank) ? 10 : int.parse(rank));
          _cards.add(PlayingCard(rank, suit, value));
        }
      }
    }

    _cards.shuffle();
    _index = 0;
  }

  PlayingCard drawCard() {
    // Reshuffle in place when the shoe runs out rather than throwing an error,
    // consistent with real casino continuous-shuffler behaviour.
    if (_index >= _cards.length) _init(1);
    return _cards[_index++];
  }
}