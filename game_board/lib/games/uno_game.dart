// lib/games/uno_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../models/uno_card.dart';
import '../models/user.dart';
import '../components/uno_card_component.dart';

class UnoGame extends FlameGame with TapDetector {
  final User user;
  
  UnoGame({required this.user});

  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerCards = 2;
  static const int layerHud = 3;

  // Game state
  late UnoDeck deck;
  final List<UnoCard> discardPile = [];
  UnoColor? currentWildColor; // For when a wild card is played
  
  // Player hands
  final List<UnoCard> playerHand = [];
  final List<List<UnoCard>> aiHands = [[], [], []]; // 3 AI opponents
  
  // Card components
  final List<UnoCardComponent> playerCardComponents = [];
  UnoCardComponent? discardTopComponent;
  final List<int> aiCardCounts = [0, 0, 0];
  
  // Game flow
  int currentPlayerIndex = 0; // 0 = human player, 1-3 = AI
  bool clockwise = true;
  bool needsToDrawCard = false;
  int drawCount = 0; // For +2 and +4 stacking
  
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

  // UI text
  String statusMessage = 'Your turn! Play a card or draw.';

  // ============================================
  // INITIALIZATION
  // ============================================

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize deck and deal cards
    deck = UnoDeck();
    _dealInitialCards();
    
    // Place first card on discard pile (can't be action card)
    _placeFirstDiscardCard();
    
    await _renderCards();
    
