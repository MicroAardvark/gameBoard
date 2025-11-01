// lib/models/uno_card.dart
import 'package:flutter/material.dart';

enum UnoColor {
  red,
  blue,
  green,
  yellow,
  wild, // For Wild and Wild Draw Four cards
}

enum UnoValue {
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

class UnoCard {
  final UnoColor color;
  final UnoValue value;
  
  UnoCard({required this.color, required this.value});

  // Check if card is an action card
  bool get isAction => [
    UnoValue.skip,
    UnoValue.reverse,
    UnoValue.drawTwo,
  ].contains(value);

  // Check if card is a wild card
  bool get isWild => value == UnoValue.wild || value == UnoValue.wildDrawFour;

  // Get the display color for the card
  Color get displayColor {
    switch (color) {
      case UnoColor.red:
        return const Color(0xFFE53935);
      case UnoColor.blue:
        return const Color(0xFF1E88E5);
      case UnoColor.green:
        return const Color(0xFF43A047);
      case UnoColor.yellow:
        return const Color(0xFFFDD835);
      case UnoColor.wild:
        return Colors.black;
    }
  }

  // Get display text for the card value
  String get displayText {
    switch (value) {
      case UnoValue.zero:
        return '0';
      case UnoValue.one:
        return '1';
      case UnoValue.two:
        return '2';
      case UnoValue.three:
        return '3';
      case UnoValue.four:
        return '4';
      case UnoValue.five:
        return '5';
      case UnoValue.six:
        return '6';
      case UnoValue.seven:
        return '7';
      case UnoValue.eight:
        return '8';
      case UnoValue.nine:
        return '9';
      case UnoValue.skip:
        return '⊘';
      case UnoValue.reverse:
        return '⇄';
      case UnoValue.drawTwo:
        return '+2';
      case UnoValue.wild:
        return 'W';
      case UnoValue.wildDrawFour:
        return '+4';
    }
  }

  // Check if this card can be played on another card
  bool canPlayOn(UnoCard otherCard, UnoColor? currentWildColor) {
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
  UnoCard copyWith({UnoColor? color, UnoValue? value}) {
    return UnoCard(
      color: color ?? this.color,
      value: value ?? this.value,
    );
  }
}

class UnoDeck {
  final List<UnoCard> _cards = [];
  int _index = 0;

  UnoDeck() {
    _init();
  }

  void _init() {
    _cards.clear();

    // Add number cards (0-9)
    // One 0 per color, two of each 1-9 per color
    for (var color in [UnoColor.red, UnoColor.blue, UnoColor.green, UnoColor.yellow]) {
      // One zero per color
      _cards.add(UnoCard(color: color, value: UnoValue.zero));

      // Two of each 1-9
      for (var i = 1; i <= 9; i++) {
        final value = UnoValue.values[i]; // one through nine
        _cards.add(UnoCard(color: color, value: value));
        _cards.add(UnoCard(color: color, value: value));
      }

      // Two of each action card per color
      _cards.add(UnoCard(color: color, value: UnoValue.skip));
      _cards.add(UnoCard(color: color, value: UnoValue.skip));
      
      _cards.add(UnoCard(color: color, value: UnoValue.reverse));
      _cards.add(UnoCard(color: color, value: UnoValue.reverse));
      
      _cards.add(UnoCard(color: color, value: UnoValue.drawTwo));
      _cards.add(UnoCard(color: color, value: UnoValue.drawTwo));
    }

    // Add wild cards (4 of each)
    for (var i = 0; i < 4; i++) {
      _cards.add(UnoCard(color: UnoColor.wild, value: UnoValue.wild));
      _cards.add(UnoCard(color: UnoColor.wild, value: UnoValue.wildDrawFour));
    }

    shuffle();
  }

  void shuffle() {
    _cards.shuffle();
    _index = 0;
  }

  UnoCard drawCard() {
    if (_index >= _cards.length) {
      // Reshuffle if deck is empty
      shuffle();
    }
    return _cards[_index++];
  }

  List<UnoCard> drawMultiple(int count) {
    final cards = <UnoCard>[];
    for (var i = 0; i < count; i++) {
      cards.add(drawCard());
    }
    return cards;
  }

  int get remainingCards => _cards.length - _index;
  
  bool get isEmpty => _index >= _cards.length;
}