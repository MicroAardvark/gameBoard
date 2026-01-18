// lib/games/multiplayer_crazy_eights_game.dart
// FIXED: Suit-picker now plays the King/Ace with chosenSuit (no standalone chooseSuit)
// FIXED: Rank sent to server in expected format (e.g. "6" not "six")
// FIXED: Stop mutating/sorting playerHand (prevents index mismatch vs server); sort only for display via index map
// UPDATED: Added optimistic UI with server validation

import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/crazy_eights_card_component.dart';
import '../models/crazy_eights_card.dart';
import '../models/user.dart';
import '../screens/multiplayer_crazy_eights_game_screen.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';

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
  final List<int> playerCardIndexMap = []; // component index -> playerHand index
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
  int? selectedCardIndex; // index in playerHand (NOT display index)
  bool showSuitPicker = false;
  bool showJackChoice = false;
  String? winner;

  // NEW: Optimistic UI state
  bool awaitingServerValidation = false;
  CrazyEightsCard? optimisticCard; // Card played optimistically for rollback

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

    // Clear optimistic state
    awaitingServerValidation = false;
    optimisticCard = null;

    // Parse my hand (KEEP SERVER ORDER - do NOT sort/mutate)
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

    // Initial chosen suit (if any)
    final chosenSuitString = gameStateData['chosenSuit'];
    currentChosenSuit = chosenSuitString != null ? _parseSuit(chosenSuitString) : null;

    // Game flow values
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';

    // Initialise other players' card counts
    final players = room['players'] as List;
    for (var player in players) {
      final playerId = player['userId'];
      if (playerId != user.id) {
        if (otherPlayers.containsKey(playerId)) {
          otherPlayers[playerId]!.cardCount = 7; // Initial deal
        }
      }
    }

    _renderCards();

    statusMessage = isMyTurn ? 'Your turn!' : 'Waiting for ${_getPlayerName(currentTurnUserId)}...';

    debugPrint('   My hand: ${playerHand.length} cards');
    debugPrint('   Discard pile: ${discardPile.length} cards');
    debugPrint('   My turn: $isMyTurn');
  }

  // UPDATED: Handle card played with optimistic UI support
  void handleCardPlayed(Map<String, dynamic> data) {
    debugPrint('🃏 Handling card played');

    final playerId = data['userId'];
    final cardData = data['card'];
    final card = CrazyEightsCard.fromMap(cardData);
    final chosenSuit = data['chosenSuit'];

    // Clear optimistic state
    awaitingServerValidation = false;
    optimisticCard = null;

    // If this is my play, it was already applied optimistically
    if (playerId == user.id) {
      selectedCardIndex = null;
      selectedCard = null;
      showSuitPicker = false;
    } else {
      // Add to discard pile for other players
      discardPile.add(card);

      // Update other player's card count
      if (otherPlayers.containsKey(playerId)) {
        otherPlayers[playerId]!.cardCount = max(0, otherPlayers[playerId]!.cardCount - 1);
      }
    }

    // Update chosen suit for King/Ace
    if (card.canChangeSuit && chosenSuit != null) {
      currentChosenSuit = _parseSuit(chosenSuit);
    } else if (!card.canChangeSuit) {
      currentChosenSuit = null;
    }

    // Update game state from room
    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';

    final chosenSuitString = gameStateData['chosenSuit'];
    currentChosenSuit = chosenSuitString != null ? _parseSuit(chosenSuitString) : null;

    _renderCards();

    // Update status
    final playerName = _getPlayerName(playerId);
    statusMessage = '$playerName played ${card.displayText}';

    debugPrint('   Card: ${card.displayText}');
    debugPrint('   Chosen suit: $currentChosenSuit');
    debugPrint('   Draw count: $drawCount');
  }

  // NEW: Handle card play rejected (optimistic update rollback)
  void handleCardPlayRejected(Map<String, dynamic> data) {
    debugPrint('❌ Card play rejected: ${data['reason']}');

    // Revert optimistic update
    if (optimisticCard != null) {
      // Remove from discard pile
      if (discardPile.isNotEmpty && discardPile.last == optimisticCard) {
        discardPile.removeLast();
      }

      // Re-add to hand (server order doesn’t matter for append; you can optionally insert back, but
      // keeping server order is less important here than consistency)
      playerHand.add(optimisticCard!);
      optimisticCard = null;
    }

    awaitingServerValidation = false;
    selectedCardIndex = null;
    selectedCard = null;
    showSuitPicker = false;

    _renderCards();

    statusMessage = 'Invalid move: ${data['reason']}';
  }

  // NEW: Handle turn changed
  void handleTurnChanged(Map<String, dynamic> data) {
    debugPrint('🔄 Turn changed');

    currentTurnUserId = data['currentTurn'];
    isMyTurn = (currentTurnUserId == user.id);
    direction = data['direction'] ?? 'clockwise';

    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;

    final chosenSuitString = gameStateData['chosenSuit'];
    currentChosenSuit = chosenSuitString != null ? _parseSuit(chosenSuitString) : null;

    statusMessage = isMyTurn ? 'Your turn!' : 'Waiting for ${_getPlayerName(currentTurnUserId)}...';

    // Clear any local selection UI when turn changes
    if (!isMyTurn) {
      if (selectedCard != null) {
        selectedCard!.setSelected(false);
      }
      selectedCard = null;
      selectedCardIndex = null;
      showSuitPicker = false;
      showJackChoice = false;
    }

    _renderCards();

    debugPrint('   Current turn: $currentTurnUserId');
    debugPrint('   Is my turn: $isMyTurn');
  }

  // NEW: Handle suit chosen (server broadcast)
  void handleSuitChosen(Map<String, dynamic> data) {
    debugPrint('👑 Suit chosen');

    final suit = data['suit'];
    final playerId = data['userId'];

    currentChosenSuit = _parseSuit(suit);

    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;

    _renderCards();

    final playerName = _getPlayerName(playerId);
    final suitDisplay = _getSuitDisplay(currentChosenSuit!);
    statusMessage = '$playerName chose $suitDisplay';

    debugPrint('   Suit: $suit');
  }

  // NEW: Handle choose suit required (server asks client)
  void handleChooseSuitRequired(Map<String, dynamic> data) {
    debugPrint('👑 Choose suit required');
    showSuitPicker = true;
    statusMessage = 'Choose a suit!';
  }

  // NEW: Handle Jack action chosen
  void handleJackActionChosen(Map<String, dynamic> data) {
    debugPrint('🃏 Jack action chosen');

    showJackChoice = false;

    final action = data['action'];
    final playerId = data['userId'];
    final newDirection = data['direction'];

    direction = newDirection;

    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;

    _renderCards();

    final playerName = _getPlayerName(playerId);
    statusMessage = '$playerName chose ${action.toUpperCase()}';

    debugPrint('   Action: $action');
    debugPrint('   Direction: $direction');
  }

  // NEW: Handle choose Jack action required
  void handleChooseJackActionRequired(Map<String, dynamic> data) {
    debugPrint('🃏 Choose Jack action required');
    showJackChoice = true;
    statusMessage = 'Choose Jack action!';
  }

  void handleCardDrawn(Map<String, dynamic> data) {
    debugPrint('📥 Handling card drawn (other player)');

    final playerId = data['userId'];
    final count = data['count'];

    if (playerId != user.id) {
      if (otherPlayers.containsKey(playerId)) {
        otherPlayers[playerId]!.cardCount += (count as num).toInt();
      }
    }

    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';

    final chosenSuitString = gameStateData['chosenSuit'];
    currentChosenSuit = chosenSuitString != null ? _parseSuit(chosenSuitString) : null;

    _renderCards();

    final playerName = _getPlayerName(playerId);
    statusMessage = '$playerName drew $count card(s)';

    debugPrint('   Player drew $count card(s)');
  }

  // NEW: Handle cards drawn (my cards with card data)
  void handleCardsDrawn(Map<String, dynamic> data) {
    debugPrint('📨 Handling my cards drawn');

    final cardsData = data['cards'] as List;
    for (var cardData in cardsData) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }

    final room = data['room'];
    final gameStateData = room['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';

    final chosenSuitString = gameStateData['chosenSuit'];
    currentChosenSuit = chosenSuitString != null ? _parseSuit(chosenSuitString) : null;

    _renderCards();

    statusMessage = 'You drew ${cardsData.length} card(s)';

    debugPrint('   Drew: ${cardsData.length} cards');
  }

  void handleCardsReceived(Map<String, dynamic> data) {
    debugPrint('📨 Handling cards received (legacy event)');

    final cardsData = data['cards'] as List;
    for (var cardData in cardsData) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }

    _renderCards();

    debugPrint('   Received ${cardsData.length} card(s)');
    debugPrint('   Total cards: ${playerHand.length}');
  }

  void handlePlayerTurn(Map<String, dynamic> data) {
    debugPrint('👤 Handling player turn (legacy event)');

    currentTurnUserId = data['userId'];
    isMyTurn = (currentTurnUserId == user.id);

    if (isMyTurn) {
      statusMessage = 'Your turn!';
    } else {
      statusMessage = '${data['username']}\'s turn';
    }

    // When the turn changes, clear any local selection UI
    if (!isMyTurn) {
      if (selectedCard != null) {
        selectedCard!.setSelected(false);
      }
      selectedCard = null;
      selectedCardIndex = null;
      showSuitPicker = false;
      showJackChoice = false;
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

    async_timer.Future.delayed(const Duration(seconds: 5), () {
      canChallenge = false;
      challengeablePlayer = null;
    });

    debugPrint('   Player: ${data['username']}');
  }

  void handleJackChoiceNeeded(Map<String, dynamic> data) {
    debugPrint('🃏 Handling Jack choice needed (legacy event)');

    if (data['userId'] == user.id) {
      showJackChoice = true;
    }
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

    _renderCards();

    debugPrint('   Winner: $winner');
  }

  // ===========================================
  // PLAYER ACTIONS
  // ===========================================

  void _handleCardTap(int handIndex) {
    if (gameState != GameState.playing) return;

    if (!isMyTurn) {
      statusMessage = 'Not your turn!';
      return;
    }

    if (awaitingServerValidation) {
      statusMessage = 'Waiting for server...';
      return;
    }

    if (handIndex < 0 || handIndex >= playerHand.length) return;

    final card = playerHand[handIndex];
    final cardComp = _componentForHandIndex(handIndex);

    debugPrint('🃏 Card tapped: ${card.displayText}');

    if (cardComp == null) return;

    // Deselect if already selected
    if (selectedCard == cardComp) {
      cardComp.setSelected(false);
      selectedCard = null;
      selectedCardIndex = null;
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
    selectedCardIndex = handIndex;
    cardComp.setSelected(true);

    if (card.canChangeSuit) {
      statusMessage = '${card.rankText} selected! Tap discard pile to choose suit';
    } else {
      statusMessage = 'Tap discard pile to play ${card.displayText}';
    }
  }

  void _handleDiscardPileTap() {
    if (gameState != GameState.playing || !isMyTurn) return;

    if (awaitingServerValidation) {
      statusMessage = 'Waiting for server...';
      return;
    }

    if (selectedCardIndex == null) return;

    final idx = selectedCardIndex!;
    if (idx < 0 || idx >= playerHand.length) {
      selectedCardIndex = null;
      selectedCard = null;
      showSuitPicker = false;
      return;
    }

    final card = playerHand[idx];

    // If King/Ace, show suit picker (actual play happens when suit picked)
    if (card.canChangeSuit) {
      showSuitPicker = true;
      statusMessage = 'Choose a suit!';
      return;
    }

    // Play the card
    _playCard(idx, null);
  }

  // UPDATED: Play card with optimistic UI
  void _playCard(int handIndex, CardSuit? chosenSuit) {
    if (handIndex < 0 || handIndex >= playerHand.length) return;

    final card = playerHand[handIndex];

    debugPrint('🎮 Playing card: ${card.displayText}');

    // ✅ OPTIMISTIC UPDATE - Add card to discard pile immediately
    awaitingServerValidation = true;
    optimisticCard = card;
    playerHand.removeAt(handIndex);
    discardPile.add(card);

    // Clear selection
    selectedCard?.setSelected(false);
    selectedCard = null;
    selectedCardIndex = null;
    showSuitPicker = false;

    // Update UI immediately
    _renderCards();

    statusMessage = 'Playing ${card.displayText}...';

    // Send to server for validation
    // IMPORTANT: rank formatting + keeping server index alignment
    socketService.playCard(
      roomId: roomId,
      userId: user.id,
      cardIndex: handIndex,
      cardSuit: card.suit.name,
      cardRank: _rankToServerString(card.rank),
      chosenSuit: chosenSuit?.name,
    );

    debugPrint('   Sent to server for validation');
  }

  void _handleDrawCard() {
    if (gameState != GameState.playing || !isMyTurn) return;

    if (awaitingServerValidation) {
      statusMessage = 'Waiting for server...';
      return;
    }

    debugPrint('📥 Drawing card');

    // Clear selection
    if (selectedCard != null) {
      selectedCard!.setSelected(false);
      selectedCard = null;
    }
    selectedCardIndex = null;
    showSuitPicker = false;

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

  CardSuit _parseSuit(String suit) {
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
        return CardSuit.hearts;
    }
  }

  String _getSuitDisplay(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:
        return '♥ Hearts';
      case CardSuit.diamonds:
        return '♦ Diamonds';
      case CardSuit.clubs:
        return '♣ Clubs';
      case CardSuit.spades:
        return '♠ Spades';
    }
  }

  String _getPlayerName(String? userId) {
    if (userId == null) return 'Unknown';
    if (userId == user.id) return 'You';

    final player = otherPlayers[userId];
    return player?.username ?? 'Player';
  }

  // Convert Dart enum rank naming to the server’s expected strings.
  // Numbers must be "2".."10" (not "two", "ten"). Faces use lower-case names.
  String _rankToServerString(CardRank rank) {
    switch (rank) {
      case CardRank.ace:
        return 'ace';
      case CardRank.king:
        return 'king';
      case CardRank.queen:
        return 'queen';
      case CardRank.jack:
        return 'jack';
      case CardRank.nine:
        return '9';
      case CardRank.eight:
        return '8';
      case CardRank.seven:
        return '7';
      case CardRank.six:
        return '6';
      case CardRank.five:
        return '5';
      case CardRank.four:
        return '4';
      case CardRank.three:
        return '3';
      case CardRank.two:
        return '2';
    }
  }

  // Build a sorted view for display WITHOUT changing playerHand order (prevents server index mismatch).
  List<int> _getSortedHandIndices() {
    final indices = List<int>.generate(playerHand.length, (i) => i);
    indices.sort((ai, bi) {
      final a = playerHand[ai];
      final b = playerHand[bi];
      if (a.suit.index != b.suit.index) {
        return a.suit.index.compareTo(b.suit.index);
      }
      return a.rank.index.compareTo(b.rank.index);
    });
    return indices;
  }

  CrazyEightsCardComponent? _componentForHandIndex(int handIndex) {
    final displayIdx = playerCardIndexMap.indexOf(handIndex);
    if (displayIdx < 0 || displayIdx >= playerCardComponents.length) return null;
    return playerCardComponents[displayIdx];
  }

  // ===========================================
  // RENDERING
  // ===========================================

  Future<void> _renderCards() async {
    // Remove existing components
    for (var card in playerCardComponents) {
      card.removeFromParent();
    }
    playerCardComponents.clear();
    playerCardIndexMap.clear();

    discardTopComponent?.removeFromParent();
    discardTopComponent = null;

    // Render player hand (sorted for display only)
    final sortedIndices = _getSortedHandIndices();

    final handSpacing = cardWidth * 0.8;
    final totalWidth = (sortedIndices.length - 1) * handSpacing + cardWidth;
    final startX = (screenWidth - totalWidth) / 2 + cardWidth / 2;
    const bottomPadding = 30.0;
    final cardY = screenHeight - (cardHeight / 2) - bottomPadding;

    for (var displayIdx = 0; displayIdx < sortedIndices.length; displayIdx++) {
      final handIndex = sortedIndices[displayIdx];
      final cardX = startX + (displayIdx * handSpacing);

      final cardComp = CrazyEightsCardComponent(
        position: Vector2(cardX, cardY),
        size: Vector2(cardWidth, cardHeight),
        card: playerHand[handIndex],
        onTap: (_) {
          _handleCardTap(handIndex);
        },
      )..priority = layerCards + 10 + displayIdx;

      playerCardComponents.add(cardComp);
      playerCardIndexMap.add(handIndex);
      add(cardComp);
    }

    // Restore selection highlight if possible after rerender
    if (selectedCardIndex != null) {
      final comp = _componentForHandIndex(selectedCardIndex!);
      if (comp != null) {
        selectedCard = comp;
        selectedCard!.setSelected(true);
      } else {
        selectedCard = null;
        selectedCardIndex = null;
        showSuitPicker = false;
      }
    } else {
      selectedCard = null;
      showSuitPicker = false;
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

    // Show loading indicator during server validation
    if (awaitingServerValidation) {
      _drawLoadingOverlay(canvas);
    }
  }

  void _drawGameInfo(Canvas canvas) {
    // Draw count indicator
    if (drawCount > 0) {
      final stackStyle = TextStyle(
        fontFamily: 'Inter',
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
    final dirStyle = TextStyle(
      fontFamily: 'Inter',
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

      final suitStyle = TextStyle(
        fontFamily: 'Inter',
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

    final positions = _calculatePlayerPositions(playerList.length);

    for (var i = 0; i < playerList.length; i++) {
      final player = playerList[i];
      final isActive = currentTurnUserId == player.userId;
      _drawOtherPlayer(canvas, positions[i], player, isActive);
    }
  }

  List<Offset> _calculatePlayerPositions(int count) {
    if (count == 1) {
      return [Offset(screenWidth * 0.5, screenHeight * 0.15)];
    } else if (count == 2) {
      return [
        Offset(screenWidth * 0.2, screenHeight * 0.25),
        Offset(screenWidth * 0.8, screenHeight * 0.25),
      ];
    } else {
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

    final nameStyle = TextStyle(
      fontFamily: 'Inter',
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
      final moreStyle = TextStyle(
        fontFamily: 'Inter',
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
        style: TextStyle(
          fontFamily: 'Inter',
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
        style: TextStyle(
          fontFamily: 'Inter',
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
        style: TextStyle(
          fontFamily: 'Inter',
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

    final titleStyle = TextStyle(
      fontFamily: 'Inter',
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

      final symbolStyle = TextStyle(
        fontFamily: 'Inter',
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

    final titleStyle = TextStyle(
      fontFamily: 'Inter',
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

    final buttonWidth = screenWidth * 0.25;
    final buttonHeight = screenHeight * 0.07;
    final spacing = screenWidth * 0.04;
    final buttonY = screenHeight / 2 + dialogHeight / 4;

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
        style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
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
        style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
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
    final subtitleText = winner == user.username ? '🎉 Congratulations! 🎉' : 'Winner: $winner';

    final textStyle = TextStyle(
      fontFamily: 'Inter',
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

    final subtitleStyle = TextStyle(
      fontFamily: 'Inter',
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

  // NEW: Loading overlay during server validation
  void _drawLoadingOverlay(Canvas canvas) {
    final overlayPaint = Paint()..color = AppColors.primaryNavyDark.withValues(alpha: 0.3);
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), overlayPaint);

    final textStyle = TextStyle(
      fontFamily: 'Inter',
      color: AppColors.textPrimary,
      fontSize: 18 * uiScale,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 4,
          color: AppColors.primaryNavyDark,
          offset: const Offset(1, 1),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: TextSpan(text: 'Sending...', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        screenWidth / 2 - textPainter.width / 2,
        screenHeight * 0.1,
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
        // ✅ FIX: Actually PLAY the selected King/Ace with the chosen suit
        // (Do NOT send chooseSuit as a standalone event here)
        final idx = selectedCardIndex;
        if (idx != null && idx >= 0 && idx < playerHand.length) {
          _playCard(idx, suits[i]);
        } else {
          // Safety fallback
          showSuitPicker = false;
          statusMessage = 'No card selected';
        }
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

    final skipRect = Rect.fromCenter(
      center: Offset(screenWidth / 2 - buttonWidth / 2 - spacing / 2, buttonY),
      width: buttonWidth,
      height: buttonHeight,
    );

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
