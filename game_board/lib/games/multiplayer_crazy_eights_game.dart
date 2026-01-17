// lib/games/multiplayer_crazy_eights_game.dart
import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../models/crazy_eights_card.dart';
import '../models/user.dart';
import '../components/crazy_eights_card_component.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../screens/multiplayer_crazy_eights_game_screen.dart';

class MultiplayerCrazyEightsGame extends FlameGame with TapCallbacks {
  final User user;
  final String roomId;
  final SocketService socketService;
  
  MultiplayerCrazyEightsGame({
    required this.user,
    required this.roomId,
    required this.socketService,
  });

  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerCards = 2;
  static const int layerHud = 3;
  static const int layerOverlay = 4;

  // Game state
  final List<CrazyEightsCard> discardPile = [];
  CardSuit? currentChosenSuit;
  
  // Multiplayer state
  final List<CrazyEightsCard> playerHand = [];
  final Map<String, OtherPlayer> otherPlayers = {};
  String? currentTurnUserId;
  bool isMyTurn = false;
  bool isHost = false;
  bool isReady = false;
  int playerCount = 1;
  GameState gameState = GameState.waiting;
  
  // Card components
  final List<CrazyEightsCardComponent> playerCardComponents = [];
  CrazyEightsCardComponent? discardTopComponent;
  
  // Game flow
  String direction = 'clockwise';
  int drawCount = 0;
  
  // CrazyEights calling state
  final Map<String, bool> hasCalledCrazyEights = {};
  bool canChallenge = false;
  String? challengeablePlayer;
  
  // UI state
  CrazyEightsCardComponent? selectedCard;
  bool showSuitPicker = false;
  bool showJackChoice = false;
  String? winner;

  // Adaptive sizing
  double get screenWidth => size.x;
  double get screenHeight => size.y;
  double get uiScale => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight => screenHeight * 0.34 * uiScale;
  double get cardWidth => cardHeight * 0.68;

  String statusMessage = 'Waiting for players...';

  @override
  Future<void> onLoad() async {
    super.onLoad();
    debugPrint('🎮 Multiplayer Crazy Eights loaded!');
  }

  // ===========================================
  // MULTIPLAYER PLAYER MANAGEMENT
  // ===========================================
  
  void addOtherPlayer(String userId, String username, int position) {
    if (!otherPlayers.containsKey(userId)) {
      otherPlayers[userId] = OtherPlayer(
        userId: userId,
        username: username,
        position: position,
      );
      debugPrint('➕ Added player: $username');
    }
  }

  void removeOtherPlayer(String userId) {
    otherPlayers.remove(userId);
    debugPrint('➖ Removed player: $userId');
  }

  // ===========================================
  // SOCKET EVENT HANDLERS
  // ===========================================
  
  void handleGameStarted(Map<String, dynamic> data) {
    debugPrint('🎮 Handling game started');
    
    gameState = GameState.playing;
    
    // Parse my hand
    final hands = data['hands'] as Map<String, dynamic>;
    final myHandData = hands[user.id] as List;
    playerHand.clear();
    for (var cardData in myHandData) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }
    
    // Parse discard pile
    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    final discardData = gameStateData['discardPile'] as List;
    discardPile.clear();
    for (var cardData in discardData) {
      discardPile.add(CrazyEightsCard.fromMap(cardData));
    }
    
    // Set initial turn
    currentTurnUserId = gameStateData['currentTurn'];
    isMyTurn = (currentTurnUserId == user.id);
    
    // Initialize other players' card counts
    final players = room['players'] as List;
    for (var player in players) {
      final playerId = player['userId'];
      if (playerId != user.id) {
        if (otherPlayers.containsKey(playerId)) {
          otherPlayers[playerId]!.cardCount = 7; // Initial deal
        }
      }
    }
    
    _sortPlayerHand();
    _renderCards();
    
