// lib/models/crazy_eights_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CardSuit {
  hearts,
  diamonds,
  clubs,
  spades,
}

enum CardRank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  jack,    // Choose: skip OR reverse
  queen,   // Draw 2, stackable
  king,    // Change suit
  ace,     // Change suit & draw 4, stackable
}

class CrazyEightsCard {
  final CardSuit suit;
  final CardRank rank;
  
  CrazyEightsCard({required this.suit, required this.rank});

  // Check if card is a special action card
  bool get isJack => rank == CardRank.jack;
  bool get isQueen => rank == CardRank.queen;
  bool get isKing => rank == CardRank.king;
  bool get isAce => rank == CardRank.ace;
  
  bool get isAction => isJack || isQueen || isKing || isAce;
  bool get canChangeSuit => isKing || isAce;
  bool get isDrawCard => isQueen || isAce;
  
  // Get numeric value for number cards
  int get numericValue {
    switch (rank) {
      case CardRank.two: return 2;
      case CardRank.three: return 3;
      case CardRank.four: return 4;
      case CardRank.five: return 5;
      case CardRank.six: return 6;
      case CardRank.seven: return 7;
      case CardRank.eight: return 8;
      case CardRank.nine: return 9;
      default: return 0; // Face cards don't have numeric values
    }
  }

  // Get the display color for the card suit
  Color get displayColor {
    switch (suit) {
      case CardSuit.hearts:
        return const Color(0xFFE53935); // Red
      case CardSuit.diamonds:
        return AppColors.accentElectricBlue;
      case CardSuit.clubs:
        return AppColors.primaryNavyDark;
      case CardSuit.spades:
        return AppColors.secondaryAmber;
    }
  }

  // Get suit symbol
  String get suitSymbol {
    switch (suit) {
      case CardSuit.hearts:
        return '♥';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.clubs:
        return '♣';
      case CardSuit.spades:
        return '♠';
    }
  }

  // Get display text for the card rank
  String get rankText {
    switch (rank) {
      case CardRank.two: return '2';
      case CardRank.three: return '3';
      case CardRank.four: return '4';
      case CardRank.five: return '5';
      case CardRank.six: return '6';
      case CardRank.seven: return '7';
      case CardRank.eight: return '8';
      case CardRank.nine: return '9';
      case CardRank.jack: return 'J';
      case CardRank.queen: return 'Q';
      case CardRank.king: return 'K';
      case CardRank.ace: return 'A';
    }
  }

  // Get full display text (e.g., "A♠")
  String get displayText => '$rankText$suitSymbol';

  // Check if this card can be played on another card
  bool canPlayOn(CrazyEightsCard otherCard, CardSuit? currentChosenSuit) {
    // Kings and Aces can change suit - always playable
    if (canChangeSuit) return true;

    // If the last card was a suit-changing card, check against the chosen suit
    if (otherCard.canChangeSuit && currentChosenSuit != null) {
      return suit == currentChosenSuit;
    }

    // Match suit or rank
    return suit == otherCard.suit || rank == otherCard.rank;
  }

  // Check if two cards are identical (for jump-in rule)
  bool isIdenticalTo(CrazyEightsCard other) {
    return suit == other.suit && rank == other.rank;
  }

  @override
  String toString() => displayText;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrazyEightsCard && 
           other.suit == suit && 
           other.rank == rank;
  }

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  // For copying
  CrazyEightsCard copyWith({CardSuit? suit, CardRank? rank}) {
    return CrazyEightsCard(
      suit: suit ?? this.suit,
      rank: rank ?? this.rank,
    );
  }

  // ============================================
  // SERIALIZATION FOR MULTIPLAYER
  // ============================================
  
  // Convert server data to CrazyEightsCard
  factory CrazyEightsCard.fromMap(Map<String, dynamic> map) {
    return CrazyEightsCard(
      suit: _parseSuit(map['suit']),
      rank: _parseRank(map['rank']),
    );
  }

  // Convert CrazyEightsCard to server data
  Map<String, dynamic> toMap() {
    return {
      'suit': suit.name,
      'rank': _rankToString(rank),
    };
  }

  // Parse suit string from server
  static CardSuit _parseSuit(String suit) {
    switch (suit) {
      case 'hearts':
        return CardSuit.hearts;
      case 'diamonds':
        return CardSuit.diamonds;
      case 'clubs':
        return CardSuit.clubs;
      case 'spades':
        return CardSuit.spades;
      default:
        throw Exception('Invalid suit: $suit');
    }
  }

  // Parse rank string from server
  static CardRank _parseRank(String rank) {
    switch (rank) {
      case '2':
        return CardRank.two;
      case '3':
        return CardRank.three;
      case '4':
        return CardRank.four;
      case '5':
        return CardRank.five;
      case '6':
        return CardRank.six;
      case '7':
        return CardRank.seven;
      case '8':
        return CardRank.eight;
      case '9':
        return CardRank.nine;
      case 'jack':
        return CardRank.jack;
      case 'queen':
        return CardRank.queen;
      case 'king':
        return CardRank.king;
      case 'ace':
        return CardRank.ace;
      default:
        throw Exception('Invalid rank: $rank');
    }
  }

  // Convert rank to string for server
  String _rankToString(CardRank rank) {
    switch (rank) {
      case CardRank.two:
        return '2';
      case CardRank.three:
        return '3';
      case CardRank.four:
        return '4';
      case CardRank.five:
        return '5';
      case CardRank.six:
        return '6';
      case CardRank.seven:
        return '7';
      case CardRank.eight:
        return '8';
      case CardRank.nine:
        return '9';
      case CardRank.jack:
        return 'jack';
      case CardRank.queen:
        return 'queen';
      case CardRank.king:
        return 'king';
      case CardRank.ace:
        return 'ace';
    }
  }
}

class CrazyEightsDeck {
  final List<CrazyEightsCard> _cards = [];
  int _index = 0;

  CrazyEightsDeck() {
    _init();
  }

  void _init() {
    _cards.clear();

    // Create 2 standard 52-card decks = 104 cards total
    for (var deckNum = 0; deckNum < 2; deckNum++) {
      for (var suit in CardSuit.values) {
        for (var rank in CardRank.values) {
          _cards.add(CrazyEightsCard(suit: suit, rank: rank));
        }
      }
    }

    shuffle();
  }

  void shuffle() {
    _cards.shuffle();
    _index = 0;
  }

  CrazyEightsCard drawCard() {
    if (_index >= _cards.length) {
      // Reshuffle if deck is empty
      shuffle();
    }
    return _cards[_index++];
  }

  List<CrazyEightsCard> drawMultiple(int count) {
    final cards = <CrazyEightsCard>[];
    for (var i = 0; i < count; i++) {
      cards.add(drawCard());
    }
    return cards;
  }

  int get remainingCards => _cards.length - _index;
  
  bool get isEmpty => _index >= _cards.length;

  // Reset with cards from discard pile (keep top card)
  void resetWithDiscard(List<CrazyEightsCard> discardCards) {
    _cards.clear();
    _cards.addAll(discardCards);
    shuffle();
  }
}