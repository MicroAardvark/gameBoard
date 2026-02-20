// lib/games/multiplayer_crazy_eights_game.dart
import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/crazy_eights_card_component.dart';
import '../models/crazy_eights_card.dart';
import '../models/user.dart';
import '../screens/multi/multiplayer_crazy_eights_game_screen.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';

/// Server-authoritative multiplayer Crazy Eights game (2-4 players).
///
/// ## Hand order preservation
/// The server tracks each player's hand by index. To prevent the client and
/// server from disagreeing about which card is at position N, [playerHand] is
/// **never sorted or mutated beyond appending**. Cards are presented to the
/// player in a visually sorted order using [_getSortedHandIndices], which
/// produces a display-only index list. [playerCardIndexMap] maps each display
/// slot back to the true [playerHand] index, allowing taps to resolve to the
/// correct server-side card position.
///
/// ## Optimistic UI
/// When the player plays a card, [_playCard] applies the change immediately to
/// [discardPile] and [playerHand] without waiting for the server. The card is
/// stored in [optimisticCard] for rollback. If the server rejects the move
/// (e.g. due to a race condition), [handleCardPlayRejected] reverts the change.
/// When the server confirms via [handleCardPlayed], [optimisticCard] is simply
/// cleared — the discard pile already shows the correct state.
class MultiplayerCrazyEightsGame extends FlameGame with TapCallbacks {
  final User user;
  final String roomId;
  final SocketService socketService;

  MultiplayerCrazyEightsGame({
    required this.user,
    required this.roomId,
    required this.socketService,
  });

  // ─── Layer priorities ─────────────────────────────────────────────────────
  static const int layerBackground = 0;
  static const int layerTable      = 1;
  static const int layerCards      = 2;
  static const int layerHud        = 3;
  static const int layerOverlay    = 4;

  // ─── Core game state ──────────────────────────────────────────────────────
  final List<CrazyEightsCard> discardPile = [];

  /// Active suit override set when a King or Ace is played. Null when the top
  /// card's own suit applies normally.
  CardSuit? currentChosenSuit;

  // ─── Multiplayer state ────────────────────────────────────────────────────
  /// Hand is kept in server-deal order. See class-level docs on hand order.
  final List<CrazyEightsCard> playerHand = [];
  final Map<String, OtherPlayer> otherPlayers = {};

  String? currentTurnUserId;
  bool isMyTurn  = false;
  bool isHost    = false;
  bool isReady   = false;
  int  playerCount = 1;
  GameState gameState = GameState.waiting;

  // ─── Card components ──────────────────────────────────────────────────────
  final List<CrazyEightsCardComponent> playerCardComponents = [];

  /// Maps display slot index → [playerHand] index. Rebuilt every [_renderCards].
  final List<int> playerCardIndexMap = [];

  CrazyEightsCardComponent? discardTopComponent;

  // ─── Game flow ────────────────────────────────────────────────────────────
  String direction = 'clockwise';
  int drawCount    = 0;

  // ─── Crazy Eights call state ──────────────────────────────────────────────
  final Map<String, bool> hasCalledCrazyEights = {};
  bool canChallenge = false;

  /// User ID of the player who failed to call Crazy Eights, or null.
  String? challengeablePlayer;

  // ─── UI state ─────────────────────────────────────────────────────────────
  CrazyEightsCardComponent? selectedCard;

  /// Index in [playerHand] (server order) of the selected card, or null.
  int? selectedCardIndex;

  bool showSuitPicker = false;
  bool showJackChoice = false;
  String? winner;

  // ─── Optimistic UI ────────────────────────────────────────────────────────
  /// True between [_playCard] being called and the server's confirmation or
  /// rejection arriving. Blocks further taps to prevent double-sends.
  bool awaitingServerValidation = false;

  /// The card removed from [playerHand] optimistically, kept for rollback.
  CrazyEightsCard? optimisticCard;

  // ─── Adaptive sizing ──────────────────────────────────────────────────────
  double get screenWidth  => size.x;
  double get screenHeight => size.y;
  double get uiScale  => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight => screenHeight * 0.34 * uiScale;
  double get cardWidth  => cardHeight * 0.68;