    debugPrint('   My hand: ${playerHand.length} cards');
    debugPrint('   Discard pile: ${discardPile.length} cards');
    debugPrint('   My turn: $isMyTurn');
  }

  void handleCardPlayed(Map<String, dynamic> data) {
    debugPrint('🃏 Handling card played');
    
    final playerId = data['userId'];
    final cardData = data['card'];
    final card = CrazyEightsCard.fromMap(cardData);
    final chosenSuit = data['chosenSuit'];
    
    // Add to discard pile
    discardPile.add(card);
    
    // Update chosen suit for King/Ace
    if (card.canChangeSuit && chosenSuit != null) {
      currentChosenSuit = _parseSuit(chosenSuit);
    } else if (!card.canChangeSuit) {
      currentChosenSuit = null;
    }
    
    // Update card counts
    if (playerId != user.id) {
      // Other player's card
      if (otherPlayers.containsKey(playerId)) {
        otherPlayers[playerId]!.cardCount = max(0, otherPlayers[playerId]!.cardCount - 1);
      }
    } else {
      // My card - remove it from my hand
      for (int i = 0; i < playerHand.length; i++) {
        if (playerHand[i].suit == card.suit && playerHand[i].rank == card.rank) {
          playerHand.removeAt(i);
          break;
        }
      }
    }
    
    // Update game state from room
    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';
    
    _renderCards();
    
    debugPrint('   Card: ${card.displayText}');
    debugPrint('   Chosen suit: $currentChosenSuit');
    debugPrint('   Draw count: $drawCount');
  }

  void handleCardDrawn(Map<String, dynamic> data) {
    debugPrint('📥 Handling card drawn');
    
    final playerId = data['userId'];
    final count = data['count'];
    
    // Update card count for other players
    if (playerId != user.id) {
      if (otherPlayers.containsKey(playerId)) {
        otherPlayers[playerId]!.cardCount += (count as num).toInt();
      }
    }
    
    // Update game state
    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    
    debugPrint('   Player drew $count card(s)');
  }

  void handleCardsReceived(Map<String, dynamic> data) {
    debugPrint('📨 Handling cards received (my cards)');
    
    final cardsData = data['cards'] as List;
    for (var cardData in cardsData) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }
    
    _sortPlayerHand();
    _renderCards();
    
    debugPrint('   Received ${cardsData.length} card(s)');
    debugPrint('   Total cards: ${playerHand.length}');
  }

  void handlePlayerTurn(Map<String, dynamic> data) {
    debugPrint('👤 Handling player turn');
    
    currentTurnUserId = data['userId'];
    isMyTurn = (currentTurnUserId == user.id);
    
    if (isMyTurn) {
      statusMessage = 'Your turn!';
    } else {
      statusMessage = '${data['username']}\'s turn';
    }
    
    debugPrint('   Current turn: ${data['username']}');
    debugPrint('   Is my turn: $isMyTurn');
  }

  void handleCrazyEightsCalled(Map<String, dynamic> data) {
    debugPrint('🎯 Handling Crazy Eights called');
    
    final playerId = data['userId'];
    hasCalledCrazyEights[playerId] = true;
    
    if (otherPlayers.containsKey(playerId)) {
      otherPlayers[playerId]!.calledCrazyEights = true;
    }
    
    debugPrint('   Player: ${data['username']}');
  }

  void handleCrazyEightsViolation(Map<String, dynamic> data) {
    debugPrint('⚠️ Handling Crazy Eights violation');
    
    final playerId = data['userId'];
    canChallenge = true;
    challengeablePlayer = playerId;
    
    // Auto-cancel challenge after 5 seconds
    async_timer.Future.delayed(Duration(seconds: 5), () {
      canChallenge = false;
      challengeablePlayer = null;
    });
    
    debugPrint('   Player: ${data['username']}');
  }

  void handleJackChoiceNeeded(Map<String, dynamic> data) {
    debugPrint('🃏 Handling Jack choice needed');
    
    if (data['userId'] == user.id) {
      showJackChoice = true;
    }
  }

  void handleJackActionChosen(Map<String, dynamic> data) {
    debugPrint('🃏 Handling Jack action chosen');
    
    showJackChoice = false;
    
    final action = data['action'];
    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    direction = gameStateData['direction'] ?? 'clockwise';
    
    debugPrint('   Action: $action');
    debugPrint('   Direction: $direction');
  }

  void handleGameEnded(Map<String, dynamic> data) {
    debugPrint('🏆 Handling game ended');
    
    gameState = GameState.finished;
    winner = data['winnerName'];
    
    if (data['winnerId'] == user.id) {
      statusMessage = '🏆 YOU WIN!';
    } else {
      statusMessage = '${data['winnerName']} wins!';
    }
    
    debugPrint('   Winner: $winner');
  }

  // ===========================================
  // PLAYER ACTIONS
  // ===========================================
  
  void _handleCardTap(int cardIndex) {
    if (gameState != GameState.playing) return;
    
    if (!isMyTurn) {
      statusMessage = 'Not your turn!';
      return;
    }
    
    final card = playerHand[cardIndex];
    final cardComp = playerCardComponents[cardIndex];
    
    debugPrint('🃏 Card tapped: ${card.displayText}');
    
    // Deselect if already selected
    if (selectedCard == cardComp) {
      cardComp.setSelected(false);
      selectedCard = null;
      statusMessage = 'Card deselected';
      return;
    }
    
    // Check if can play card
    final topCard = discardPile.isNotEmpty ? discardPile.last : null;
    if (topCard != null && !_canPlayCard(card, topCard)) {
      statusMessage = 'Cannot play that card!';
      return;
    }
    
    // Deselect previous card
    if (selectedCard != null) {
      selectedCard!.setSelected(false);
    }
    
    // Select new card
    selectedCard = cardComp;
    cardComp.setSelected(true);
    
    if (card.canChangeSuit) {
      statusMessage = '${card.rankText} selected! Tap again to choose suit';
    } else {
      statusMessage = 'Tap again to play ${card.displayText}';
    }
  }

  void _handleDiscardPileTap() {
    if (gameState != GameState.playing || !isMyTurn) return;
    
    if (selectedCard != null) {
      final cardIndex = playerCardComponents.indexOf(selectedCard!);
      if (cardIndex >= 0) {
        final card = playerHand[cardIndex];
        
        // If King/Ace, show suit picker
        if (card.canChangeSuit) {
          showSuitPicker = true;
          statusMessage = 'Choose a suit!';
          return;
        }
        
        // Play the card
        _playCard(cardIndex, null);
      }
    }
  }

  void _playCard(int cardIndex, CardSuit? chosenSuit) {
  final card = playerHand[cardIndex];  // ✅ Just read it
  
  socketService.playCard(
    roomId: roomId,
    userId: user.id,
    cardIndex: cardIndex,
    suit: chosenSuit?.name,
  );
  
  selectedCard = null;
  showSuitPicker = false;
  
  statusMessage = 'Playing ${card.displayText}...';
}

  void _handleDrawCard() {
    if (gameState != GameState.playing || !isMyTurn) return;
    
    debugPrint('📥 Drawing card');
    
    // Clear selection
    if (selectedCard != null) {
      selectedCard!.setSelected(false);
      selectedCard = null;
    }
    
    // Emit to server
    socketService.drawCard(
      roomId: roomId,
      userId: user.id,
    );
    
    statusMessage = 'Drawing card...';
  }

  void _handleCrazyEightsCall() {
    if (playerHand.length != 1) {
      statusMessage = 'You can only call Crazy Eights with 1 card!';
      return;
    }
    
    if (hasCalledCrazyEights[user.id] == true) {
      statusMessage = 'Already called Crazy Eights!';
      return;
    }
    
    debugPrint('🎯 Calling Crazy Eights');
    
    socketService.callCrazyEights(
      roomId: roomId,
      userId: user.id,
    );
    
    hasCalledCrazyEights[user.id] = true;
    statusMessage = '🎯 Crazy Eights called!';
  }

  void _handleChallenge() {
    if (!canChallenge || challengeablePlayer == null) return;
    
    debugPrint('⚡ Challenging player');
    
    socketService.challengePlayer(
      roomId: roomId,
      challengerId: user.id,
      targetId: challengeablePlayer!,
    );
    
    canChallenge = false;
    challengeablePlayer = null;
    statusMessage = 'Challenge sent!';
  }

  void _handleJackChoice(String action) {
    debugPrint('🃏 Choosing Jack action: $action');
    
    socketService.chooseJackAction(
      roomId: roomId,
      userId: user.id,
      action: action,
    );
    
    showJackChoice = false;
    statusMessage = '$action action chosen!';
  }

  // ===========================================
  // GAME LOGIC HELPERS
  // ===========================================
  
  bool _canPlayCard(CrazyEightsCard card, CrazyEightsCard topCard) {
    // If there's a draw stack
    if (drawCount > 0) {
      // Can only stack Queens with Queens or Aces with Aces
      if (topCard.isQueen && card.isQueen) return true;
      if (topCard.isAce && card.isAce) return true;
      return false;
    }
    
    // King or Ace can always be played
    if (card.isKing || card.isAce) return true;
    
    // Match chosen suit (from previous King/Ace)
    if (currentChosenSuit != null && card.suit == currentChosenSuit) return true;
    
    // Match suit or rank
    if (card.suit == topCard.suit || card.rank == topCard.rank) return true;
    
    return false;
  }

  void _sortPlayerHand() {
    playerHand.sort((a, b) {
      if (a.suit.index != b.suit.index) {
        return a.suit.index.compareTo(b.suit.index);
      }
      return a.rank.index.compareTo(b.rank.index);
    });
  }

  CardSuit _parseSuit(String suit) {
    switch (suit) {
      case 'hearts': return CardSuit.hearts;
      case 'diamonds': return CardSuit.diamonds;
      case 'clubs': return CardSuit.clubs;
      case 'spades': return CardSuit.spades;
      default: return CardSuit.hearts;
    }
  }

  // Continued in part 2...
