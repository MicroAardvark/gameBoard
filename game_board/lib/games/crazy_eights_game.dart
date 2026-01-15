// lib/games/crazy_eights_game.dart
import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/crazy_eights_card.dart';
import '../models/user.dart';
import '../components/crazy_eights_card_component.dart';

class CrazyEightsGame extends FlameGame {
  final User user;
  
  CrazyEightsGame({required this.user});

  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerCards = 2;
  static const int layerHud = 3;
  static const int layerOverlay = 4;

  // Game state
  late CrazyEightsDeck deck;
  final List<CrazyEightsCard> discardPile = [];
  CardSuit? currentChosenSuit;  // CHANGED: from currentWildColor
  
  // Player hands
  final List<CrazyEightsCard> playerHand = [];
  final List<List<CrazyEightsCard>> aiHands = [[], [], []];
  
  // Card components
  final List<CrazyEightsCardComponent> playerCardComponents = [];
  CrazyEightsCardComponent? discardTopComponent;
  DrawPileComponent? drawPileComponent;
  CrazyEightsButton? crazyEightsButton;
  CrazyEightsButton? challengeButton;
  final List<int> aiCardCounts = [0, 0, 0];
  
  // Game flow
  int currentPlayerIndex = 0;
  bool clockwise = true;
  bool needsToDrawCard = false;
  int drawCount = 0;
  bool isDrawStacking = false;
  
  // CrazyEights calling state
  final List<bool> hasCalledCrazyEights = [false, false, false, false];
  bool canChallenge = false;
  int? challengeablePlayer;
  async_timer.Timer? challengeTimer;
  
  // Jump-in state
  bool jumpInEnabled = true;
  
  // NEW: Jack choice state
  bool isAwaitingJackChoice = false;
  CrazyEightsCard? pendingJackCard;
  
  // UI state
  CrazyEightsCardComponent? selectedCard;
  bool showSuitPicker = false;  // CHANGED: from showColorPicker
  bool showJackChoice = false;  // NEW
  bool gameOver = false;
  String? winner;

  // Adaptive sizing
  double get screenWidth => size.x;
  double get screenHeight => size.y;
  double get uiScale => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight => screenHeight * 0.34 * uiScale;  // INCREASED from 0.28
  double get cardWidth => cardHeight * 0.68;

  String statusMessage = 'Your turn! Play a card or draw.';

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    deck = CrazyEightsDeck();
    _dealInitialCards();
    _placeFirstDiscardCard();
    await _renderCards();
    _createCrazyEightsButton();
    