  String statusMessage = 'Waiting for players...';

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    super.onLoad();
  }

  // ─── Player management ────────────────────────────────────────────────────

  void addOtherPlayer(String userId, String username, int position) {
    if (!otherPlayers.containsKey(userId)) {
      otherPlayers[userId] = OtherPlayer(userId: userId, username: username, position: position);
    }
  }

  void removeOtherPlayer(String userId) => otherPlayers.remove(userId);

  // ─── Socket event handlers ────────────────────────────────────────────────

  /// Initialises the visual board from the server's game-started payload.
  ///
  /// The hand is stored exactly as the server delivered it (server order) to
  /// ensure card indices remain aligned throughout the game.
  void handleGameStarted(Map<String, dynamic> data) {
    gameState = GameState.playing;
    awaitingServerValidation = false;
    optimisticCard = null;

    final hands    = data['hands'] as Map<String, dynamic>;
    playerHand.clear();
    for (var cardData in hands[user.id] as List) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }

    final gameStateData = data['room']['gameState']['data'];
    discardPile.clear();
    for (var cardData in gameStateData['discardPile'] as List) {
      discardPile.add(CrazyEightsCard.fromMap(cardData));
    }

    currentTurnUserId = gameStateData['currentTurn'];
    isMyTurn = (currentTurnUserId == user.id);

    final chosenSuitStr = gameStateData['chosenSuit'];
    currentChosenSuit = chosenSuitStr != null ? _parseSuit(chosenSuitStr) : null;

    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';

    for (var player in data['room']['players'] as List) {
      final id = player['userId'];
      if (id != user.id && otherPlayers.containsKey(id)) {
        otherPlayers[id]!.cardCount = 7;
      }
    }

    _renderCards();
    statusMessage = isMyTurn ? 'Your turn!' : 'Waiting for ${_getPlayerName(currentTurnUserId)}...';
  }

  /// Handles a card-played broadcast from the server.
  ///
  /// If the card was played by this client, it was already applied optimistically
  /// so only cleanup is needed. For other players, the discard pile is updated
  /// and their card count is decremented.
  void handleCardPlayed(Map<String, dynamic> data) {
    final playerId  = data['userId'];
    final card      = CrazyEightsCard.fromMap(data['card']);
    final chosenSuit = data['chosenSuit'];

    awaitingServerValidation = false;
    optimisticCard = null;

    if (playerId == user.id) {
      // Optimistic state already applied — just clear selection UI.
      selectedCardIndex = null;
      selectedCard = null;
      showSuitPicker = false;
    } else {
      discardPile.add(card);
      if (otherPlayers.containsKey(playerId)) {
        otherPlayers[playerId]!.cardCount = max(0, otherPlayers[playerId]!.cardCount - 1);
      }
    }

    final gameStateData = data['room']['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';

    final suitStr = gameStateData['chosenSuit'];
    currentChosenSuit = suitStr != null ? _parseSuit(suitStr) : null;

    _renderCards();
    statusMessage = '${_getPlayerName(playerId)} played ${card.displayText}';
  }

  /// Rolls back the optimistic update when the server rejects a move.
  ///
  /// The card is re-appended to [playerHand] rather than inserted at its
  /// original index — the exact position within the server-order list is not
  /// material to correctness, only the card's presence matters for future moves.
  void handleCardPlayRejected(Map<String, dynamic> data) {
    if (optimisticCard != null) {
      if (discardPile.isNotEmpty && discardPile.last == optimisticCard) {
        discardPile.removeLast();
      }
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

  /// Synchronises turn state and game flow fields from the server's turn-changed event.
  void handleTurnChanged(Map<String, dynamic> data) {
    currentTurnUserId = data['currentTurn'];
    isMyTurn = (currentTurnUserId == user.id);
    direction = data['direction'] ?? 'clockwise';

    final gameStateData = data['room']['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    final suitStr = gameStateData['chosenSuit'];
    currentChosenSuit = suitStr != null ? _parseSuit(suitStr) : null;

    statusMessage = isMyTurn ? 'Your turn!' : 'Waiting for ${_getPlayerName(currentTurnUserId)}...';

    // Clear stale selection UI when it stops being this player's turn.
    if (!isMyTurn) {
      selectedCard?.setSelected(false);
      selectedCard      = null;
      selectedCardIndex = null;
      showSuitPicker    = false;
      showJackChoice    = false;
    }

    _renderCards();
  }

  void handleSuitChosen(Map<String, dynamic> data) {
    currentChosenSuit = _parseSuit(data['suit']);
    final gameStateData = data['room']['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    _renderCards();
    statusMessage = '${_getPlayerName(data['userId'])} chose ${_getSuitDisplay(currentChosenSuit!)}';
  }

  /// Shows the suit picker when the server confirms the current player must
  /// choose a suit (e.g. after playing a King or Ace).
  void handleChooseSuitRequired(Map<String, dynamic> data) {
    showSuitPicker = true;
    statusMessage  = 'Choose a suit!';
  }

  void handleJackActionChosen(Map<String, dynamic> data) {
    showJackChoice = false;
    direction      = data['direction'];
    final gameStateData = data['room']['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    _renderCards();
    statusMessage = '${_getPlayerName(data['userId'])} chose ${(data['action'] as String).toUpperCase()}';
  }

  void handleChooseJackActionRequired(Map<String, dynamic> data) {
    showJackChoice = true;
    statusMessage  = 'Choose Jack action!';
  }

  /// Updates an opposing player's card count when they draw card(s).
  void handleCardDrawn(Map<String, dynamic> data) {
    final playerId = data['userId'];
    final count    = (data['count'] as num).toInt();

    if (playerId != user.id && otherPlayers.containsKey(playerId)) {
      otherPlayers[playerId]!.cardCount += count;
    }

    final gameStateData = data['room']['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';
    final suitStr = gameStateData['chosenSuit'];
    currentChosenSuit = suitStr != null ? _parseSuit(suitStr) : null;

    _renderCards();
    statusMessage = '${_getPlayerName(playerId)} drew $count card(s)';
  }

  /// Appends newly drawn cards to this player's hand and re-renders.
  void handleCardsDrawn(Map<String, dynamic> data) {
    for (var cardData in data['cards'] as List) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }

    final gameStateData = data['room']['gameState']['data'];
    drawCount = gameStateData['drawCount'] ?? 0;
    direction = gameStateData['direction'] ?? 'clockwise';
    final suitStr = gameStateData['chosenSuit'];
    currentChosenSuit = suitStr != null ? _parseSuit(suitStr) : null;

    _renderCards();
    statusMessage = 'You drew ${(data['cards'] as List).length} card(s)';
  }

  /// Legacy event handler kept for backward compatibility with older server versions.
  void handleCardsReceived(Map<String, dynamic> data) {
    for (var cardData in data['cards'] as List) {
      playerHand.add(CrazyEightsCard.fromMap(cardData));
    }
    _renderCards();
  }

  /// Legacy turn event handler. Superseded by [handleTurnChanged] but retained
  /// for servers that still emit the older event format.
  void handlePlayerTurn(Map<String, dynamic> data) {
    currentTurnUserId = data['userId'];
    isMyTurn          = (currentTurnUserId == user.id);
    statusMessage     = isMyTurn ? 'Your turn!' : '${data['username']}\'s turn';

    if (!isMyTurn) {
      selectedCard?.setSelected(false);
      selectedCard      = null;
      selectedCardIndex = null;
      showSuitPicker    = false;
      showJackChoice    = false;
    }
  }

  void handleCrazyEightsCalled(Map<String, dynamic> data) {
    final playerId = data['userId'];
    hasCalledCrazyEights[playerId] = true;
    if (otherPlayers.containsKey(playerId)) {
      otherPlayers[playerId]!.calledCrazyEights = true;
    }
  }

  /// Opens a 5-second challenge window when a player fails to call Crazy Eights.
  void handleCrazyEightsViolation(Map<String, dynamic> data) {
    canChallenge       = true;
    challengeablePlayer = data['userId'];

    async_timer.Future.delayed(const Duration(seconds: 5), () {
      canChallenge       = false;
      challengeablePlayer = null;
    });
  }

  /// Legacy Jack-choice event handler for older server versions.
  void handleJackChoiceNeeded(Map<String, dynamic> data) {
    if (data['userId'] == user.id) showJackChoice = true;
  }

  void handleGameEnded(Map<String, dynamic> data) {
    gameState = GameState.finished;
    winner    = data['winnerName'];
    statusMessage = data['winnerId'] == user.id ? '🏆 YOU WIN!' : '${data['winnerName']} wins!';
    _renderCards();
  }

  // ─── Player actions ───────────────────────────────────────────────────────

  void _handleCardTap(int handIndex) {
    if (gameState != GameState.playing || !isMyTurn) {
      statusMessage = 'Not your turn!';
      return;
    }

    if (awaitingServerValidation) {
      statusMessage = 'Waiting for server...';
      return;
    }

    if (handIndex < 0 || handIndex >= playerHand.length) return;

    final card     = playerHand[handIndex];
    final cardComp = _componentForHandIndex(handIndex);
    if (cardComp == null) return;

    // Tapping the selected card again deselects it.
    if (selectedCard == cardComp) {
      cardComp.setSelected(false);
      selectedCard      = null;
      selectedCardIndex = null;
      statusMessage     = 'Card deselected';
      return;
    }

    final topCard = discardPile.isNotEmpty ? discardPile.last : null;
    if (topCard != null && !_canPlayCard(card, topCard)) {
      statusMessage = 'Cannot play that card!';
      return;
    }

    selectedCard?.setSelected(false);
    selectedCard      = cardComp;
    selectedCardIndex = handIndex;
    cardComp.setSelected(true);

    statusMessage = card.canChangeSuit
        ? '${card.rankText} selected! Tap discard pile to choose suit'
        : 'Tap discard pile to play ${card.displayText}';
  }

  void _handleDiscardPileTap() {
    if (gameState != GameState.playing || !isMyTurn || awaitingServerValidation) return;
    if (selectedCardIndex == null) return;

    final idx = selectedCardIndex!;
    if (idx < 0 || idx >= playerHand.length) {
      selectedCardIndex = null;
      selectedCard      = null;
      showSuitPicker    = false;
      return;
    }

    final card = playerHand[idx];

    // King/Ace require a suit choice — the actual play happens when the suit
    // is selected via [_handleSuitPickerTap].
    if (card.canChangeSuit) {
      showSuitPicker = true;
      statusMessage  = 'Choose a suit!';
      return;
    }

    _playCard(idx, null);
  }

  /// Applies the optimistic update locally and sends the play to the server.
  ///
  /// [handIndex] is the index into [playerHand] (server order, not display order).
  /// [chosenSuit] is non-null only for King/Ace plays.
  void _playCard(int handIndex, CardSuit? chosenSuit) {
    if (handIndex < 0 || handIndex >= playerHand.length) return;

    final card = playerHand[handIndex];

    // Optimistic update: reflect the play immediately without waiting for the server.
    awaitingServerValidation = true;
    optimisticCard = card;
    playerHand.removeAt(handIndex);
    discardPile.add(card);

    selectedCard?.setSelected(false);
    selectedCard      = null;
    selectedCardIndex = null;
    showSuitPicker    = false;

    _renderCards();
    statusMessage = 'Playing ${card.displayText}...';

    // The server validates and broadcasts the move to all players.
    socketService.playCard(
      roomId:     roomId,
      userId:     user.id,
      cardIndex:  handIndex,
      cardSuit:   card.suit.name,
      // Numbers sent as "2".."10"; faces as "ace", "king", "queen", "jack".
      cardRank:   _rankToServerString(card.rank),
      chosenSuit: chosenSuit?.name,
    );
  }

  void _handleDrawCard() {
    if (gameState != GameState.playing || !isMyTurn || awaitingServerValidation) return;

    selectedCard?.setSelected(false);
    selectedCard      = null;
    selectedCardIndex = null;
    showSuitPicker    = false;

    socketService.drawCard(roomId: roomId, userId: user.id);
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

    socketService.callCrazyEights(roomId: roomId, userId: user.id);
    hasCalledCrazyEights[user.id] = true;
    statusMessage = '🎯 Crazy Eights called!';
  }

  void _handleChallenge() {
    if (!canChallenge || challengeablePlayer == null) return;
    socketService.challengePlayer(
      roomId:      roomId,
      challengerId: user.id,
      targetId:    challengeablePlayer!,
    );
    canChallenge       = false;
    challengeablePlayer = null;
    statusMessage = 'Challenge sent!';
  }

  void _handleJackChoice(String action) {
    socketService.chooseJackAction(roomId: roomId, userId: user.id, action: action);
    showJackChoice = false;
    statusMessage  = '$action action chosen!';
  }

  // ─── Game logic helpers ───────────────────────────────────────────────────

  /// Returns true if [card] can legally be played on [topCard] given the
  /// current game state (draw stack rules, chosen suit override, etc.).
  bool _canPlayCard(CrazyEightsCard card, CrazyEightsCard topCard) {
    // When a draw stack is active, only the matching stacking card is legal.
    if (drawCount > 0) {
      return (topCard.isQueen && card.isQueen) || (topCard.isAce && card.isAce);
    }
    // Kings and Aces can always be played (suit change cards).
    if (card.isKing || card.isAce) return true;
    // Chosen suit from a previous King/Ace overrides the top card's suit.
    if (currentChosenSuit != null && card.suit == currentChosenSuit) return true;
    // Standard rule: match suit or rank.
    return card.suit == topCard.suit || card.rank == topCard.rank;
  }

  CardSuit _parseSuit(String suit) {
    switch (suit) {
      case 'hearts':   return CardSuit.hearts;
      case 'diamonds': return CardSuit.diamonds;
      case 'clubs':    return CardSuit.clubs;
      case 'spades':   return CardSuit.spades;
      default:         return CardSuit.hearts;
    }
  }

  String _getSuitDisplay(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:   return '♥ Hearts';
      case CardSuit.diamonds: return '♦ Diamonds';
      case CardSuit.clubs:    return '♣ Clubs';
      case CardSuit.spades:   return '♠ Spades';
    }
  }

  String _getPlayerName(String? userId) {
    if (userId == null)    return 'Unknown';
    if (userId == user.id) return 'You';
    return otherPlayers[userId]?.username ?? 'Player';
  }

  /// Converts a [CardRank] to the string format expected by the server.
  ///
  /// Number cards use their numeric string ("2".."10"); face cards use
  /// lower-case names ("ace", "king", "queen", "jack").
  String _rankToServerString(CardRank rank) {
    switch (rank) {
      case CardRank.ace:   return 'ace';
      case CardRank.king:  return 'king';
      case CardRank.queen: return 'queen';
      case CardRank.jack:  return 'jack';
      case CardRank.nine:  return '9';
      case CardRank.eight: return '8';
      case CardRank.seven: return '7';
      case CardRank.six:   return '6';
      case CardRank.five:  return '5';
      case CardRank.four:  return '4';
      case CardRank.three: return '3';
      case CardRank.two:   return '2';
    }
  }

  /// Returns a sorted list of [playerHand] indices for display purposes only.
  ///
  /// Sorted by suit then rank. Does NOT mutate [playerHand] — see class docs.
  List<int> _getSortedHandIndices() {
    final indices = List<int>.generate(playerHand.length, (i) => i);
    indices.sort((ai, bi) {
      final a = playerHand[ai];
      final b = playerHand[bi];
      if (a.suit.index != b.suit.index) return a.suit.index.compareTo(b.suit.index);
      return a.rank.index.compareTo(b.rank.index);
    });
    return indices;
  }

  /// Looks up the [CrazyEightsCardComponent] responsible for [handIndex].
  ///
  /// Uses [playerCardIndexMap] since display order differs from hand order.
  CrazyEightsCardComponent? _componentForHandIndex(int handIndex) {
    final displayIdx = playerCardIndexMap.indexOf(handIndex);
    if (displayIdx < 0 || displayIdx >= playerCardComponents.length) return null;
    return playerCardComponents[displayIdx];
  }

  // ─── Rendering ────────────────────────────────────────────────────────────

  /// Rebuilds all card components from the current hand and discard state.
  ///
  /// Cards are displayed in sorted order for readability, but [playerCardIndexMap]
  /// maintains the mapping back to server-order indices so taps resolve correctly.
  /// Selection state is restored after the rebuild using [selectedCardIndex].
  Future<void> _renderCards() async {
    for (var card in playerCardComponents) card.removeFromParent();
    playerCardComponents.clear();
    playerCardIndexMap.clear();
    discardTopComponent?.removeFromParent();
    discardTopComponent = null;

    final sortedIndices = _getSortedHandIndices();
    final handSpacing   = cardWidth * 0.8;
    final totalWidth    = (sortedIndices.length - 1) * handSpacing + cardWidth;
    final startX        = (screenWidth - totalWidth) / 2 + cardWidth / 2;
    final cardY         = screenHeight - (cardHeight / 2) - 30.0;

    for (var di = 0; di < sortedIndices.length; di++) {
      final handIndex = sortedIndices[di];
      final cardComp  = CrazyEightsCardComponent(
        position: Vector2(startX + di * handSpacing, cardY),
        size: Vector2(cardWidth, cardHeight),
        card: playerHand[handIndex],
        onTap: (_) => _handleCardTap(handIndex),
      )..priority = layerCards + 10 + di;

      playerCardComponents.add(cardComp);
      playerCardIndexMap.add(handIndex);
      add(cardComp);
    }

    // Restore the selection highlight on the same card after re-render.
    if (selectedCardIndex != null) {
      final comp = _componentForHandIndex(selectedCardIndex!);
      if (comp != null) {
        selectedCard = comp;
        selectedCard!.setSelected(true);
      } else {
        selectedCard      = null;
        selectedCardIndex = null;
        showSuitPicker    = false;
      }
    } else {
      selectedCard   = null;
      showSuitPicker = false;
    }

    if (discardPile.isNotEmpty) {
      final topCard = discardPile.last;
      discardTopComponent = CrazyEightsCardComponent(
        position: Vector2(screenWidth / 2 + cardWidth * 0.7, screenHeight / 2),
        size: Vector2(cardWidth, cardHeight),
        card: topCard,
        // Show the chosen suit on King/Ace cards so players know the active suit.
        displaySuit: topCard.canChangeSuit ? currentChosenSuit : null,
        onTap: (_) => _handleDiscardPileTap(),
      )..priority = layerCards;
      add(discardTopComponent!);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      Paint()..color = const Color(0xFF1B5E20),
    );

    if (gameState == GameState.playing) {
      _drawGameInfo(canvas);
      _drawOtherPlayers(canvas);
      _drawDrawPile(canvas);
    }

    super.render(canvas);

    if (showSuitPicker) _drawSuitPicker(canvas);
    if (showJackChoice) _drawJackChoice(canvas);
    if (gameState == GameState.finished) _drawGameOver(canvas);

    // Dim overlay to signal that a move has been sent and validation is pending.
    if (awaitingServerValidation) _drawLoadingOverlay(canvas);
  }

  // ─── Game info HUD ────────────────────────────────────────────────────────

  /// Draws the draw stack count, play direction, chosen suit label, and
  /// the Crazy Eights / Challenge action buttons.
  void _drawGameInfo(Canvas canvas) {
    if (drawCount > 0) {
      _paintText(
        canvas,
        text: '🎴 STACK: +$drawCount',
        style: TextStyle(
          fontFamily: 'Inter', color: Colors.redAccent, fontSize: 24 * uiScale,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 6, color: AppColors.primaryNavyDark.withValues(alpha: 0.7), offset: const Offset(2, 2))],
        ),
        offset: Offset(screenWidth * 0.05, screenHeight * 0.15),
      );
    }

    _paintText(
      canvas,
      text: direction == 'clockwise' ? '→ Clockwise' : '← Counter-Clockwise',
      style: TextStyle(fontFamily: 'Inter', color: Colors.amber, fontSize: 18 * uiScale, fontWeight: FontWeight.bold),
      offset: Offset(screenWidth * 0.72, screenHeight * 0.08),
    );

    if (currentChosenSuit != null) {
      _paintText(
        canvas,
        text: 'Suit: ${_getSuitDisplay(currentChosenSuit!)}',
        style: TextStyle(fontFamily: 'Inter', color: _getSuitColor(currentChosenSuit!), fontSize: 16 * uiScale, fontWeight: FontWeight.bold),
        offset: Offset(screenWidth * 0.05, screenHeight * 0.08),
      );
    }

    if (playerHand.length == 1 && hasCalledCrazyEights[user.id] != true) {
      _drawCrazyEightsButton(canvas);
    }

    if (canChallenge) _drawChallengeButton(canvas);
  }

  // ─── Other player rendering ───────────────────────────────────────────────

  void _drawOtherPlayers(Canvas canvas) {
    final playerList = otherPlayers.values.toList();
    if (playerList.isEmpty) return;

    final positions = _calculatePlayerPositions(playerList.length);
    for (var i = 0; i < playerList.length; i++) {
      _drawOtherPlayer(canvas, positions[i], playerList[i], currentTurnUserId == playerList[i].userId);
    }
  }

  /// Positions players evenly across the top of the screen based on headcount.
  List<Offset> _calculatePlayerPositions(int count) {
    if (count == 1) return [Offset(screenWidth * 0.5, screenHeight * 0.15)];
    if (count == 2) return [Offset(screenWidth * 0.2, screenHeight * 0.25), Offset(screenWidth * 0.8, screenHeight * 0.25)];
    return [
      Offset(screenWidth * 0.15, screenHeight * 0.3),
      Offset(screenWidth * 0.5,  screenHeight * 0.15),
      Offset(screenWidth * 0.85, screenHeight * 0.3),
    ];
  }

  /// Renders a single opponent's name, card count, and a fan of face-down card backs.
  void _drawOtherPlayer(Canvas canvas, Offset position, OtherPlayer player, bool isActive) {
    final ceStatus = player.calledCrazyEights && player.cardCount == 1 ? ' 🎯CE' : '';
    _paintText(
      canvas,
      text: '${player.username}\n${player.cardCount} card${player.cardCount != 1 ? 's' : ''}$ceStatus',
      style: TextStyle(
        fontFamily: 'Inter',
        color: isActive ? Colors.amber : AppColors.textPrimary,
        fontSize: 16 * uiScale,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        shadows: [Shadow(blurRadius: 4, color: AppColors.primaryNavyDark.withValues(alpha: 0.7), offset: const Offset(1, 1))],
      ),
      offset: Offset(position.dx, position.dy),
      centreX: true,
    );

    final cardBackSize  = Size(cardWidth * 0.6, cardHeight * 0.6);
    final displayCards  = min(player.cardCount, 5);

    for (var i = 0; i < displayCards; i++) {
      final cardRect = Rect.fromLTWH(
        position.dx - cardBackSize.width / 2 + (i * 5),
        position.dy + 40,
        cardBackSize.width,
        cardBackSize.height,
      );
      final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0B3A79));
      canvas.drawRRect(rrect, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textPrimary.withValues(alpha: 0.5));
    }

    if (player.cardCount > 5) {
      _paintText(
        canvas,
        text: '+${player.cardCount - 5} more',
        style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 12 * uiScale),
        offset: Offset(position.dx, position.dy + 40 + cardBackSize.height + 5),
        centreX: true,
      );
    }
  }

  // ─── Draw pile ────────────────────────────────────────────────────────────

  void _drawDrawPile(Canvas canvas) {
    final deckX  = screenWidth / 2 - cardWidth * 0.7;
    final deckY  = screenHeight / 2;
    final rect   = Rect.fromCenter(center: Offset(deckX, deckY), width: cardWidth, height: cardHeight);
    final rrect  = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0B3A79));

    _paintText(
      canvas,
      text: 'DRAW',
      style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: cardHeight * 0.15, fontWeight: FontWeight.bold),
      offset: Offset(deckX, deckY),
      centreX: true, centreY: true,
    );

    canvas.drawRRect(rrect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.textPrimary.withValues(alpha: 0.5));
  }

  // ─── Action buttons ───────────────────────────────────────────────────────

  void _drawCrazyEightsButton(Canvas canvas) =>
      _drawHudButton(canvas, text: 'CrazyEights!', color: Colors.red,
          cx: screenWidth * 0.85, cy: screenHeight * 0.85);

  void _drawChallengeButton(Canvas canvas) =>
      _drawHudButton(canvas, text: 'Challenge!', color: Colors.orange,
          cx: screenWidth * 0.85, cy: screenHeight * 0.73);

  void _drawHudButton(Canvas canvas, {required String text, required Color color, required double cx, required double cy}) {
    final buttonW = screenWidth * 0.15;
    final buttonH = screenHeight * 0.08;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: buttonW, height: buttonH),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    _paintText(
      canvas,
      text: text,
      style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
      offset: Offset(cx, cy),
      centreX: true, centreY: true,
    );
  }

  // ─── Modal dialogs ────────────────────────────────────────────────────────

  /// Draws the suit picker dialog — identical geometry to the single-player
  /// version so [_handleSuitPickerTap] hit regions match exactly.
  void _drawSuitPicker(Canvas canvas) {
    _drawOverlay(canvas);
    final dialogW = screenWidth * 0.6;
    final dialogH = screenHeight * 0.25;
    _drawDialog(canvas, dialogW, dialogH, title: 'Choose a Suit');

    final buttonSize = screenWidth * 0.11;
    final gap        = screenWidth * 0.02;
    final totalWidth = buttonSize * 4 + gap * 3;
    final startX     = screenWidth / 2 - totalWidth / 2;
    final buttonY    = screenHeight / 2 + dialogH / 4;

    final suits = [
      {'symbol': '♥', 'color': const Color(0xFFE53935)},
      {'symbol': '♦', 'color': const Color(0xFFE53935)},
      {'symbol': '♣', 'color': AppColors.primaryNavyDark},
      {'symbol': '♠', 'color': AppColors.primaryNavyDark},
    ];

    for (var i = 0; i < 4; i++) {
      final x      = startX + i * (buttonSize + gap);
      final rrect  = RRect.fromRectAndRadius(Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize), const Radius.circular(12));
      canvas.drawRRect(rrect, Paint()..color = Colors.grey.shade200);
      canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = AppColors.primaryNavyDark.withValues(alpha: 0.3));
      _paintText(
        canvas,
        text: suits[i]['symbol'] as String,
        style: TextStyle(fontFamily: 'Inter', color: suits[i]['color'] as Color, fontSize: buttonSize * 0.5, fontWeight: FontWeight.bold),
        offset: Offset(x + buttonSize / 2, buttonY),
        centreX: true, centreY: true,
      );
    }
  }

  void _drawJackChoice(Canvas canvas) {
    _drawOverlay(canvas);
    final dialogW = screenWidth * 0.65;
    final dialogH = screenHeight * 0.22;
    _drawDialog(canvas, dialogW, dialogH, title: 'Choose Jack Action');

    final buttonW = screenWidth * 0.25;
    final buttonH = screenHeight * 0.07;
    final spacing = screenWidth * 0.04;
    final buttonY = screenHeight / 2 + dialogH / 4;

    _drawDialogButton(canvas, text: 'Skip Next', color: Colors.blue,
        cx: screenWidth / 2 - buttonW / 2 - spacing / 2, cy: buttonY, w: buttonW, h: buttonH);
    _drawDialogButton(canvas, text: 'Reverse',   color: Colors.orange,
        cx: screenWidth / 2 + buttonW / 2 + spacing / 2, cy: buttonY, w: buttonW, h: buttonH);
  }

  void _drawGameOver(Canvas canvas) {
    _drawOverlay(canvas, alpha: 0.8);
    final isWin    = winner == user.username;
    final mainText = isWin ? 'YOU WIN!' : 'YOU LOSE!';
    final subText  = isWin ? '🎉 Congratulations! 🎉' : 'Winner: $winner';

    _paintText(
      canvas,
      text: mainText,
      style: TextStyle(fontFamily: 'Inter', color: isWin ? AppColors.primaryNavyLight : Colors.redAccent,
          fontSize: 48 * uiScale, fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 10, color: AppColors.primaryNavyDark, offset: const Offset(2, 2))]),
      offset: Offset(screenWidth / 2, screenHeight / 2 - 30),
      centreX: true, centreY: true,
    );

    _paintText(
      canvas,
      text: subText,
      style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 20 * uiScale),
      offset: Offset(screenWidth / 2, screenHeight / 2 + 50),
      centreX: true,
    );
  }

  /// Light overlay shown while waiting for the server to validate the last move.
  void _drawLoadingOverlay(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight),
        Paint()..color = AppColors.primaryNavyDark.withValues(alpha: 0.3));
    _paintText(
      canvas,
      text: 'Sending...',
      style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 18 * uiScale, fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: AppColors.primaryNavyDark, offset: const Offset(1, 1))]),
      offset: Offset(screenWidth / 2, screenHeight * 0.1),
      centreX: true,
    );
  }

  // ─── Drawing helpers ──────────────────────────────────────────────────────

  Color _getSuitColor(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:
      case CardSuit.diamonds: return const Color(0xFFE53935);
      case CardSuit.clubs:
      case CardSuit.spades:   return AppColors.primaryNavyDark;
    }
  }

  void _drawOverlay(Canvas canvas, {double alpha = 0.7}) {
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight),
        Paint()..color = AppColors.primaryNavyDark.withValues(alpha: alpha));
  }

  void _drawDialog(Canvas canvas, double w, double h, {required String title}) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(screenWidth / 2, screenHeight / 2), width: w, height: h),
      const Radius.circular(20),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.textPrimary);
    _paintText(
      canvas,
      text: title,
      style: TextStyle(fontFamily: 'Inter', color: AppColors.primaryNavyDark, fontSize: 20 * uiScale, fontWeight: FontWeight.bold),
      offset: Offset(screenWidth / 2, screenHeight / 2 - h / 2 + 15),
      centreX: true,
    );
  }

  void _drawDialogButton(Canvas canvas, {required String text, required Color color, required double cx, required double cy, required double w, required double h}) {
    final rrect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), const Radius.circular(12));
    canvas.drawRRect(rrect, Paint()..color = color);
    _paintText(
      canvas,
      text: text,
      style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
      offset: Offset(cx, cy),
      centreX: true, centreY: true,
    );
  }

  /// Shared text painter. Centres horizontally and/or vertically when requested.
  void _paintText(Canvas canvas, {required String text, required TextStyle style, required Offset offset, bool centreX = false, bool centreY = false, double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: centreX ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: maxWidth ?? double.infinity);

    canvas.drawText(
      painter,
      Offset(
        centreX ? offset.dx - painter.width / 2 : offset.dx,
        centreY ? offset.dy - painter.height / 2 : offset.dy,
      ),
    );
  }

  // ─── Input handling ───────────────────────────────────────────────────────

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
    final gap        = screenWidth * 0.02;
    final totalWidth = buttonSize * 4 + gap * 3;
    final startX     = screenWidth / 2 - totalWidth / 2;
    final buttonY    = screenHeight / 2 + screenHeight * 0.25 / 4;
    final suits      = [CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs, CardSuit.spades];

    for (var i = 0; i < 4; i++) {
      final x = startX + i * (buttonSize + gap);
      if (Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize).contains(position)) {
        final idx = selectedCardIndex;
        if (idx != null && idx >= 0 && idx < playerHand.length) {
          _playCard(idx, suits[i]);
        } else {
          showSuitPicker = false;
          statusMessage  = 'No card selected';
        }
        return;
      }
    }
  }

  void _handleJackChoiceTap(Offset position) {
    final buttonW = screenWidth * 0.25;
    final buttonH = screenHeight * 0.07;
    final spacing = screenWidth * 0.04;
    final buttonY = screenHeight / 2 + screenHeight * 0.22 / 4;

    final skipRect    = Rect.fromCenter(center: Offset(screenWidth / 2 - buttonW / 2 - spacing / 2, buttonY), width: buttonW, height: buttonH);
    final reverseRect = Rect.fromCenter(center: Offset(screenWidth / 2 + buttonW / 2 + spacing / 2, buttonY), width: buttonW, height: buttonH);

    if (skipRect.contains(position))    { _handleJackChoice('skip'); }
    else if (reverseRect.contains(position)) { _handleJackChoice('reverse'); }
  }

  /// Handles taps on the main game area: draw pile, Crazy Eights button, or
  /// the challenge button (when a challenge window is open).
  void _handleGameTap(Offset position) {
    final deckRect = Rect.fromCenter(
      center: Offset(screenWidth / 2 - cardWidth * 0.7, screenHeight / 2),
      width: cardWidth, height: cardHeight,
    );
    if (deckRect.contains(position)) { _handleDrawCard(); return; }

    if (playerHand.length == 1 && hasCalledCrazyEights[user.id] != true) {
      final ceRect = Rect.fromCenter(
        center: Offset(screenWidth * 0.85, screenHeight * 0.85),
        width: screenWidth * 0.15, height: screenHeight * 0.08,
      );
      if (ceRect.contains(position)) { _handleCrazyEightsCall(); return; }
    }

    if (canChallenge) {
      final challengeRect = Rect.fromCenter(
        center: Offset(screenWidth * 0.85, screenHeight * 0.73),
        width: screenWidth * 0.15, height: screenHeight * 0.08,
      );
      if (challengeRect.contains(position)) { _handleChallenge(); return; }
    }
  }
}

// ─── Canvas extension ─────────────────────────────────────────────────────────

extension _CanvasTextPainter on Canvas {
  void drawText(TextPainter painter, Offset offset) => painter.paint(this, offset);
}

// ─── Other player model ───────────────────────────────────────────────────────

/// Lightweight data model for a remote player.
///
/// Used purely for rendering — no game logic lives here.
class OtherPlayer {
  final String userId;
  final String username;
  final int    position;
  int  cardCount;
  bool isReady;
  bool calledCrazyEights;

  OtherPlayer({
    required this.userId,
    required this.username,
    required this.position,
    this.cardCount         = 7,
    this.isReady           = false,
    this.calledCrazyEights = false,
  });

  void setReady(bool ready) => isReady = ready;
}