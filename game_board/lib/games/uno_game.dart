// lib/games/uno_game.dart
import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/uno_card.dart';
import '../models/user.dart';
import '../components/uno_card_component.dart';

class UnoGame extends FlameGame {
  final User user;
  
  UnoGame({required this.user});

  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerCards = 2;
  static const int layerHud = 3;
  static const int layerOverlay = 4;

  // Game state
  late UnoDeck deck;
  final List<UnoCard> discardPile = [];
  UnoColor? currentWildColor;
  
  // Player hands
  final List<UnoCard> playerHand = [];
  final List<List<UnoCard>> aiHands = [[], [], []];
  
  // Card components
  final List<UnoCardComponent> playerCardComponents = [];
  UnoCardComponent? discardTopComponent;
  DrawPileComponent? drawPileComponent;
  UnoButton? unoButton;
  UnoButton? challengeButton;
  final List<int> aiCardCounts = [0, 0, 0];
  
  // Game flow
  int currentPlayerIndex = 0;
  bool clockwise = true;
  bool needsToDrawCard = false;
  int drawCount = 0;
  bool isDrawStacking = false;
  
  // NEW: UNO calling state
  final List<bool> hasCalledUno = [false, false, false, false];
  bool canChallenge = false;
  int? challengeablePlayer;
  async_timer.Timer? challengeTimer;
  
  // NEW: Jump-in state
  bool jumpInEnabled = true;
  
  // UI state
  UnoCardComponent? selectedCard;
  bool showColorPicker = false;
  bool gameOver = false;
  String? winner;

  // Adaptive sizing
  double get screenWidth => size.x;
  double get screenHeight => size.y;
  double get uiScale => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight => screenHeight * 0.28 * uiScale;
  double get cardWidth => cardHeight * 0.68;

  String statusMessage = 'Your turn! Play a card or draw.';

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    deck = UnoDeck();
    _dealInitialCards();
    _placeFirstDiscardCard();
    await _renderCards();
    _createUnoButton();
    
    debugPrint('🎮 UNO Game loaded with advanced rules!');
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
    UnoCard firstCard;
    do {
      firstCard = deck.drawCard();
    } while (firstCard.isAction || firstCard.isWild);
    
