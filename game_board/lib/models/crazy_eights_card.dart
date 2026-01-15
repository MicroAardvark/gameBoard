// lib/models/CrazyEights_card.dart
import 'package:flutter/material.dart';

enum CrazyEightsColor {
  red,
  blue,
  green,
  yellow,
  wild, // For Wild and Wild Draw Four cards
}

enum CrazyEightsValue {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  skip,
  reverse,
  drawTwo,
  wild,
  wildDrawFour,
}

class CrazyEightsCard {
  final CrazyEightsColor color;
  final CrazyEightsValue value;
  
  CrazyEightsCard({required this.color, required this.value});

  // Check if card is an action card
  bool get isAction => [
    CrazyEightsValue.skip,
    CrazyEightsValue.reverse,
    CrazyEightsValue.drawTwo,
  ].contains(value);

  // Check if card is a wild card
  bool get isWild => value == CrazyEightsValue.wild || value == CrazyEightsValue.wildDrawFour;

  // Get the display color for the card
  Color get displayColor {
    switch (color) {
      case CrazyEightsColor.red:
        return const Color(0xFFE53935);
      case CrazyEightsColor.blue:
        return const Color(0xFF1E88E5);
      case CrazyEightsColor.green:
        return const Color(0xFF43A047);
      case CrazyEightsColor.yellow:
        return const Color(0xFFFDD835);
      case CrazyEightsColor.wild:
        return Colors.black;
    }
  }

  // Get display text for the card value
  String get displayText {
    switch (value) {
      case CrazyEightsValue.zero:
        return '0';
      case CrazyEightsValue.one:
        return '1';
      case CrazyEightsValue.two:
        return '2';
      case CrazyEightsValue.three:
        return '3';
      case CrazyEightsValue.four:
        return '4';
      case CrazyEightsValue.five:
        return '5';
      case CrazyEightsValue.six:
        return '6';
      case CrazyEightsValue.seven:
        return '7';
      case CrazyEightsValue.eight:
        return '8';
      case CrazyEightsValue.nine:
        return '9';
      case CrazyEightsValue.skip:
        return '⊘';
      case CrazyEightsValue.reverse:
        return '⇄';
      case CrazyEightsValue.drawTwo:
        return '+2';
      case CrazyEightsValue.wild:
        return 'W';
      case CrazyEightsValue.wildDrawFour:
        return '+4';
    }
  }

  // Check if this card can be played on another card
  bool canPlayOn(CrazyEightsCard otherCard, CrazyEightsColor? currentWildColor) {
    // Wild cards can always be played
    if (isWild) return true;

    // If the last card was wild, check against the chosen color
    if (otherCard.isWild && currentWildColor != null) {
      return color == currentWildColor;
    }

    // Match color or value
    return color == otherCard.color || value == otherCard.value;
  }

  @override
  String toString() => '$color $value';

  // For copying/comparing
  CrazyEightsCard copyWith({CrazyEightsColor? color, CrazyEightsValue? value}) {
    return CrazyEightsCard(
      color: color ?? this.color,
      value: value ?? this.value,
    );
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

    // Add number cards (0-9)
    // One 0 per color, two of each 1-9 per color
    for (var color in [CrazyEightsColor.red, CrazyEightsColor.blue, CrazyEightsColor.green, CrazyEightsColor.yellow]) {
      // One zero per color
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.zero));

      // Two of each 1-9
      for (var i = 1; i <= 9; i++) {
        final value = CrazyEightsValue.values[i]; // one through nine
        _cards.add(CrazyEightsCard(color: color, value: value));
        _cards.add(CrazyEightsCard(color: color, value: value));
      }

      // Two of each action card per color
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.skip));
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.skip));
      
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.reverse));
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.reverse));
      
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.drawTwo));
      _cards.add(CrazyEightsCard(color: color, value: CrazyEightsValue.drawTwo));
    }

    // Add wild cards (4 of each)
    for (var i = 0; i < 4; i++) {
      _cards.add(CrazyEightsCard(color: CrazyEightsColor.wild, value: CrazyEightsValue.wild));
      _cards.add(CrazyEightsCard(color: CrazyEightsColor.wild, value: CrazyEightsValue.wildDrawFour));
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
}