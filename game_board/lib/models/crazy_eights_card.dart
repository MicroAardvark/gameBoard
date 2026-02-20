// lib/models/crazy_eights_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CardSuit { hearts, diamonds, clubs, spades }

/// Ranks used in this Crazy Eights variant.
///
/// Note: there is no Ten in this deck — the number cards run 2–9 and then
/// jump straight to the face cards. This is deliberate; Tens were removed
/// when the special-card ruleset was designed to avoid ambiguity with Aces.
enum CardRank {
  two, three, four, five, six, seven, eight, nine,
  jack,  // Choose: skip next player OR reverse direction.
  queen, // Draw 2, stackable with other Queens.
  king,  // Change the active suit (no draw).
  ace,   // Change the active suit AND draw 4, stackable with other Aces.
}

/// A single card in the Crazy Eights deck.
///
/// Carries all display and game-logic properties so the game engine and UI
/// components can operate on the card itself rather than carrying lookup tables.
class CrazyEightsCard {
  final CardSuit suit;
  final CardRank rank;

  const CrazyEightsCard({required this.suit, required this.rank});

  // ─── Rank queries ─────────────────────────────────────────────────────────
  bool get isJack  => rank == CardRank.jack;
  bool get isQueen => rank == CardRank.queen;
  bool get isKing  => rank == CardRank.king;
  bool get isAce   => rank == CardRank.ace;

  /// True for any card that has a special effect when played.
  bool get isAction => isJack || isQueen || isKing || isAce;

  /// True for Kings and Aces, which allow the active suit to be changed.
  bool get canChangeSuit => isKing || isAce;

  /// True for Queens (+2) and Aces (+4), which can be stacked.
  bool get isDrawCard => isQueen || isAce;

  /// Point value for number cards; returns 0 for face cards (unused in
  /// AI card selection, which uses [isAction] / specific rank checks instead).
  int get numericValue {
    switch (rank) {
      case CardRank.two:   return 2;
      case CardRank.three: return 3;
      case CardRank.four:  return 4;
      case CardRank.five:  return 5;
      case CardRank.six:   return 6;
      case CardRank.seven: return 7;
      case CardRank.eight: return 8;
      case CardRank.nine:  return 9;
      default:             return 0;
    }
  }

  // ─── Display ──────────────────────────────────────────────────────────────

  /// Each suit has a distinct colour so players can distinguish suits at a
  /// glance even on small screens. Hearts use standard red; Diamonds use
  /// electric blue; Clubs use dark navy; Spades use amber.
  Color get displayColor {
    switch (suit) {
      case CardSuit.hearts:   return const Color(0xFFE53935);
      case CardSuit.diamonds: return AppColors.accentElectricBlue;
      case CardSuit.clubs:    return AppColors.primaryNavyDark;
      case CardSuit.spades:   return AppColors.secondaryAmber;
    }
  }

  String get suitSymbol {
    switch (suit) {
      case CardSuit.hearts:   return '♥';
      case CardSuit.diamonds: return '♦';
      case CardSuit.clubs:    return '♣';
      case CardSuit.spades:   return '♠';
    }
  }

  String get rankText {
    switch (rank) {
      case CardRank.two:   return '2';
      case CardRank.three: return '3';
      case CardRank.four:  return '4';
      case CardRank.five:  return '5';
      case CardRank.six:   return '6';
      case CardRank.seven: return '7';
      case CardRank.eight: return '8';
      case CardRank.nine:  return '9';
      case CardRank.jack:  return 'J';
      case CardRank.queen: return 'Q';
      case CardRank.king:  return 'K';
      case CardRank.ace:   return 'A';
    }
  }

  /// Short display string used in status messages and debug output, e.g. "A♠".
  String get displayText => '$rankText$suitSymbol';

  // ─── Game logic ───────────────────────────────────────────────────────────

  /// Returns true if this card may legally be played on [otherCard].
  ///
  /// Kings and Aces are always playable (they set the new suit).
  /// If the last played card was a suit-changer, [currentChosenSuit] takes
  /// precedence over [otherCard]'s natural suit for matching purposes.
  /// Otherwise, standard Crazy Eights matching applies: same suit or same rank.
  bool canPlayOn(CrazyEightsCard otherCard, CardSuit? currentChosenSuit) {
    if (canChangeSuit) return true;

    if (otherCard.canChangeSuit && currentChosenSuit != null) {
      return suit == currentChosenSuit;
    }

    return suit == otherCard.suit || rank == otherCard.rank;
  }

  /// Exact match on both suit and rank, used to validate jump-in plays.
  bool isIdenticalTo(CrazyEightsCard other) => suit == other.suit && rank == other.rank;