    debugPrint('🎮 Crazy Eights Enhanced loaded!');
  }

  void _dealInitialCards() {
    for (var i = 0; i < 7; i++) {
      playerHand.add(deck.drawCard());
      for (var j = 0; j < 3; j++) {
        aiHands[j].add(deck.drawCard());
      }
    }
    
    _sortPlayerHand();
    
    for (var i = 0; i < 3; i++) {
      aiCardCounts[i] = aiHands[i].length;
    }
  }

  void _placeFirstDiscardCard() {
    CrazyEightsCard firstCard;
    do {
      firstCard = deck.drawCard();
    } while (firstCard.isAction);  // CHANGED: no more isWild, just isAction
    
    discardPile.add(firstCard);
  }

  void _sortPlayerHand() {
    playerHand.sort((a, b) {
      // Sort by suit first, then rank
      if (a.suit.index != b.suit.index) {
        return a.suit.index.compareTo(b.suit.index);
      }
      return a.rank.index.compareTo(b.rank.index);
    });
  }

  void _createCrazyEightsButton() {
    crazyEightsButton?.removeFromParent();
    crazyEightsButton = CrazyEightsButton(
      position: Vector2(screenWidth * 0.85, screenHeight * 0.85),
      size: Vector2(screenWidth * 0.12, screenHeight * 0.08),
      text: 'CrazyEights!',
      onTap: () => _handleCrazyEightsCall(),
    )..priority = layerHud;
    add(crazyEightsButton!);
  }

  void _handleCrazyEightsCall() {
    if (playerHand.length == 1 && !hasCalledCrazyEights[0]) {
      hasCalledCrazyEights[0] = true;
      statusMessage = '🎯 Crazy Eights called!';
      debugPrint('🎯 Player called Crazy Eights!');
    } else if (playerHand.length != 1) {
      statusMessage = 'You can only call Crazy Eights with 1 card!';
    } else {
      statusMessage = 'You already called Crazy Eights!';
    }
  }

  void _checkCrazyEightsViolation(int playerIndex) {
    final hand = playerIndex == 0 ? playerHand : aiHands[playerIndex - 1];
    
    if (hand.length == 1 && !hasCalledCrazyEights[playerIndex]) {
      canChallenge = true;
      challengeablePlayer = playerIndex;
      
      if (currentPlayerIndex != 0 && playerIndex != 0) {
        _showChallengeButton();
      }
      
      if (playerIndex != 0) {
        async_timer.Future.delayed(const Duration(seconds: 2), () {
          if (canChallenge && challengeablePlayer == playerIndex) {
            _performAiChallenge();
          }
        });
      }
      
      challengeTimer?.cancel();
      challengeTimer = async_timer.Timer(const Duration(seconds: 5), () {
        canChallenge = false;
        challengeablePlayer = null;
        challengeButton?.removeFromParent();
        challengeButton = null;
      });
    }
  }

  void _showChallengeButton() {
    challengeButton?.removeFromParent();
    challengeButton = CrazyEightsButton(
      position: Vector2(screenWidth * 0.85, screenHeight * 0.73),
      size: Vector2(screenWidth * 0.12, screenHeight * 0.08),
      text: 'Challenge!',
      onTap: () => _handleChallenge(),
    )..priority = layerHud;
    add(challengeButton!);
  }

  void _handleChallenge() {
    if (canChallenge && challengeablePlayer != null) {
      final targetPlayer = challengeablePlayer!;
      debugPrint('🚨 Player $targetPlayer challenged for not calling Crazy Eights!');
      
      if (targetPlayer == 0) {
        playerHand.add(deck.drawCard());
        playerHand.add(deck.drawCard());
        _sortPlayerHand();
        statusMessage = '❌ You were challenged! Drew 2 cards.';
      } else {
        aiHands[targetPlayer - 1].add(deck.drawCard());
        aiHands[targetPlayer - 1].add(deck.drawCard());
        aiCardCounts[targetPlayer - 1] += 2;
        statusMessage = '✅ Player ${targetPlayer + 1} challenged! Drew 2 cards.';
      }
      
      _renderCards();
      canChallenge = false;
      challengeablePlayer = null;
      challengeButton?.removeFromParent();
      challengeButton = null;
    }
  }

  void _performAiChallenge() {
    if (Random().nextDouble() < 0.7) {
      _handleChallenge();
    }
  }

  Future<void> _renderCards() async {
    for (var card in playerCardComponents) {
      card.removeFromParent();
    }
    playerCardComponents.clear();
    
    discardTopComponent?.removeFromParent();
    discardTopComponent = null;
    
    drawPileComponent?.removeFromParent();
    drawPileComponent = null;

    final handSpacing = cardWidth * 0.8;
    final totalWidth = (playerHand.length - 1) * handSpacing + cardWidth;
    final startX = (screenWidth - totalWidth) / 2 + cardWidth / 2;
    final bottomPadding = 30.0;
    final cardY = screenHeight - (cardHeight / 2) - bottomPadding;

    for (var i = 0; i < playerHand.length; i++) {
      final cardX = startX + (i * handSpacing);
      
      final cardComp = CrazyEightsCardComponent(
        position: Vector2(cardX, cardY),
        size: Vector2(cardWidth, cardHeight),
        card: playerHand[i],
        onTap: (tappedCard) {
          final index = playerCardComponents.indexOf(tappedCard);
          if (index >= 0) {
            _handleCardTap(index);
          }
        },
      )..priority = layerCards + 10 + i;

      playerCardComponents.add(cardComp);
      add(cardComp);
    }

    if (discardPile.isNotEmpty) {
      final topCard = discardPile.last;
      final discardX = screenWidth / 2 + cardWidth * 0.7;
      final discardY = screenHeight / 2;
      
      discardTopComponent = CrazyEightsCardComponent(
        position: Vector2(discardX, discardY),
        size: Vector2(cardWidth, cardHeight),
        card: topCard,
        onTap: (_) => _handleDiscardPileTap(),
      )..priority = layerCards;
      
      add(discardTopComponent!);
    }

    final deckX = screenWidth / 2 - cardWidth * 0.7;
    final deckY = screenHeight / 2;
    
    drawPileComponent = DrawPileComponent(
      position: Vector2(deckX, deckY),
      size: Vector2(cardWidth, cardHeight),
      remainingCards: deck.remainingCards,
      onTap: () => _handleDrawCard(),
    )..priority = layerCards;
    
    add(drawPileComponent!);

    for (var i = 0; i < 3; i++) {
      aiCardCounts[i] = aiHands[i].length;
    }
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), bgPaint);
    
    _drawGameInfo(canvas);
    _drawAIPlayers(canvas);
    
    super.render(canvas);
    
    if (showSuitPicker) {
      _drawSuitPicker(canvas);
    }
    
    if (showJackChoice) {
      _drawJackChoice(canvas);
    }
    
    if (gameOver) {
      _drawGameOver(canvas);
    }
  }

  void _drawGameInfo(Canvas canvas) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 20 * uiScale,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 4,
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(2, 2),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: TextSpan(text: statusMessage, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: screenWidth * 0.8);

    textPainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - textPainter.width / 2,
        screenHeight * 0.05,
      ),
    );

    if (drawCount > 0) {
      final stackStyle = TextStyle(
        color: Colors.redAccent,
        fontSize: 24 * uiScale,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.7),
            offset: const Offset(2, 2),
          ),
        ],
      );
      
      final stackPainter = TextPainter(
        text: TextSpan(text: '🎴 STACK: +$drawCount', style: stackStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      stackPainter.paint(
        canvas,
        Offset(screenWidth * 0.05, screenHeight * 0.12),
      );
    }

    final directionText = clockwise ? '→ Clockwise' : '← Counter-Clockwise';
    final dirStyle = TextStyle(
      color: Colors.amber,
      fontSize: 18 * uiScale,
      fontWeight: FontWeight.bold,
    );
    
    final dirPainter = TextPainter(
      text: TextSpan(text: directionText, style: dirStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    dirPainter.paint(
      canvas,
      Offset(screenWidth * 0.72, screenHeight * 0.05),
    );

    // CHANGED: Clear chosen suit when no longer relevant
    if (currentChosenSuit != null && !discardPile.last.canChangeSuit) {
      currentChosenSuit = null;
    }
    
    // CHANGED: Show chosen suit instead of color
    if (currentChosenSuit != null) {
      final suitNames = {
        CardSuit.hearts: '♥ Hearts',
        CardSuit.diamonds: '♦ Diamonds',
        CardSuit.clubs: '♣ Clubs',
        CardSuit.spades: '♠ Spades',
      };
      
      final suitStyle = TextStyle(
        color: _getSuitColor(currentChosenSuit!),
        fontSize: 16 * uiScale,
        fontWeight: FontWeight.bold,
      );
      
      final suitPainter = TextPainter(
        text: TextSpan(text: 'Suit: ${suitNames[currentChosenSuit]}', style: suitStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      suitPainter.paint(
        canvas,
        Offset(screenWidth * 0.05, screenHeight * 0.05),
      );
    }
  }

  // CHANGED: Get suit color
  Color _getSuitColor(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:
      case CardSuit.diamonds:
        return const Color(0xFFE53935);
      case CardSuit.clubs:
      case CardSuit.spades:
        return Colors.black;
    }
  }

  void _drawAIPlayers(Canvas canvas) {
    final positions = [
      Offset(screenWidth * 0.1, screenHeight * 0.3),
      Offset(screenWidth * 0.5, screenHeight * 0.1),
      Offset(screenWidth * 0.9, screenHeight * 0.3),
    ];

    for (var i = 0; i < 3; i++) {
      final isActive = currentPlayerIndex == i + 1;
      _drawAIPlayer(canvas, positions[i], i, isActive);
    }
  }

  void _drawAIPlayer(Canvas canvas, Offset position, int aiIndex, bool isActive) {
    final name = 'Player ${aiIndex + 2}';
    final cardCount = '${aiCardCounts[aiIndex]} card${aiCardCounts[aiIndex] != 1 ? 's' : ''}';
    
    final crazyEightsStatus = hasCalledCrazyEights[aiIndex + 1] && aiCardCounts[aiIndex] == 1 ? ' 🎯CE' : '';
    
    final nameStyle = TextStyle(
      color: isActive ? Colors.amber : Colors.white,
      fontSize: 16 * uiScale,
      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      shadows: [
        Shadow(
          blurRadius: 4,
          color: Colors.black.withValues(alpha: 0.7),
          offset: const Offset(1, 1),
        ),
      ],
    );
    
    final namePainter = TextPainter(
      text: TextSpan(text: '$name\n$cardCount$crazyEightsStatus', style: nameStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    namePainter.paint(
      canvas,
      Offset(position.dx - namePainter.width / 2, position.dy),
    );

    final cardBackSize = Size(cardWidth * 0.6, cardHeight * 0.6);
    final displayCards = min(aiCardCounts[aiIndex], 5);
    
    for (var i = 0; i < displayCards; i++) {
      final cardRect = Rect.fromLTWH(
        position.dx - cardBackSize.width / 2 + (i * 5),
        position.dy + 40,
        cardBackSize.width,
        cardBackSize.height,
      );
      
      final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(8));
      final backPaint = Paint()..color = const Color(0xFF0B3A79);
      canvas.drawRRect(rrect, backPaint);
      
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5);
      canvas.drawRRect(rrect, borderPaint);
    }

    if (aiCardCounts[aiIndex] > 5) {
      final moreStyle = TextStyle(
        color: Colors.white70,
        fontSize: 12 * uiScale,
      );
      
      final morePainter = TextPainter(
        text: TextSpan(text: '+${aiCardCounts[aiIndex] - 5} more', style: moreStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      morePainter.paint(
        canvas,
        Offset(
          position.dx - morePainter.width / 2,
          position.dy + 40 + cardBackSize.height + 5,
        ),
      );
    }
  }

  // CHANGED: Suit picker instead of color picker
  void _drawSuitPicker(Canvas canvas) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final dialogWidth = screenWidth * 0.6;
    final dialogHeight = screenHeight * 0.25;  // REDUCED from 0.35
    final dialogRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenWidth / 2, screenHeight / 2),
        width: dialogWidth,
        height: dialogHeight,
      ),
      const Radius.circular(20),
    );
    
    final dialogPaint = Paint()..color = Colors.white;
    canvas.drawRRect(dialogRect, dialogPaint);
    
    final titleStyle = TextStyle(
      color: Colors.black,
      fontSize: 20 * uiScale,  // REDUCED from 24
      fontWeight: FontWeight.bold,
    );
    
    final titlePainter = TextPainter(
      text: TextSpan(text: 'Choose a Suit', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    titlePainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - titlePainter.width / 2,
        screenHeight / 2 - dialogHeight / 2 + 15,
      ),
    );
    
    // Draw 4 suit buttons in a horizontal row - CHANGED from 2x2 grid
    final buttonSize = screenWidth * 0.11;  // REDUCED from 0.15
    final totalWidth = (buttonSize * 4) + (screenWidth * 0.02 * 3);  // 4 buttons + 3 gaps
    final startX = screenWidth / 2 - totalWidth / 2;
    final buttonY = screenHeight / 2 + dialogHeight / 4;
    
    final suits = [
      {'suit': CardSuit.hearts, 'symbol': '♥', 'name': 'Hearts', 'color': const Color(0xFFE53935)},
      {'suit': CardSuit.diamonds, 'symbol': '♦', 'name': 'Diamonds', 'color': const Color(0xFFE53935)},
      {'suit': CardSuit.clubs, 'symbol': '♣', 'name': 'Clubs', 'color': Colors.black},
      {'suit': CardSuit.spades, 'symbol': '♠', 'name': 'Spades', 'color': Colors.black},
    ];
    
    for (var i = 0; i < 4; i++) {
      final x = startX + (i * (buttonSize + screenWidth * 0.02));
      
      final buttonRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize),
        const Radius.circular(12),
      );
      
      final bgPaint = Paint()..color = Colors.grey.shade200;
      canvas.drawRRect(buttonRect, bgPaint);
      
      final symbolStyle = TextStyle(
        color: suits[i]['color'] as Color,
        fontSize: buttonSize * 0.5,  // ADJUSTED for better fit
        fontWeight: FontWeight.bold,
      );
      
      final symbolPainter = TextPainter(
        text: TextSpan(text: suits[i]['symbol'] as String, style: symbolStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      symbolPainter.paint(
        canvas,
        Offset(
          x + buttonSize / 2 - symbolPainter.width / 2,
          buttonY - symbolPainter.height / 2,
        ),
      );
      
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.3);
      canvas.drawRRect(buttonRect, borderPaint);
    }
  }

  // NEW: Jack choice dialog
  void _drawJackChoice(Canvas canvas) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final dialogWidth = screenWidth * 0.65;
    final dialogHeight = screenHeight * 0.22;  // REDUCED from 0.3
    final dialogRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenWidth / 2, screenHeight / 2),
        width: dialogWidth,
        height: dialogHeight,
      ),
      const Radius.circular(20),
    );
    
    final dialogPaint = Paint()..color = Colors.white;
    canvas.drawRRect(dialogRect, dialogPaint);
    
    final titleStyle = TextStyle(
      color: Colors.black,
      fontSize: 20 * uiScale,  // REDUCED from 24
      fontWeight: FontWeight.bold,
    );
    
    final titlePainter = TextPainter(
      text: TextSpan(text: 'Choose Jack Action', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    titlePainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - titlePainter.width / 2,
        screenHeight / 2 - dialogHeight / 2 + 15,
      ),
    );
    
    // Two buttons: Skip and Reverse
    final buttonWidth = screenWidth * 0.25;  // REDUCED from 0.22
    final buttonHeight = screenHeight * 0.07;  // REDUCED from 0.08
    final spacing = screenWidth * 0.04;
    final buttonY = screenHeight / 2 + dialogHeight / 4;
    
    // Skip button
    final skipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenWidth / 2 - buttonWidth / 2 - spacing / 2, buttonY),
        width: buttonWidth,
        height: buttonHeight,
      ),
      const Radius.circular(12),
    );
    
    final skipPaint = Paint()..color = Colors.blue;
    canvas.drawRRect(skipRect, skipPaint);
    
    final skipTextPainter = TextPainter(
      text: const TextSpan(
        text: 'Skip Next',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),  // REDUCED from 18
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    skipTextPainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - buttonWidth / 2 - spacing / 2 - skipTextPainter.width / 2,
        buttonY - skipTextPainter.height / 2,
      ),
    );
    
    // Reverse button
    final reverseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenWidth / 2 + buttonWidth / 2 + spacing / 2, buttonY),
        width: buttonWidth,
        height: buttonHeight,
      ),
      const Radius.circular(12),
    );
    
    final reversePaint = Paint()..color = Colors.orange;
    canvas.drawRRect(reverseRect, reversePaint);
    
    final reverseTextPainter = TextPainter(
      text: const TextSpan(
        text: 'Reverse',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),  // REDUCED from 18
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    reverseTextPainter.paint(
      canvas,
      Offset(
        screenWidth / 2 + buttonWidth / 2 + spacing / 2 - reverseTextPainter.width / 2,
        buttonY - reverseTextPainter.height / 2,
      ),
    );
  }

  void _drawGameOver(Canvas canvas) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.8);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final resultText = winner == 'player' ? 'YOU WIN!' : 'YOU LOSE!';
    final subtitleText = winner == 'player' 
        ? '🎉 Congratulations! 🎉' 
        : 'Better luck next time!';
    
    final textStyle = TextStyle(
      color: winner == 'player' ? Colors.greenAccent : Colors.redAccent,
      fontSize: 48 * uiScale,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 10,
          color: Colors.black,
          offset: const Offset(2, 2),
        ),
      ],
    );
    
    final textPainter = TextPainter(
      text: TextSpan(text: resultText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - textPainter.width / 2,
        screenHeight / 2 - textPainter.height / 2 - 30,
      ),
    );

    final subtitleStyle = TextStyle(
      color: Colors.white,
      fontSize: 20 * uiScale,
      fontWeight: FontWeight.normal,
    );
    
    final subtitlePainter = TextPainter(
      text: TextSpan(text: subtitleText, style: subtitleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    subtitlePainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - subtitlePainter.width / 2,
        screenHeight / 2 + 20,
      ),
    );
  }

  // ============================================
  // INPUT HANDLING
  // ============================================
  
  void _handleDiscardPileTap() {
    if (gameOver || currentPlayerIndex != 0 || showSuitPicker || showJackChoice) return;
    
    if (selectedCard != null) {
      final cardIndex = playerCardComponents.indexOf(selectedCard!);
      if (cardIndex >= 0) {
        final card = playerHand[cardIndex];
        if (card.canChangeSuit) {
          // King or Ace - show suit picker
          _showSuitPicker();
        } else {
          _playCard(cardIndex, null);
        }
      }
    }
  }

  void _handleCardTap(int cardIndex) {
    if (gameOver || showSuitPicker || showJackChoice) return;
    
    final card = playerHand[cardIndex];
    debugPrint('🃏 Card clicked: ${card.displayText}');
    
    // Check for jump-in (identical card)
    if (currentPlayerIndex != 0 && jumpInEnabled) {
      final topCard = discardPile.last;
      if (card.isIdenticalTo(topCard)) {
        _performJumpIn(cardIndex);
        return;
      }
    }
    
    if (currentPlayerIndex != 0) {
      statusMessage = 'Not your turn!';
      return;
    }
    
    final topCard = discardPile.last;
    final cardComp = playerCardComponents[cardIndex];

    if (selectedCard == cardComp) {
      cardComp.setSelected(false);
      selectedCard = null;
      statusMessage = 'Card deselected. Pick another or draw.';
      return;
    }

    // Allow stacking draw cards
    if (drawCount > 0 && _canStackDrawCard(card)) {
      if (selectedCard != null) {
        selectedCard!.setSelected(false);
      }
      selectedCard = cardComp;
      cardComp.setSelected(true);
      statusMessage = 'Stack +${card.isQueen ? '2' : '4'}! Click discard to play.';
      return;
    }

    if (!card.canPlayOn(topCard, currentChosenSuit) && drawCount == 0) {
      statusMessage = 'Cannot play that card! Match suit or rank.';
      return;
    }

    if (selectedCard != null) {
      selectedCard!.setSelected(false);
    }

    selectedCard = cardComp;
    cardComp.setSelected(true);
    
    if (card.canChangeSuit) {
      statusMessage = '${card.rankText} selected! Click discard pile to choose suit.';
    } else {
      statusMessage = 'Click the discard pile to play ${card.displayText}';
    }
  }

  // CHANGED: Check if card can stack (Queens with Queens, Aces with Aces)
  bool _canStackDrawCard(CrazyEightsCard card) {
    if (drawCount == 0) return false;
    final topCard = discardPile.last;
    
    // Queens stack with Queens
    if (topCard.isQueen && card.isQueen) {
      return true;
    }
    
    // Aces stack with Aces
    if (topCard.isAce && card.isAce) {
      return true;
    }
    
    return false;
  }

  void _performJumpIn(int cardIndex) {
    debugPrint('⚡ JUMP-IN! Player playing out of turn!');
    
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);
    
    statusMessage = '⚡ JUMP-IN! You played ${card.displayText}!';
    
    if (playerHand.length == 1) {
      hasCalledCrazyEights[0] = false;
    }
    
    currentPlayerIndex = 0;
    
    // Handle Jack choice for jump-in
    if (card.isJack) {
      pendingJackCard = card;
      showJackChoice = true;
      statusMessage = '⚡ JUMP-IN! Choose Jack action...';
      return;
    }
    
    _handleCardAction(card);
    _renderCards();
    
    if (playerHand.isEmpty) {
      _endGame('player');
      return;
    }
    
    _checkCrazyEightsViolation(0);
    
    async_timer.Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) {
        _nextTurn();
      }
    });
  }

  void _showSuitPicker() {
    showSuitPicker = true;
    statusMessage = 'Choose a suit!';
  }

  void _handleSuitPickerTap(Offset position) {
    if (!showSuitPicker) return;
    
    final buttonSize = screenWidth * 0.11;
    final totalWidth = (buttonSize * 4) + (screenWidth * 0.02 * 3);
    final startX = screenWidth / 2 - totalWidth / 2;
    final dialogHeight = screenHeight * 0.25;
    final buttonY = screenHeight / 2 + dialogHeight / 4;
    
    final suits = [CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs, CardSuit.spades];
    
    for (var i = 0; i < 4; i++) {
      final x = startX + (i * (buttonSize + screenWidth * 0.02));
      final buttonRect = Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize);

      if (buttonRect.contains(position)) {
        if (selectedCard != null) {
          final cardIndex = playerCardComponents.indexOf(selectedCard!);
          if (cardIndex >= 0) {
            _playCard(cardIndex, suits[i]);
          }
        }
        showSuitPicker = false;
        selectedCard = null;
        return;
      }
    }
  }

  // NEW: Handle Jack choice dialog tap
  void _handleJackChoiceTap(Offset position) {
    if (!showJackChoice) return;
    
    final buttonWidth = screenWidth * 0.25;
    final buttonHeight = screenHeight * 0.07;
    final spacing = screenWidth * 0.04;
    final dialogHeight = screenHeight * 0.22;
    final buttonY = screenHeight / 2 + dialogHeight / 4;
    
    // Skip button
    final skipRect = Rect.fromCenter(
      center: Offset(screenWidth / 2 - buttonWidth / 2 - spacing / 2, buttonY),
      width: buttonWidth,
      height: buttonHeight,
    );
    
    // Reverse button
    final reverseRect = Rect.fromCenter(
      center: Offset(screenWidth / 2 + buttonWidth / 2 + spacing / 2, buttonY),
      width: buttonWidth,
      height: buttonHeight,
    );
    
    if (skipRect.contains(position)) {
      _executeJackChoice('skip');
    } else if (reverseRect.contains(position)) {
      _executeJackChoice('reverse');
    }
  }

  void _executeJackChoice(String choice) {
    showJackChoice = false;
    isAwaitingJackChoice = false;
    
    if (choice == 'skip') {
      statusMessage += ' → Skipped next player!';
      _skipNextPlayer();
    } else {
      clockwise = !clockwise;
      statusMessage += ' → Direction reversed!';
    }
    
    pendingJackCard = null;
    
    // Continue game flow
    async_timer.Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) {
        _nextTurn();
      }
    });
  }

  void _handleDrawCard() {
    if (gameOver || currentPlayerIndex != 0 || showSuitPicker || showJackChoice) return;
    
    if (selectedCard != null) {
      selectedCard!.setSelected(false);
      selectedCard = null;
    }
    
    if (drawCount > 0) {
      for (var i = 0; i < drawCount; i++) {
        playerHand.add(deck.drawCard());
      }
      _sortPlayerHand();
      _renderCards();
      
      statusMessage = 'Drew $drawCount penalty card(s).';
      drawCount = 0;
      isDrawStacking = false;
      
      _nextTurn();
    } else {
      final drawnCard = deck.drawCard();
      playerHand.add(drawnCard);
      _sortPlayerHand();
      _renderCards();
      
      final topCard = discardPile.last;
      if (drawnCard.canPlayOn(topCard, currentChosenSuit)) {
        statusMessage = 'Drew a card - you can play it or end turn.';
      } else {
        statusMessage = 'Drew a card - turn ending...';
        async_timer.Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver && currentPlayerIndex == 0) {
            _nextTurn();
          }
        });
      }
    }
  }

  // ============================================
  // GAME LOGIC
  // ============================================

  void _playCard(int cardIndex, CardSuit? chosenSuit) {
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);
    
    if (selectedCard != null) {
      selectedCard!.setSelected(false);
      selectedCard = null;
    }
    
    if (card.canChangeSuit) {
      currentChosenSuit = chosenSuit;
      statusMessage = 'You played ${card.displayText}!';
    } else {
      currentChosenSuit = null;
      statusMessage = 'You played ${card.displayText}!';
    }

    if (playerHand.length != 1) {
      hasCalledCrazyEights[0] = false;
    }

    // Handle Jack choice
    if (card.isJack) {
      pendingJackCard = card;
      showJackChoice = true;
      _renderCards();
      return;
    }

    _handleCardAction(card);
    _renderCards();

    if (playerHand.isEmpty) {
      _endGame('player');
      return;
    }

    _checkCrazyEightsViolation(0);

    async_timer.Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) {
        _nextTurn();
      }
    });
  }

  // CHANGED: Updated for playing card actions
  void _handleCardAction(CrazyEightsCard card) {
    if (card.isJack) {
      // Jack choice handled separately via dialog
      return;
    } else if (card.isQueen) {
      // Queen: Draw 2, stackable
      drawCount += 2;
      isDrawStacking = true;
      statusMessage += ' +2 added! Total: +$drawCount';
    } else if (card.isKing) {
      // King: Change suit only (no draw)
      // Suit already chosen
    } else if (card.isAce) {
      // Ace: Change suit + Draw 4, stackable
      drawCount += 4;
      isDrawStacking = true;
      statusMessage += ' +4 added! Total: +$drawCount';
    }
  }

  void _skipNextPlayer() {
    _advanceTurn();
  }

  void _nextTurn() {
    _advanceTurn();
    
    if (currentPlayerIndex == 0) {
      statusMessage = 'Your turn! Play a card or draw.';
    } else {
      statusMessage = 'Player ${currentPlayerIndex + 1}\'s turn...';
      _aiTakeTurn();
    }
  }

  void _advanceTurn() {
    if (clockwise) {
      currentPlayerIndex = (currentPlayerIndex + 1) % 4;
    } else {
      currentPlayerIndex = (currentPlayerIndex - 1);
      if (currentPlayerIndex < 0) currentPlayerIndex = 3;
    }
  }

  // ============================================
  // AI LOGIC
  // ============================================

  void _aiTakeTurn() {
    async_timer.Future.delayed(const Duration(milliseconds: 1500), () {
      if (gameOver) return;

      final aiIndex = currentPlayerIndex - 1;
      final aiHand = aiHands[aiIndex];
      final topCard = discardPile.last;

      // AI calls Crazy Eights when down to 2 cards
      if (aiHand.length == 2 && !hasCalledCrazyEights[currentPlayerIndex]) {
        hasCalledCrazyEights[currentPlayerIndex] = true;
        debugPrint('🎯 AI Player ${currentPlayerIndex + 1} called Crazy Eights!');
      }

      if (drawCount > 0) {
        // Check if AI can stack
        final stackableCards = <int>[];
        for (var i = 0; i < aiHand.length; i++) {
          if (_canStackDrawCard(aiHand[i])) {
            stackableCards.add(i);
          }
        }
        
        if (stackableCards.isNotEmpty && Random().nextDouble() < 0.8) {
          final cardIndex = stackableCards[0];
          final card = aiHand.removeAt(cardIndex);
          discardPile.add(card);
          aiCardCounts[aiIndex] = aiHand.length;
          
          if (card.canChangeSuit) {
            currentChosenSuit = _aiChooseSuit(aiHand);
          }
          
          drawCount += card.isQueen ? 2 : 4;
          statusMessage = 'Player ${currentPlayerIndex + 1} stacked! Total: +$drawCount';
          
          _renderCards();
          
          if (aiHand.isEmpty) {
            _endGame('ai${aiIndex + 1}');
            return;
          }
          
          _checkCrazyEightsViolation(currentPlayerIndex);
          
          async_timer.Future.delayed(const Duration(milliseconds: 800), () {
            if (!gameOver) _nextTurn();
          });
          return;
        } else {
          for (var i = 0; i < drawCount; i++) {
            aiHand.add(deck.drawCard());
          }
          aiCardCounts[aiIndex] = aiHand.length;
          statusMessage = 'Player ${currentPlayerIndex + 1} drew $drawCount penalty card(s).';
          drawCount = 0;
          isDrawStacking = false;
          
          async_timer.Future.delayed(const Duration(milliseconds: 800), () {
            if (!gameOver) _nextTurn();
          });
          return;
        }
      }

      final playableCards = <int>[];
      for (var i = 0; i < aiHand.length; i++) {
        if (aiHand[i].canPlayOn(topCard, currentChosenSuit)) {
          playableCards.add(i);
        }
      }

      if (playableCards.isEmpty) {
        aiHand.add(deck.drawCard());
        aiCardCounts[aiIndex] = aiHand.length;
        statusMessage = 'Player ${currentPlayerIndex + 1} drew a card.';
        
        async_timer.Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver) _nextTurn();
        });
        return;
      }

      final cardIndex = _aiChooseCard(playableCards, aiHand);
      final card = aiHand.removeAt(cardIndex);
      discardPile.add(card);
      aiCardCounts[aiIndex] = aiHand.length;

      if (card.canChangeSuit) {
        currentChosenSuit = _aiChooseSuit(aiHand);
        final suitNames = {
          CardSuit.hearts: 'Hearts',
          CardSuit.diamonds: 'Diamonds',
          CardSuit.clubs: 'Clubs',
          CardSuit.spades: 'Spades',
        };
        statusMessage = 'Player ${currentPlayerIndex + 1} played ${card.displayText} (chose ${suitNames[currentChosenSuit]})';
      } else {
        currentChosenSuit = null;
        statusMessage = 'Player ${currentPlayerIndex + 1} played ${card.displayText}';
      }

      if (aiHand.length != 1) {
        hasCalledCrazyEights[currentPlayerIndex] = false;
      }

      // Handle Jack choice for AI
      if (card.isJack) {
        final choice = _aiChooseJackAction();
        if (choice == 'skip') {
          statusMessage += ' (skip)';
          _skipNextPlayer();
        } else {
          statusMessage += ' (reverse)';
          clockwise = !clockwise;
        }
      } else {
        _handleCardAction(card);
      }

      if (aiHand.isEmpty) {
        _endGame('ai${aiIndex + 1}');
        return;
      }

      _renderCards();
      _checkCrazyEightsViolation(currentPlayerIndex);
      
      async_timer.Future.delayed(const Duration(milliseconds: 800), () {
        if (!gameOver) _nextTurn();
      });
    });
  }

  int _aiChooseCard(List<int> playableCards, List<CrazyEightsCard> hand) {
    var bestIndex = playableCards[0];
    var bestCard = hand[playableCards[0]];

    for (var index in playableCards) {
      final card = hand[index];
      
      // Prioritize Aces (change suit + draw 4)
      if (card.isAce) {
        return index;
      }
      
      // Then Queens (draw 2)
      if (card.isQueen && !bestCard.isAce) {
        bestIndex = index;
        bestCard = card;
        continue;
      }
      
      // Then Jacks (skip/reverse)
      if (card.isJack && !bestCard.isQueen && !bestCard.isAce) {
        bestIndex = index;
        bestCard = card;
        continue;
      }
      
      // Then Kings (change suit)
      if (card.isKing && !bestCard.isAction) {
        bestIndex = index;
        bestCard = card;
      }
      
      // Finally number cards - play highest
      if (!card.isAction && !bestCard.isAction && card.numericValue > bestCard.numericValue) {
        bestIndex = index;
        bestCard = card;
      }
    }

    return bestIndex;
  }

  // NEW: AI chooses Jack action
  String _aiChooseJackAction() {
    // If only 2 players, skip and reverse do the same thing
    if (aiHands.length <= 1) {
      return Random().nextBool() ? 'skip' : 'reverse';
    }
    
    // Get next player's card count
    int nextPlayerIndex = clockwise ? (currentPlayerIndex + 1) % 4 : (currentPlayerIndex - 1 + 4) % 4;
    int nextPlayerCards = nextPlayerIndex == 0 
        ? playerHand.length 
        : aiHands[nextPlayerIndex - 1].length;
    
    // If next player has few cards, prefer to skip them
    if (nextPlayerCards <= 2) {
      return 'skip';
    }
    
    // Otherwise random
    return Random().nextBool() ? 'skip' : 'reverse';
  }

  // CHANGED: AI chooses suit instead of color
  CardSuit _aiChooseSuit(List<CrazyEightsCard> hand) {
    final suitCounts = {
      CardSuit.hearts: 0,
      CardSuit.diamonds: 0,
      CardSuit.clubs: 0,
      CardSuit.spades: 0,
    };

    for (var card in hand) {
      if (!card.canChangeSuit) {
        suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      }
    }

    var maxSuit = CardSuit.hearts;
    var maxCount = 0;
    suitCounts.forEach((suit, count) {
      if (count > maxCount) {
        maxCount = count;
        maxSuit = suit;
      }
    });

    return maxSuit;
  }

  void _endGame(String winnerName) {
    gameOver = true;
    winner = winnerName == 'player' ? 'player' : 'ai';
    statusMessage = winner == 'player' ? 'YOU WIN!' : 'You lose!';
    
    challengeTimer?.cancel();
    
    debugPrint('Game Over! Winner: $winner');
  }

  @override
  void onTapDown(TapDownInfo info) {
    final position = info.eventPosition.global.toOffset();
    
    if (showSuitPicker) {
      _handleSuitPickerTap(position);
    } else if (showJackChoice) {
      _handleJackChoiceTap(position);
    }
  }
}

// ============================================
// Draw Pile Component
// ============================================
class DrawPileComponent extends PositionComponent with TapCallbacks {
  final VoidCallback onTap;
  final int remainingCards;

  DrawPileComponent({
    required Vector2 position,
    required Vector2 size,
    required this.onTap,
    required this.remainingCards,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    
    final backPaint = Paint()..color = const Color(0xFF0B3A79);
    canvas.drawRRect(rrect, backPaint);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DRAW\n$remainingCards',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.y * 0.1,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}

// ============================================
// CrazyEights Button Component
// ============================================
class CrazyEightsButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onTap;
  bool isPressed = false;

  CrazyEightsButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    required this.onTap,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    
    final buttonPaint = Paint()..color = isPressed ? Colors.red.shade700 : Colors.red;
    canvas.drawRRect(rrect, buttonPaint);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  void onTapDown(TapDownEvent event) {
    isPressed = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    isPressed = false;
    onTap();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    isPressed = false;
  }
}