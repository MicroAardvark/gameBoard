import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlayingCard {
  final String rank;
  final String suit;
  final int value;

  PlayingCard(this.rank, this.suit, this.value);

  bool get isAce => rank == 'A';
  
  // Added getters for card_component.dart
  String get display => '$rank$suit';
  bool get isRed => (suit == '♥' || suit == '♦');
  Color get suitColor => isRed ? Colors.red : AppColors.primaryNavyDark;

  @override
  String toString() => '$rank$suit';
}

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
          int value;
          if (rank == 'A') {
            value = 11;
          } else if (['J', 'Q', 'K'].contains(rank)) {
            value = 10;
          } else {
            value = int.parse(rank);
          }
          _cards.add(PlayingCard(rank, suit, value));
        }
      }
    }
    _cards.shuffle();
    _index = 0;
  }

  PlayingCard drawCard() {
    if (_index >= _cards.length) {
      _init(1);
    }
    return _cards[_index++];
  }
}