// lib/games/multiplayer_crazy_eights_game.dart (PART 2 - RENDERING)
// This continues from part 1 - append this to the same file

  // ===========================================
  // RENDERING
  // ===========================================
  
  Future<void> _renderCards() async {
    // Remove existing components
    for (var card in playerCardComponents) {
      card.removeFromParent();
    }
    playerCardComponents.clear();
    
    discardTopComponent?.removeFromParent();
    discardTopComponent = null;

    // Render player hand
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

    // Render discard pile top card
    if (discardPile.isNotEmpty) {
      final topCard = discardPile.last;
      final discardX = screenWidth / 2 + cardWidth * 0.7;
      final discardY = screenHeight / 2;
      
      discardTopComponent = CrazyEightsCardComponent(
        position: Vector2(discardX, discardY),
        size: Vector2(cardWidth, cardHeight),
        card: topCard,
        displaySuit: topCard.canChangeSuit ? currentChosenSuit : null,
        onTap: (_) => _handleDiscardPileTap(),
      )..priority = layerCards;
      
      add(discardTopComponent!);
    }
  }

  @override
  void render(Canvas canvas) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), bgPaint);
    
    if (gameState == GameState.playing) {
      _drawGameInfo(canvas);
      _drawOtherPlayers(canvas);
      _drawDrawPile(canvas);
    }
    
    super.render(canvas);
    
    if (showSuitPicker) {
      _drawSuitPicker(canvas);
    }
    
    if (showJackChoice) {
      _drawJackChoice(canvas);
    }
    
    if (gameState == GameState.finished) {
      _drawGameOver(canvas);
    }
  }

  void _drawGameInfo(Canvas canvas) {
    // Draw count indicator
    if (drawCount > 0) {
      final stackStyle = TextStyle(fontFamily: 'Inter', 
        color: Colors.redAccent,
        fontSize: 24 * uiScale,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 6,
            color: AppColors.primaryNavyDark.withValues(alpha: 0.7),
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
        Offset(screenWidth * 0.05, screenHeight * 0.15),
      );
    }

    // Direction indicator
    final directionText = direction == 'clockwise' ? '→ Clockwise' : '← Counter-Clockwise';
    final dirStyle = TextStyle(fontFamily: 'Inter', 
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
      Offset(screenWidth * 0.72, screenHeight * 0.08),
    );

    // Chosen suit indicator
    if (currentChosenSuit != null) {
      final suitNames = {
        CardSuit.hearts: '♥ Hearts',
        CardSuit.diamonds: '♦ Diamonds',
        CardSuit.clubs: '♣ Clubs',
        CardSuit.spades: '♠ Spades',
      };
      
      final suitStyle = TextStyle(fontFamily: 'Inter', 
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
        Offset(screenWidth * 0.05, screenHeight * 0.08),
      );
    }

    // Crazy Eights and Challenge buttons
    if (playerHand.length == 1 && hasCalledCrazyEights[user.id] != true) {
      _drawCrazyEightsButton(canvas);
    }
    
    if (canChallenge) {
      _drawChallengeButton(canvas);
    }
  }

  void _drawOtherPlayers(Canvas canvas) {
    final playerList = otherPlayers.values.toList();
    
    if (playerList.isEmpty) return;
    
    // Calculate positions based on number of players
    final positions = _calculatePlayerPositions(playerList.length);
    
    for (var i = 0; i < playerList.length; i++) {
      final player = playerList[i];
      final isActive = currentTurnUserId == player.userId;
      _drawOtherPlayer(canvas, positions[i], player, isActive);
    }
  }

  List<Offset> _calculatePlayerPositions(int count) {
    // Positions for 1-3 other players
    if (count == 1) {
      return [Offset(screenWidth * 0.5, screenHeight * 0.15)];
    } else if (count == 2) {
      return [
        Offset(screenWidth * 0.2, screenHeight * 0.25),
        Offset(screenWidth * 0.8, screenHeight * 0.25),
      ];
    } else { // 3 players
      return [
        Offset(screenWidth * 0.15, screenHeight * 0.3),
        Offset(screenWidth * 0.5, screenHeight * 0.15),
        Offset(screenWidth * 0.85, screenHeight * 0.3),
      ];
    }
  }

  void _drawOtherPlayer(Canvas canvas, Offset position, OtherPlayer player, bool isActive) {
    final name = player.username;
    final cardCount = '${player.cardCount} card${player.cardCount != 1 ? 's' : ''}';
    final ceStatus = player.calledCrazyEights && player.cardCount == 1 ? ' 🎯CE' : '';
    
    final nameStyle = TextStyle(fontFamily: 'Inter', 
      color: isActive ? Colors.amber : AppColors.textPrimary,
      fontSize: 16 * uiScale,
      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      shadows: [
        Shadow(
          blurRadius: 4,
          color: AppColors.primaryNavyDark.withValues(alpha: 0.7),
          offset: const Offset(1, 1),
        ),
      ],
    );
    
    final namePainter = TextPainter(
      text: TextSpan(text: '$name\n$cardCount$ceStatus', style: nameStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    namePainter.paint(
      canvas,
      Offset(position.dx - namePainter.width / 2, position.dy),
    );

    // Draw card backs
    final cardBackSize = Size(cardWidth * 0.6, cardHeight * 0.6);
    final displayCards = min(player.cardCount, 5);
    
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
        ..color = AppColors.textPrimary.withValues(alpha: 0.5);
      canvas.drawRRect(rrect, borderPaint);
    }

    if (player.cardCount > 5) {
      final moreStyle = TextStyle(fontFamily: 'Inter', 
        color: AppColors.textPrimary,
        fontSize: 12 * uiScale,
      );
      
      final morePainter = TextPainter(
        text: TextSpan(text: '+${player.cardCount - 5} more', style: moreStyle),
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
    final deckX = screenWidth / 2 - cardWidth * 0.7;
    final deckY = screenHeight / 2;
    
    final rect = Rect.fromCenter(
      center: Offset(deckX, deckY),
      width: cardWidth,
      height: cardHeight,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    
    final backPaint = Paint()..color = const Color(0xFF0B3A79);
    canvas.drawRRect(rrect, backPaint);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DRAW',
        style: TextStyle(fontFamily: 'Inter', 
          color: AppColors.textPrimary,
          fontSize: cardHeight * 0.15,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(deckX - textPainter.width / 2, deckY - textPainter.height / 2),
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.textPrimary.withValues(alpha: 0.5);
    canvas.drawRRect(rrect, borderPaint);
    
    // Check if tap is on draw pile
    // Note: Implement tap detection in onTapDown
  }

  void _drawCrazyEightsButton(Canvas canvas) {
    final buttonWidth = screenWidth * 0.15;
    final buttonHeight = screenHeight * 0.08;
    final buttonX = screenWidth * 0.85;
    final buttonY = screenHeight * 0.85;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(buttonX, buttonY),
        width: buttonWidth,
        height: buttonHeight,
      ),
      const Radius.circular(12),
    );
    
    final buttonPaint = Paint()..color = Colors.red;
    canvas.drawRRect(rect, buttonPaint);
    
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CrazyEights!',
        style: TextStyle(fontFamily: 'Inter', 
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2),
    );
  }

  void _drawChallengeButton(Canvas canvas) {
    final buttonWidth = screenWidth * 0.15;
    final buttonHeight = screenHeight * 0.08;
    final buttonX = screenWidth * 0.85;
    final buttonY = screenHeight * 0.73;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(buttonX, buttonY),
        width: buttonWidth,
        height: buttonHeight,
      ),
      const Radius.circular(12),
    );
    
    final buttonPaint = Paint()..color = Colors.orange;
    canvas.drawRRect(rect, buttonPaint);
    
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Challenge!',
        style: TextStyle(fontFamily: 'Inter', 
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2),
    );
  }

  void _drawSuitPicker(Canvas canvas) {
    final overlayPaint = Paint()..color = AppColors.primaryNavyDark.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final dialogWidth = screenWidth * 0.6;
    final dialogHeight = screenHeight * 0.25;
    final dialogRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenWidth / 2, screenHeight / 2),
        width: dialogWidth,
        height: dialogHeight,
      ),
      const Radius.circular(20),
    );
    
    final dialogPaint = Paint()..color = AppColors.textPrimary;
    canvas.drawRRect(dialogRect, dialogPaint);
    
    final titleStyle = TextStyle(fontFamily: 'Inter', 
      color: AppColors.primaryNavyDark,
      fontSize: 20 * uiScale,
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
    
    // Draw 4 suit buttons
    final buttonSize = screenWidth * 0.11;
    final totalWidth = (buttonSize * 4) + (screenWidth * 0.02 * 3);
    final startX = screenWidth / 2 - totalWidth / 2;
    final buttonY = screenHeight / 2 + dialogHeight / 4;
    
    final suits = [
      {'suit': CardSuit.hearts, 'symbol': '♥', 'color': const Color(0xFFE53935)},
      {'suit': CardSuit.diamonds, 'symbol': '♦', 'color': const Color(0xFFE53935)},
      {'suit': CardSuit.clubs, 'symbol': '♣', 'color': AppColors.primaryNavyDark},
      {'suit': CardSuit.spades, 'symbol': '♠', 'color': AppColors.primaryNavyDark},
    ];
    
    for (var i = 0; i < 4; i++) {
      final x = startX + (i * (buttonSize + screenWidth * 0.02));
      
      final buttonRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize),
        const Radius.circular(12),
      );
      
      final bgPaint = Paint()..color = Colors.grey.shade200;
      canvas.drawRRect(buttonRect, bgPaint);
      
      final symbolStyle = TextStyle(fontFamily: 'Inter', 
        color: suits[i]['color'] as Color,
        fontSize: buttonSize * 0.5,
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
        ..color = AppColors.primaryNavyDark.withValues(alpha: 0.3);
      canvas.drawRRect(buttonRect, borderPaint);
    }
  }

  void _drawJackChoice(Canvas canvas) {
    final overlayPaint = Paint()..color = AppColors.primaryNavyDark.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final dialogWidth = screenWidth * 0.65;
    final dialogHeight = screenHeight * 0.22;
    final dialogRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenWidth / 2, screenHeight / 2),
        width: dialogWidth,
        height: dialogHeight,
      ),
      const Radius.circular(20),
    );
    
    final dialogPaint = Paint()..color = AppColors.textPrimary;
    canvas.drawRRect(dialogRect, dialogPaint);
    
    final titleStyle = TextStyle(fontFamily: 'Inter', 
      color: AppColors.primaryNavyDark,
      fontSize: 20 * uiScale,
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
    final buttonWidth = screenWidth * 0.25;
    final buttonHeight = screenHeight * 0.07;
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
        style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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
        style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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
    final overlayPaint = Paint()..color = AppColors.primaryNavyDark.withValues(alpha: 0.8);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);
    
    final resultText = winner == user.username ? 'YOU WIN!' : 'YOU LOSE!';
    final subtitleText = winner == user.username 
        ? '🎉 Congratulations! 🎉' 
        : 'Winner: $winner';
    
    final textStyle = TextStyle(fontFamily: 'Inter', 
      color: winner == user.username ? AppColors.primaryNavyLight : Colors.redAccent,
      fontSize: 48 * uiScale,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 10,
          color: AppColors.primaryNavyDark,
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

    final subtitleStyle = TextStyle(fontFamily: 'Inter', 
      color: AppColors.textPrimary,
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

  Color _getSuitColor(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:
      case CardSuit.diamonds:
        return const Color(0xFFE53935);
      case CardSuit.clubs:
      case CardSuit.spades:
        return AppColors.primaryNavyDark;
    }
  }

  // ===========================================
  // INPUT HANDLING
  // ===========================================
  
  @override
  void onTapDown(TapDownEvent event) {
    final position = event.localPosition.toOffset();
    
    if (showSuitPicker) {
      _handleSuitPickerTap(position);
    } else if (showJackChoice) {
      _handleJackChoiceTap(position);
    } else if (gameState == GameState.playing && isMyTurn) {
      _handleGameTap(position);
    }
  }

  void _handleSuitPickerTap(Offset position) {
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

  void _handleJackChoiceTap(Offset position) {
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
      _handleJackChoice('skip');
    } else if (reverseRect.contains(position)) {
      _handleJackChoice('reverse');
    }
  }

  void _handleGameTap(Offset position) {
    // Check draw pile
    final deckX = screenWidth / 2 - cardWidth * 0.7;
    final deckY = screenHeight / 2;
    final deckRect = Rect.fromCenter(
      center: Offset(deckX, deckY),
      width: cardWidth,
      height: cardHeight,
    );
    
    if (deckRect.contains(position)) {
      _handleDrawCard();
      return;
    }
    
    // Check Crazy Eights button
    if (playerHand.length == 1 && hasCalledCrazyEights[user.id] != true) {
      final buttonX = screenWidth * 0.85;
      final buttonY = screenHeight * 0.85;
      final buttonRect = Rect.fromCenter(
        center: Offset(buttonX, buttonY),
        width: screenWidth * 0.15,
        height: screenHeight * 0.08,
      );
      
      if (buttonRect.contains(position)) {
        _handleCrazyEightsCall();
        return;
      }
    }
    
    // Check Challenge button
    if (canChallenge) {
      final buttonX = screenWidth * 0.85;
      final buttonY = screenHeight * 0.73;
      final buttonRect = Rect.fromCenter(
        center: Offset(buttonX, buttonY),
        width: screenWidth * 0.15,
        height: screenHeight * 0.08,
      );
      
      if (buttonRect.contains(position)) {
        _handleChallenge();
        return;
      }
    }
  }
}

// ===========================================
// OTHER PLAYER CLASS
// ===========================================
class OtherPlayer {
  final String userId;
  final String username;
  final int position;
  int cardCount;
  bool isReady;
  bool calledCrazyEights;
  
  OtherPlayer({
    required this.userId,
    required this.username,
    required this.position,
    this.cardCount = 7,
    this.isReady = false,
    this.calledCrazyEights = false,
  });
  
  void setReady(bool ready) {
    isReady = ready;
  }
}