  // ─── Object overrides ─────────────────────────────────────────────────────

  @override String   toString()                 => displayText;
  @override bool     operator ==(Object other)  => other is CrazyEightsCard && other.suit == suit && other.rank == rank;
  @override int      get hashCode               => suit.hashCode ^ rank.hashCode;

  CrazyEightsCard copyWith({CardSuit? suit, CardRank? rank}) {
    return CrazyEightsCard(suit: suit ?? this.suit, rank: rank ?? this.rank);
  }

  // ─── Serialisation (multiplayer) ──────────────────────────────────────────

  /// Deserialises a card from the Socket.IO game state payload.
  factory CrazyEightsCard.fromMap(Map<String, dynamic> map) {
    return CrazyEightsCard(
      suit: _parseSuit(map['suit'] as String),
      rank: _parseRank(map['rank']),
    );
  }

  /// Serialises the card for transmission to the Node.js server.
  /// Numbers are sent as their digit string ("2"–"9"); faces as their name.
  Map<String, dynamic> toMap() => {'suit': suit.name, 'rank': rankServerValue};

  /// The canonical rank string used in server payloads.
  ///
  /// Number cards use digit strings ("2"–"9") to match the server schema.
  /// Face cards use their lowercase name ("jack", "queen", "king", "ace").
  String get rankServerValue {
    switch (rank) {
      case CardRank.two:   return '2';
      case CardRank.three: return '3';
      case CardRank.four:  return '4';
      case CardRank.five:  return '5';
      case CardRank.six:   return '6';
      case CardRank.seven: return '7';
      case CardRank.eight: return '8';
      case CardRank.nine:  return '9';
      case CardRank.jack:  return 'jack';
      case CardRank.queen: return 'queen';
      case CardRank.king:  return 'king';
      case CardRank.ace:   return 'ace';
    }
  }

  static CardSuit _parseSuit(String suit) {
    switch (suit) {
      case 'hearts':   return CardSuit.hearts;
      case 'diamonds': return CardSuit.diamonds;
      case 'clubs':    return CardSuit.clubs;
      case 'spades':   return CardSuit.spades;
      default: throw Exception('Invalid suit: $suit');
    }
  }

  /// Accepts both the canonical server format ("6", "jack") and the legacy
  /// word format ("six", "jack") so that old client payloads don't cause
  /// parse errors during a rolling deployment.
  static CardRank _parseRank(dynamic rank) {
    switch (rank.toString().toLowerCase().trim()) {
      case '2': case 'two':   return CardRank.two;
      case '3': case 'three': return CardRank.three;
      case '4': case 'four':  return CardRank.four;
      case '5': case 'five':  return CardRank.five;
      case '6': case 'six':   return CardRank.six;
      case '7': case 'seven': return CardRank.seven;
      case '8': case 'eight': return CardRank.eight;
      case '9': case 'nine':  return CardRank.nine;
      case 'jack':  return CardRank.jack;
      case 'queen': return CardRank.queen;
      case 'king':  return CardRank.king;
      case 'ace':   return CardRank.ace;
      default: throw Exception('Invalid rank: $rank');
    }
  }
}

/// A two-deck (104-card) shoe used for single-player Crazy Eights.
///
/// Two decks are used so that a four-player game with 7 cards each (28 cards)
/// plus an opening discard leaves a comfortable draw pile before reshuffling.
/// The deck reshuffles in place when exhausted rather than throwing an error.
class CrazyEightsDeck {
  final List<CrazyEightsCard> _cards = [];
  int _index = 0;

  CrazyEightsDeck() { _init(); }

  void _init() {
    _cards.clear();
    for (var deckNum = 0; deckNum < 2; deckNum++) {
      for (var suit in CardSuit.values) {
        for (var rank in CardRank.values) {
          _cards.add(CrazyEightsCard(suit: suit, rank: rank));
        }
      }
    }
    shuffle();
  }

  void shuffle() { _cards.shuffle(); _index = 0; }

  CrazyEightsCard drawCard() {
    if (_index >= _cards.length) shuffle();
    return _cards[_index++];
  }

  List<CrazyEightsCard> drawMultiple(int count) =>
      [for (var i = 0; i < count; i++) drawCard()];

  int  get remainingCards => _cards.length - _index;
  bool get isEmpty        => _index >= _cards.length;

  /// Replenishes the shoe from [discardCards] (minus the top card, which
  /// stays on the discard pile) when the draw pile runs dry mid-game.
  void resetWithDiscard(List<CrazyEightsCard> discardCards) {
    _cards.clear();
    _cards.addAll(discardCards);
    shuffle();
  }
}