    debugPrint('UNO Game loaded!');
  }

  void _dealInitialCards() {
    // Deal 7 cards to each player
    for (var i = 0; i < 7; i++) {
      playerHand.add(deck.drawCard());
      for (var j = 0; j < 3; j++) {
        aiHands[j].add(deck.drawCard());
      }
    }
    
    // Sort player hand
    _sortPlayerHand();
    
    // Update AI card counts
    for (var i = 0; i < 3; i++) {
      aiCardCounts[i] = aiHands[i].length;
    }
  }

  void _placeFirstDiscardCard() {
    // Draw until we get a number card (not action or wild)
    UnoCard firstCard;
    do {
      firstCard = deck.drawCard();
    } while (firstCard.isAction || firstCard.isWild);
    
    discardPile.add(firstCard);
  }

  void _sortPlayerHand() {
    playerHand.sort((a, b) {
      // Sort by color first, then by value
      if (a.color.index != b.color.index) {
        return a.color.index.compareTo(b.color.index);
      }
      return a.value.index.compareTo(b.value.index);
    });
  }

  // ============================================
  // RENDERING
  // ============================================

  Future<void> _renderCards() async {
    // Clear existing card components
    for (var card in playerCardComponents) {
      card.removeFromParent();
    }
    playerCardComponents.clear();
    
    // Remove discard top component if it exists
    if (discardTopComponent != null) {
      discardTopComponent!.removeFromParent();
      discardTopComponent = null;
    }

    // Render player hand - FIXED positioning
    final handSpacing = cardWidth * 0.5;  // Increased spacing
    final totalWidth = (playerHand.length - 1) * handSpacing + cardWidth;
    final startX = (screenWidth - totalWidth) / 2 + cardWidth / 2;
    final cardY = screenHeight - cardHeight * 0.6;  // Changed to be higher up

    debugPrint('🎴 Rendering ${playerHand.length} player cards at y=$cardY');

    for (var i = 0; i < playerHand.length; i++) {
      final cardX = startX + (i * handSpacing);
      
      final cardComp = UnoCardComponent(
        position: Vector2(cardX, cardY),
        size: Vector2(cardWidth, cardHeight),
        card: playerHand[i],
      )..priority = layerCards + 10 + i;  // Higher priority to ensure visibility

      playerCardComponents.add(cardComp);
      add(cardComp);
      
      debugPrint('  Card ${i + 1}: ${playerHand[i].displayText} at x=$cardX, y=$cardY');
    }

    // Render discard pile (top card)
    if (discardPile.isNotEmpty) {
      final topCard = discardPile.last;
      final discardX = screenWidth / 2 + cardWidth * 0.7;
      final discardY = screenHeight / 2;
      
      discardTopComponent = UnoCardComponent(
        position: Vector2(discardX, discardY),
        size: Vector2(cardWidth, cardHeight),
        card: topCard,
      )..priority = layerCards;
      
      add(discardTopComponent!);
      
      debugPrint('🃏 Discard pile: ${topCard.displayText}');
    }

    // Update AI card counts
    for (var i = 0; i < 3; i++) {
      aiCardCounts[i] = aiHands[i].length;
    }
    
    debugPrint('✅ Render complete. Total components: ${children.length}');
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Draw background
    final bgPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), bgPaint);
    
    // Draw game elements
    _drawGameInfo(canvas);
    _drawAIPlayers(canvas);
    _drawDrawPile(canvas);
    
    if (showColorPicker) {
      _drawColorPicker(canvas);
    }
    
    if (gameOver) {
      _drawGameOver(canvas);
    }
  }

  void _drawGameInfo(Canvas canvas) {
    // Draw current status message
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

    // Draw direction indicator
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

    // Show current wild color if applicable
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
    // AI opponents positioned around the table
    final positions = [
      Offset(screenWidth * 0.1, screenHeight * 0.3),  // Left
      Offset(screenWidth * 0.5, screenHeight * 0.1),  // Top
      Offset(screenWidth * 0.9, screenHeight * 0.3),  // Right
    ];

    for (var i = 0; i < 3; i++) {
      final isActive = currentPlayerIndex == i + 1;
      _drawAIPlayer(canvas, positions[i], i, isActive);
    }
  }

  void _drawAIPlayer(Canvas canvas, Offset position, int aiIndex, bool isActive) {
    // Draw name and card count
    final name = 'Player ${aiIndex + 2}';
    final cardCount = '${aiCardCounts[aiIndex]} card${aiCardCounts[aiIndex] != 1 ? 's' : ''}';
    
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
      text: TextSpan(text: '$name\n$cardCount', style: nameStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    namePainter.paint(
      canvas,
      Offset(position.dx - namePainter.width / 2, position.dy),
    );

    // Draw card backs
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
      
      // UNO text on back
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

    // Show "+X more" if more than 5 cards
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

  void _drawDrawPile(Canvas canvas) {
    // Draw pile representation (deck) - positioned to the LEFT of discard
    final deckX = screenWidth / 2 - cardWidth * 0.7;  // Changed from -1.2
    final deckY = screenHeight / 2;
    
    final deckRect = Rect.fromCenter(
      center: Offset(deckX, deckY),
      width: cardWidth,
      height: cardHeight,
    );
    
    final rrect = RRect.fromRectAndRadius(deckRect, const Radius.circular(12));
    final backPaint = Paint()..color = Colors.black;
    canvas.drawRRect(rrect, backPaint);
    
    // "DRAW" text
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: cardHeight * 0.1,
      fontWeight: FontWeight.bold,
    );
    
    final textPainter = TextPainter(
      text: TextSpan(text: 'DRAW\n${deck.remainingCards}', style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(
        deckX - textPainter.width / 2,
        deckY - textPainter.height / 2,
      ),
    );

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.red;
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawColorPicker(Canvas canvas) {
    // Semi-transparent overlay
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    // Color picker dialog
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
    
    // Title
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
    
    // Color buttons
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
      
      // Draw color button
      final colorPaint = Paint()..color = colorDisplays[i];
      canvas.drawRRect(buttonRect, colorPaint);
      
      // Draw border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.3);
      canvas.drawRRect(buttonRect, borderPaint);
    }
  }

  void _drawGameOver(Canvas canvas) {
    // Game over overlay
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

    // Subtitle
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
  
  @override
  void onTapDown(TapDownInfo info) {
    final position = info.eventPosition.global.toOffset();
    
    if (gameOver) return;
    
    if (showColorPicker) {
      _handleColorPickerTap(position);
      return;
    }
    
    if (currentPlayerIndex != 0) return;

    // Check if tapped on player's cards
    for (var i = 0; i < playerCardComponents.length; i++) {
      final card = playerCardComponents[i];
      
      // Create Rect from card position and size
      final cardRect = Rect.fromCenter(
        center: Offset(card.position.x, card.position.y),
        width: card.size.x,
        height: card.size.y,
      );
      
      if (cardRect.contains(position)) {
        _handleCardTap(i);
        return;
      }
    }

    // Check if tapped on draw pile - FIXED: Updated position
    final deckX = screenWidth / 2 - cardWidth * 0.7;
    final deckY = screenHeight / 2;
    final deckRect = Rect.fromCenter(
      center: Offset(deckX, deckY),
      width: cardWidth,
      height: cardHeight,
    );
    
    if (deckRect.contains(position)) {
      _handleDrawCard();
    }
  }

  void _handleCardTap(int cardIndex) {
    final card = playerHand[cardIndex];
    final topCard = discardPile.last;

    // Check if card can be played
    if (!card.canPlayOn(topCard, currentWildColor)) {
      statusMessage = 'Cannot play that card! Match color or number.';
      return;
    }

    // If it's a wild card, show color picker
    if (card.isWild) {
      selectedCard = playerCardComponents[cardIndex];
      showColorPicker = true;
      return;
    }

    // Play the card
    _playCard(cardIndex, null);
  }

  void _handleColorPickerTap(Offset position) {
    // Color buttons positioned in dialog
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
        // Find the selected wild card
        final cardIndex = playerCardComponents.indexOf(selectedCard!);
        _playCard(cardIndex, colors[i]);
        showColorPicker = false;
        selectedCard = null;
        return;
      }
    }
  }

  void _handleDrawCard() {
    if (drawCount > 0) {
      // Must draw penalty cards
      for (var i = 0; i < drawCount; i++) {
        playerHand.add(deck.drawCard());
      }
      _sortPlayerHand();
      _renderCards();
      
      statusMessage = 'Drew $drawCount penalty card(s).';
      drawCount = 0;
      
      // After drawing penalty, turn ends
      _nextTurn();
    } else {
      // Regular draw
      final drawnCard = deck.drawCard();
      playerHand.add(drawnCard);
      _sortPlayerHand();
      _renderCards();
      
      // Check if drawn card can be played immediately
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
    
    // Handle wild cards
    if (card.isWild) {
      currentWildColor = chosenColor;
      statusMessage = 'You played ${card.displayText}!';
    } else {
      currentWildColor = null;
      statusMessage = 'You played ${card.displayText}!';
    }

    // Handle action cards
    _handleCardAction(card);

    _renderCards();

    // Check for win
    if (playerHand.isEmpty) {
      _endGame('player');
      return;
    }

    // Delay before next turn
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
        statusMessage += ' Next player draws 2!';
        break;
      
      case UnoValue.wildDrawFour:
        drawCount += 4;
        statusMessage += ' Next player draws 4!';
        break;
      
      default:
        // Regular card, no special action
        break;
    }
  }

  void _skipNextPlayer() {
    // Skip happens by advancing turn twice
    _advanceTurn();
  }

  void _nextTurn() {
    _advanceTurn();
    
    if (currentPlayerIndex == 0) {
      // Player's turn
      statusMessage = 'Your turn! Play a card or draw.';
    } else {
      // AI turn
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

      // Check for penalty cards to draw
      if (drawCount > 0) {
        // AI draws penalty cards
        for (var i = 0; i < drawCount; i++) {
          aiHand.add(deck.drawCard());
        }
        aiCardCounts[aiIndex] = aiHand.length;
        statusMessage = 'Player ${currentPlayerIndex + 1} drew $drawCount penalty card(s).';
        drawCount = 0;
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver) _nextTurn();
        });
        return;
      }

      // Find playable cards
      final playableCards = <int>[];
      for (var i = 0; i < aiHand.length; i++) {
        if (aiHand[i].canPlayOn(topCard, currentWildColor)) {
          playableCards.add(i);
        }
      }

      if (playableCards.isEmpty) {
        // AI must draw
        aiHand.add(deck.drawCard());
        aiCardCounts[aiIndex] = aiHand.length;
        statusMessage = 'Player ${currentPlayerIndex + 1} drew a card.';
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver) _nextTurn();
        });
        return;
      }

      // AI plays a card (with strategy)
      final cardIndex = _aiChooseCard(playableCards, aiHand);
      final card = aiHand.removeAt(cardIndex);
      discardPile.add(card);
      aiCardCounts[aiIndex] = aiHand.length;

      // Handle wild cards (AI chooses most common color in hand)
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

      // Handle actions
      _handleCardAction(card);

      // Check for AI win
      if (aiHand.isEmpty) {
        _endGame('ai${aiIndex + 1}');
        return;
      }

      _renderCards();
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!gameOver) _nextTurn();
      });
    });
  }

  int _aiChooseCard(List<int> playableCards, List<UnoCard> hand) {
    // AI Strategy: Prioritize action cards, then wild cards, then highest number
    var bestIndex = playableCards[0];
    var bestCard = hand[playableCards[0]];

    for (var index in playableCards) {
      final card = hand[index];
      
      // Prefer Draw Four over everything
      if (card.value == UnoValue.wildDrawFour) {
        return index;
      }
      
      // Prefer Draw Two
      if (card.value == UnoValue.drawTwo && bestCard.value != UnoValue.wildDrawFour) {
        bestIndex = index;
        bestCard = card;
        continue;
      }
      
      // Then other action cards
      if (card.isAction && !bestCard.isAction && 
          bestCard.value != UnoValue.wildDrawFour && 
          bestCard.value != UnoValue.drawTwo) {
        bestIndex = index;
        bestCard = card;
        continue;
      }
      
      // Then regular wild cards
      if (card.value == UnoValue.wild && !bestCard.isAction && !bestCard.isWild) {
        bestIndex = index;
        bestCard = card;
      }
      
      // If both are numbers, play higher value
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
    // Count colors in hand
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

    // Choose most common color
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
    
    debugPrint('Game Over! Winner: $winner');
  }
}