    discardPile.add(firstCard);
  }

  void _sortPlayerHand() {
    playerHand.sort((a, b) {
      if (a.color.index != b.color.index) {
        return a.color.index.compareTo(b.color.index);
      }
      return a.value.index.compareTo(b.value.index);
    });
  }

  // NEW: Create UNO button
  void _createUnoButton() {
    unoButton?.removeFromParent();
    unoButton = UnoButton(
      position: Vector2(screenWidth * 0.85, screenHeight * 0.85),
      size: Vector2(screenWidth * 0.12, screenHeight * 0.08),
      text: 'UNO!',
      onTap: () => _handleUnoCall(),
    )..priority = layerHud;
    add(unoButton!);
  }

  // NEW: UNO calling logic
  void _handleUnoCall() {
    if (playerHand.length == 1 && !hasCalledUno[0]) {
      hasCalledUno[0] = true;
      statusMessage = '🎯 UNO called!';
      debugPrint('🎯 Player called UNO!');
    } else if (playerHand.length != 1) {
      statusMessage = 'You can only call UNO with 1 card!';
    } else {
      statusMessage = 'You already called UNO!';
    }
  }

  // NEW: Check if player should have called UNO
  void _checkUnoViolation(int playerIndex) {
    final hand = playerIndex == 0 ? playerHand : aiHands[playerIndex - 1];
    
    if (hand.length == 1 && !hasCalledUno[playerIndex]) {
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
    challengeButton = UnoButton(
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
      debugPrint('🚨 Player $targetPlayer challenged for not calling UNO!');
      
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

    debugPrint('🎴 Rendering ${playerHand.length} player cards at y=$cardY');

    for (var i = 0; i < playerHand.length; i++) {
      final cardX = startX + (i * handSpacing);
      
      final cardComp = UnoCardComponent(
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
      
      debugPrint('  Card ${i + 1}: ${playerHand[i].displayText} at x=$cardX, y=$cardY');
    }

    if (discardPile.isNotEmpty) {
      final topCard = discardPile.last;
      final discardX = screenWidth / 2 + cardWidth * 0.7;
      final discardY = screenHeight / 2;
      
      discardTopComponent = UnoCardComponent(
        position: Vector2(discardX, discardY),
        size: Vector2(cardWidth, cardHeight),
        card: topCard,
        onTap: (_) => _handleDiscardPileTap(),
      )..priority = layerCards;
      
      add(discardTopComponent!);
      
      debugPrint('🃏 Discard pile: ${topCard.displayText}');
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
    
    debugPrint('✅ Render complete. Total components: ${children.length}');
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), bgPaint);
    
    _drawGameInfo(canvas);
    _drawAIPlayers(canvas);
    
    super.render(canvas);
    
    if (showColorPicker) {
      _drawColorPicker(canvas);
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

    // NEW: Draw stack indicator
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

    if (currentWildColor != null && !discardPile.last.isWild) {
      currentWildColor = null;
    }
    
    if (currentWildColor != null) {
      final colorNames = {
        UnoColor.red: 'Red',
        UnoColor.blue: 'Blue',
        UnoColor.green: 'Green',
        UnoColor.yellow: 'Yellow',
      };
      
      final colorStyle = TextStyle(
        color: _getColorDisplay(currentWildColor!),
        fontSize: 16 * uiScale,
        fontWeight: FontWeight.bold,
      );
      
      final colorPainter = TextPainter(
        text: TextSpan(text: 'Wild: ${colorNames[currentWildColor]}', style: colorStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      colorPainter.paint(
        canvas,
        Offset(screenWidth * 0.05, screenHeight * 0.05),
      );
    }
  }

  Color _getColorDisplay(UnoColor color) {
    switch (color) {
      case UnoColor.red:
        return const Color(0xFFE53935);
      case UnoColor.blue:
        return const Color(0xFF1E88E5);
      case UnoColor.green:
        return const Color(0xFF43A047);
      case UnoColor.yellow:
        return const Color(0xFFFDD835);
      default:
        return Colors.white;
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
    
    // NEW: Show UNO indicator
    final unoStatus = hasCalledUno[aiIndex + 1] && aiCardCounts[aiIndex] == 1 ? ' 🎯UNO' : '';
    
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
      text: TextSpan(text: '$name\n$cardCount$unoStatus', style: nameStyle),
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
      final backPaint = Paint()..color = Colors.black;
      canvas.drawRRect(rrect, backPaint);
      
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: cardBackSize.height * 0.15,
        fontWeight: FontWeight.bold,
      );
      
      final textPainter = TextPainter(
        text: TextSpan(text: 'UNO', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(
          cardRect.left + cardBackSize.width / 2 - textPainter.width / 2,
          cardRect.top + cardBackSize.height / 2 - textPainter.height / 2,
        ),
      );
      
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.red;
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

  void _drawColorPicker(Canvas canvas) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final dialogWidth = screenWidth * 0.6;
    final dialogHeight = screenHeight * 0.3;
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
      fontSize: 24 * uiScale,
      fontWeight: FontWeight.bold,
    );
    
    final titlePainter = TextPainter(
      text: TextSpan(text: 'Choose a color', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    titlePainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - titlePainter.width / 2,
        screenHeight / 2 - dialogHeight / 2 + 20,
      ),
    );
    
    final colorDisplays = [
      const Color(0xFFE53935),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFDD835),
    ];
    
    final buttonSize = screenWidth * 0.12;
    final spacing = screenWidth * 0.15;
    final startX = screenWidth / 2 - (spacing * 1.5);
    final buttonY = screenHeight / 2 + 20;
    
    for (var i = 0; i < 4; i++) {
      final buttonRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(startX + (i * spacing), buttonY),
          width: buttonSize,
          height: buttonSize,
        ),
        const Radius.circular(12),
      );
      
      final colorPaint = Paint()..color = colorDisplays[i];
      canvas.drawRRect(buttonRect, colorPaint);
      
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.3);
      canvas.drawRRect(buttonRect, borderPaint);
    }
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
    if (gameOver || currentPlayerIndex != 0 || showColorPicker) return;
    
    if (selectedCard != null) {
      final cardIndex = playerCardComponents.indexOf(selectedCard!);
      if (cardIndex >= 0) {
        final card = playerHand[cardIndex];
        if (card.isWild) {
          _showColorPicker();
        } else {
          _playCard(cardIndex, null);
        }
      }
    }
  }

  void _handleCardTap(int cardIndex) {
    if (gameOver || showColorPicker) return;
    
    final card = playerHand[cardIndex];
    debugPrint('🃏 Card clicked: ${card.displayText} (${card.color} ${card.value})');
    
    // NEW: Check for jump-in (identical card)
    if (currentPlayerIndex != 0 && jumpInEnabled) {
      final topCard = discardPile.last;
      if (_isIdenticalCard(card, topCard)) {
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

    // NEW: Allow stacking +2 or +4 cards
    if (drawCount > 0 && _canStackDrawCard(card)) {
      if (selectedCard != null) {
        selectedCard!.setSelected(false);
      }
      selectedCard = cardComp;
      cardComp.setSelected(true);
      statusMessage = 'Stack +${card.value == UnoValue.drawTwo ? '2' : '4'}! Click discard to play.';
      return;
    }

    if (!card.canPlayOn(topCard, currentWildColor) && drawCount == 0) {
      statusMessage = 'Cannot play that card! Match color or number.';
      return;
    }

    if (selectedCard != null) {
      selectedCard!.setSelected(false);
    }

    selectedCard = cardComp;
    cardComp.setSelected(true);
    
    if (card.isWild) {
      statusMessage = 'Wild selected! Click discard pile to play.';
    } else {
      statusMessage = 'Click the discard pile to play ${card.displayText}';
    }
  }

  // NEW: Check if card is identical
  bool _isIdenticalCard(UnoCard card1, UnoCard card2) {
    return card1.color == card2.color && card1.value == card2.value;
  }

  // NEW: Check if card can stack
  bool _canStackDrawCard(UnoCard card) {
    if (drawCount == 0) return false;
    final topCard = discardPile.last;
    
    if (topCard.value == UnoValue.drawTwo && card.value == UnoValue.drawTwo) {
      return true;
    }
    
    if (topCard.value == UnoValue.wildDrawFour && card.value == UnoValue.wildDrawFour) {
      return true;
    }
    
    return false;
  }

  // NEW: Perform jump-in
  void _performJumpIn(int cardIndex) {
    debugPrint('⚡ JUMP-IN! Player playing out of turn!');
    
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);
    
    statusMessage = '⚡ JUMP-IN! You played ${card.displayText}!';
    
    _handleCardAction(card);
    
    if (playerHand.length == 1) {
      hasCalledUno[0] = false;
    }
    
    _renderCards();
    
    if (playerHand.isEmpty) {
      _endGame('player');
      return;
    }
    
    currentPlayerIndex = 0;
    _checkUnoViolation(0);
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) {
        _nextTurn();
      }
    });
  }

  void _showColorPicker() {
    showColorPicker = true;
    statusMessage = 'Choose a color for your wild card!';
  }

  void _handleColorPickerTap(Offset position) {
    if (!showColorPicker) return;
    
    final colors = [
      UnoColor.red,
      UnoColor.blue,
      UnoColor.green,
      UnoColor.yellow,
    ];

    final buttonSize = screenWidth * 0.12;
    final spacing = screenWidth * 0.15;
    final startX = screenWidth / 2 - (spacing * 1.5);
    final buttonY = screenHeight / 2 + 20;

    for (var i = 0; i < colors.length; i++) {
      final buttonRect = Rect.fromCenter(
        center: Offset(startX + (i * spacing), buttonY),
        width: buttonSize,
        height: buttonSize,
      );

      if (buttonRect.contains(position)) {
        if (selectedCard != null) {
          final cardIndex = playerCardComponents.indexOf(selectedCard!);
          if (cardIndex >= 0) {
            _playCard(cardIndex, colors[i]);
          }
        }
        showColorPicker = false;
        selectedCard = null;
        return;
      }
    }
  }

  void _handleDrawCard() {
    if (gameOver || currentPlayerIndex != 0 || showColorPicker) return;
    
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
      if (drawnCard.canPlayOn(topCard, currentWildColor)) {
        statusMessage = 'Drew a card - you can play it or end turn.';
      } else {
        statusMessage = 'Drew a card - turn ending...';
        Future.delayed(const Duration(milliseconds: 800), () {
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

  void _playCard(int cardIndex, UnoColor? chosenColor) {
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);
    
    if (selectedCard != null) {
      selectedCard!.setSelected(false);
      selectedCard = null;
    }
    
    if (card.isWild) {
      currentWildColor = chosenColor;
      statusMessage = 'You played ${card.displayText}!';
    } else {
      currentWildColor = null;
      statusMessage = 'You played ${card.displayText}!';
    }

    if (playerHand.length != 1) {
      hasCalledUno[0] = false;
    }

    _handleCardAction(card);
    _renderCards();

    if (playerHand.isEmpty) {
      _endGame('player');
      return;
    }

    _checkUnoViolation(0);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) {
        _nextTurn();
      }
    });
  }

  void _handleCardAction(UnoCard card) {
    switch (card.value) {
      case UnoValue.skip:
        statusMessage += ' Next player skipped!';
        _skipNextPlayer();
        break;
      
      case UnoValue.reverse:
        clockwise = !clockwise;
        statusMessage += ' Direction reversed!';
        break;
      
      case UnoValue.drawTwo:
        drawCount += 2;
        isDrawStacking = true;
        statusMessage += ' +2 added to stack! Total: +$drawCount';
        break;
      
      case UnoValue.wildDrawFour:
        drawCount += 4;
        isDrawStacking = true;
        statusMessage += ' +4 added to stack! Total: +$drawCount';
        break;
      
      case UnoValue.zero:
        // NEW: Rotate hands when 0 is played
        _rotateHands();
        statusMessage += ' 🔄 Hands rotated!';
        break;
      
      default:
        break;
    }
  }

  // NEW: Rotate all hands
  void _rotateHands() {
    debugPrint('🔄 Rotating hands ${clockwise ? 'clockwise' : 'counter-clockwise'}');
    
    if (clockwise) {
      final temp = List<UnoCard>.from(playerHand);
      playerHand.clear();
      playerHand.addAll(aiHands[2]);
      
      aiHands[2].clear();
      aiHands[2].addAll(aiHands[1]);
      
      aiHands[1].clear();
      aiHands[1].addAll(aiHands[0]);
      
      aiHands[0].clear();
      aiHands[0].addAll(temp);
    } else {
      final temp = List<UnoCard>.from(playerHand);
      playerHand.clear();
      playerHand.addAll(aiHands[0]);
      
      aiHands[0].clear();
      aiHands[0].addAll(aiHands[1]);
      
      aiHands[1].clear();
      aiHands[1].addAll(aiHands[2]);
      
      aiHands[2].clear();
      aiHands[2].addAll(temp);
    }
    
    for (var i = 0; i < 4; i++) {
      hasCalledUno[i] = false;
    }
    
    _sortPlayerHand();
    _renderCards();
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
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (gameOver) return;

      final aiIndex = currentPlayerIndex - 1;
      final aiHand = aiHands[aiIndex];
      final topCard = discardPile.last;

      // AI calls UNO when down to 2 cards
      if (aiHand.length == 2 && !hasCalledUno[currentPlayerIndex]) {
        hasCalledUno[currentPlayerIndex] = true;
        debugPrint('🎯 AI Player ${currentPlayerIndex + 1} called UNO!');
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
          
          if (card.isWild) {
            currentWildColor = _aiChooseWildColor(aiHand);
          }
          
          drawCount += card.value == UnoValue.drawTwo ? 2 : 4;
          statusMessage = 'Player ${currentPlayerIndex + 1} stacked! Total: +$drawCount';
          
          _renderCards();
          
          if (aiHand.isEmpty) {
            _endGame('ai${aiIndex + 1}');
            return;
          }
          
          _checkUnoViolation(currentPlayerIndex);
          
          Future.delayed(const Duration(milliseconds: 800), () {
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
          
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!gameOver) _nextTurn();
          });
          return;
        }
      }

      final playableCards = <int>[];
      for (var i = 0; i < aiHand.length; i++) {
        if (aiHand[i].canPlayOn(topCard, currentWildColor)) {
          playableCards.add(i);
        }
      }

      if (playableCards.isEmpty) {
        aiHand.add(deck.drawCard());
        aiCardCounts[aiIndex] = aiHand.length;
        statusMessage = 'Player ${currentPlayerIndex + 1} drew a card.';
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver) _nextTurn();
        });
        return;
      }

      final cardIndex = _aiChooseCard(playableCards, aiHand);
      final card = aiHand.removeAt(cardIndex);
      discardPile.add(card);
      aiCardCounts[aiIndex] = aiHand.length;

      if (card.isWild) {
        currentWildColor = _aiChooseWildColor(aiHand);
        final colorNames = {
          UnoColor.red: 'Red',
          UnoColor.blue: 'Blue',
          UnoColor.green: 'Green',
          UnoColor.yellow: 'Yellow',
        };
        statusMessage = 'Player ${currentPlayerIndex + 1} played ${card.displayText} (chose ${colorNames[currentWildColor]})';
      } else {
        currentWildColor = null;
        statusMessage = 'Player ${currentPlayerIndex + 1} played ${card.displayText}';
      }

      if (aiHand.length != 1) {
        hasCalledUno[currentPlayerIndex] = false;
      }

      _handleCardAction(card);

      if (aiHand.isEmpty) {
        _endGame('ai${aiIndex + 1}');
        return;
      }

      _renderCards();
      _checkUnoViolation(currentPlayerIndex);
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!gameOver) _nextTurn();
      });
    });
  }

  int _aiChooseCard(List<int> playableCards, List<UnoCard> hand) {
    var bestIndex = playableCards[0];
    var bestCard = hand[playableCards[0]];

    for (var index in playableCards) {
      final card = hand[index];
      
      if (card.value == UnoValue.wildDrawFour) {
        return index;
      }
      
      if (card.value == UnoValue.drawTwo && bestCard.value != UnoValue.wildDrawFour) {
        bestIndex = index;
        bestCard = card;
        continue;
      }
      
      if (card.isAction && !bestCard.isAction && 
          bestCard.value != UnoValue.wildDrawFour && 
          bestCard.value != UnoValue.drawTwo) {
        bestIndex = index;
        bestCard = card;
        continue;
      }
      
      if (card.value == UnoValue.wild && !bestCard.isAction && !bestCard.isWild) {
        bestIndex = index;
        bestCard = card;
      }
      
      if (!card.isAction && !card.isWild && 
          !bestCard.isAction && !bestCard.isWild &&
          card.value.index > bestCard.value.index) {
        bestIndex = index;
        bestCard = card;
      }
    }

    return bestIndex;
  }

  UnoColor _aiChooseWildColor(List<UnoCard> hand) {
    final colorCounts = {
      UnoColor.red: 0,
      UnoColor.blue: 0,
      UnoColor.green: 0,
      UnoColor.yellow: 0,
    };

    for (var card in hand) {
      if (!card.isWild) {
        colorCounts[card.color] = (colorCounts[card.color] ?? 0) + 1;
      }
    }

    var maxColor = UnoColor.red;
    var maxCount = 0;
    colorCounts.forEach((color, count) {
      if (count > maxCount) {
        maxCount = count;
        maxColor = color;
      }
    });

    return maxColor;
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
    if (showColorPicker) {
      _handleColorPickerTap(info.eventPosition.global.toOffset());
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
    
    final backPaint = Paint()..color = Colors.black;
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
      ..color = Colors.red;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}

// ============================================
// UNO Button Component
// ============================================
class UnoButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onTap;
  bool isPressed = false;

  UnoButton({
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