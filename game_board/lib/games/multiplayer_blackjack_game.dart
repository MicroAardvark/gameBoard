// lib/games/multiplayer_blackjack_game.dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flame/components.dart';
import '../models/playing_card.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../components/card_component.dart';
import '../components/chip_components.dart';
import '../components/multiplayer_player.dart';
import '../services/socket_service.dart';
import '../components/result_popup_component.dart';
import '../theme/app_theme.dart';
import '../components/text_component.dart';
import '../components/button_component.dart';

/// Server-authoritative multiplayer Blackjack game (up to 3 players + dealer).
///
/// ## Betting flow
/// Betting is turn-based: the server nominates one player at a time to place a
/// bet. Once all players have bet, [allBetsPlaced] is set to true and only the
/// host can start the round via [startRound]. This prevents any player from
/// accidentally dealing cards before everyone is ready.
///
/// ## State management
/// [_setGameState] should always be used instead of assigning [gameState]
/// directly — it ensures the [onGameStateChanged] callback fires so the host
/// Flutter widget (e.g. the bet side menu) can respond correctly.
///
/// ## Socket events
/// All server-driven state changes arrive via [handleSocketEvent]. Turn-related
/// callbacks (`isMyTurn`, `currentTurnPlayerId`) are set BEFORE [_setGameState]
/// is called so that the callback fires with the correct turn context.
class MultiplayerBlackjackGame extends FlameGame implements ChipGameInterface {
  final User user;
  final String roomId;
  final SocketService socketService;
  final Function(GameState)? onGameStateChanged;

  MultiplayerBlackjackGame({
    required this.user,
    required this.roomId,
    required this.socketService,
    this.onGameStateChanged,
  });

  // ─── Layer priorities ─────────────────────────────────────────────────────
  static const int layerBackground = 0;
  static const int layerTable      = 1;
  static const int layerChips      = 2;
  static const int layerCards      = 3;
  static const int layerHud        = 4;
  static const int layerHudPanel   = 5;

  // ─── HUD text components ──────────────────────────────────────────────────
  late CardDeck deck;
  InfoTextComponent? betText;
  InfoTextComponent? gameResultText;
  InfoTextComponent? myHandText;
  InfoTextComponent? dealerHandText;
  InfoTextComponent? turnIndicatorText;
  InfoTextComponent? roomInfoText;
  InfoTextComponent? playerCountText;
  InfoTextComponent? waitingStatusText;

  // ─── Button groups ────────────────────────────────────────────────────────
  // Grouped by game phase so [_showOnlyButtons] can swap them atomically.
  List<GameButton> _waitingBtns  = [];
  List<GameButton> _bettingBtns  = [];
  List<GameButton> _playingBtns  = [];
  List<GameButton> _gameOverBtns = [];

  // ─── Card visuals ─────────────────────────────────────────────────────────
  final List<CardComponent> myCards     = [];
  final List<CardComponent> dealerCards = [];

  /// Remote player HUD components keyed by their server user ID.
  final Map<String, MultiplayerPlayerUI> otherPlayers = {};

  // ─── Chip components ──────────────────────────────────────────────────────
  // In multiplayer the palette is always hidden — betting uses the side menu.
  final List<PaletteChip> paletteChips = [];
  final List<BetChip>     betChips     = [];
  final List<BetChip>     stagedChips  = [];

  // ─── Adaptive sizing ──────────────────────────────────────────────────────
  double get screenWidth   => size.x;
  double get screenHeight  => size.y;
  double get uiScale       => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight    => screenHeight * 0.34 * uiScale;
  double get cardWidth     => cardHeight * 0.68;
  double get chipRadius    => screenWidth * 0.026 * uiScale;
  double get buttonWidth   => screenWidth * 0.15 * uiScale;
  double get buttonHeight  => screenHeight * 0.10 * uiScale;
  double get fontSize      => screenWidth * 0.02 * uiScale;
  double get largeFontSize => screenWidth * 0.028 * uiScale;
  double get hudPanelHeight => size.y * 0.16 * uiScale;
  double get margin        => screenWidth * 0.011 * uiScale;

  double get myCardY    => screenHeight * 0.70;
  double get dealerCardY => screenHeight * 0.22;
  Vector2 get deckPosition  => Vector2(screenWidth / 2, -cardHeight);
  Vector2 get bettingCenter => Vector2(screenWidth / 2, screenHeight / 2);
  double get potRadius  => min(screenWidth, screenHeight) * 0.14 * uiScale;
  Vector2 get stagedCenter => bettingCenter + Vector2(0, potRadius * 1.35);

  final List<double> chipValues = [1, 5, 10, 25, 50, 100];

  // ─── Game state ───────────────────────────────────────────────────────────
  List<PlayingCard> myHand     = [];
  List<PlayingCard> dealerHand = [];
  GameState gameState = GameState.waiting;
  String gameResult   = '';

  double bankroll   = 1000.0;
  double currentBet = 0.0;
  double stagedBet  = 0.0;

  bool _hudInit            = false;
  bool isMyTurn            = false;
  bool isHost              = false;
  String currentTurnPlayerId = '';
  int playerCount          = 1;
  int maxPlayers           = 3;

  /// True once all players in the room have placed their bets.
  /// Only the host can call [startRound] once this is true.
  bool allBetsPlaced = false;

  // ─── Socket subscriptions ─────────────────────────────────────────────────
  StreamSubscription? _gameActionSub;
  StreamSubscription? _newRoundSub;
  StreamSubscription? _gameStartingSub;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    deck     = CardDeck();
    bankroll = user.bankroll.toDouble();

    _createTextComponents();
    _createButtons();
    _setupChips();
    _buildCachedPaintsAndShaders();
    _updateTexts();
    _hudInit = true;

    _setupSocketListeners();

    // Defer initial button visibility update until after the first frame so
    // all components have been added to the scene tree.
    Future.delayed(const Duration(milliseconds: 100), _updateButtonVisibility);
  }

  // ─── HUD construction ─────────────────────────────────────────────────────

  void _createTextComponents() {
    gameResultText = InfoTextComponent(text: '', position: Vector2(20, 20), fontSize: fontSize)
      ..priority = layerHud;
    add(gameResultText!);

    myHandText = InfoTextComponent(text: 'Player Hand', position: Vector2(20, 80), fontSize: fontSize)
      ..priority = layerHud;
    add(myHandText!);

    dealerHandText = InfoTextComponent(text: 'Dealer Hand', position: Vector2(20, 120), fontSize: fontSize)
      ..priority = layerHud;
    add(dealerHandText!);

    // Turn indicator is centred at the top; anchor adjusts its own position.
    turnIndicatorText = InfoTextComponent(text: '', position: Vector2(screenWidth / 2, 160), fontSize: largeFontSize)
      ..priority = layerHud
      ..anchor   = Anchor.center;
    add(turnIndicatorText!);

    waitingStatusText = InfoTextComponent(
      text: 'Waiting for players to ready up...',
      position: Vector2(screenWidth / 2, screenHeight / 2 - 100),
      fontSize: largeFontSize,
    )..priority = layerHud
     ..anchor   = Anchor.center;
    add(waitingStatusText!);

    betText = InfoTextComponent(text: 'Bet: £0', position: Vector2(20, screenHeight - 40), fontSize: fontSize)
      ..priority = layerHud;
    add(betText!);

    // Room ID is truncated to 8 chars to fit comfortably in the corner.
    roomInfoText = InfoTextComponent(text: 'Room: ...', position: Vector2(screenWidth - 20, 20), fontSize: fontSize * 0.7)
      ..priority = layerHud
      ..anchor   = Anchor.topRight;
    add(roomInfoText!);

    playerCountText = InfoTextComponent(text: '0/3', position: Vector2(screenWidth - 20, 40), fontSize: fontSize * 0.8)
      ..priority = layerHud
      ..anchor   = Anchor.topRight;
    add(playerCountText!);
  }

  void _createButtons() {
    final double leftButtonX  = screenWidth * 0.15;
    final double buttonSpacing = screenHeight * 0.10;
    final double startY        = screenHeight * 0.35;

    _waitingBtns = [
      GameButton(
        position: Vector2(screenWidth * 0.5, screenHeight / 2),
        size: Vector2(buttonWidth * 1.5, buttonHeight * 1.2),
        text: 'Ready',
        onTap: () => socketService.playerReady(roomId: roomId, userId: user.id),
      )..priority = layerHudPanel + 1,
    ];

    // Only the Start button is shown for betting in multiplayer — chip palette
    // is replaced by the side bet menu.
    _bettingBtns = [
      GameButton(
        position: Vector2(leftButtonX, startY),
        size: Vector2(buttonWidth, buttonHeight),
        text: 'Start',
        onTap: startRound,
      )..priority = layerHudPanel + 1,
    ];

    _playingBtns = [
      GameButton(position: Vector2(leftButtonX, startY + buttonSpacing),     size: Vector2(buttonWidth, buttonHeight), text: 'Hit',    onTap: hit)        ..priority = layerHudPanel + 1,
      GameButton(position: Vector2(leftButtonX, startY + buttonSpacing * 2), size: Vector2(buttonWidth, buttonHeight), text: 'Stand',  onTap: stand)      ..priority = layerHudPanel + 1,
      GameButton(position: Vector2(leftButtonX, startY + buttonSpacing * 3), size: Vector2(buttonWidth, buttonHeight), text: 'Double', onTap: doubleDown) ..priority = layerHudPanel + 1,
    ];

    _gameOverBtns = [
      GameButton(position: Vector2(leftButtonX, startY + buttonSpacing),     size: Vector2(buttonWidth, buttonHeight), text: 'Next Round', onTap: newRound)   ..priority = layerHudPanel + 1,
      GameButton(position: Vector2(leftButtonX, startY + buttonSpacing * 2), size: Vector2(buttonWidth, buttonHeight), text: 'Leave',      onTap: leaveRoom) ..priority = layerHudPanel + 1,
    ];
  }

  // ─── Button / HUD visibility ──────────────────────────────────────────────

  /// Shows the correct button set for the current [gameState] and hides all
  /// others. Also controls the chip palette and secondary HUD elements.
  void _updateButtonVisibility() {
    updateChipPaletteState();

    switch (gameState) {
      case GameState.waiting:
        _showOnlyButtons(_waitingBtns);
        if (!children.contains(waitingStatusText!)) add(waitingStatusText!);
        turnIndicatorText?.removeFromParent();
        gameResultText?.text = '';

      case GameState.betting:
        waitingStatusText?.removeFromParent();
        if (!children.contains(turnIndicatorText!)) add(turnIndicatorText!);
        gameResultText?.text = '';
        // Start is only available to the host, and only once all bets are in.
        if (isHost && allBetsPlaced && _bettingBtns.isNotEmpty) {
          _showOnlyButtons([_bettingBtns[0]]);
          _bettingBtns[0].isEnabled = currentBet > 0;
          _bettingBtns[0].hidden    = false;
        } else {
          _showOnlyButtons(const []);
        }

      case GameState.playing:
        waitingStatusText?.removeFromParent();
        if (!children.contains(turnIndicatorText!)) add(turnIndicatorText!);
        // Only show action buttons when it is this player's turn.
        _showOnlyButtons(isMyTurn ? _playingBtns : const []);

      case GameState.dealerTurn:
        _showOnlyButtons(const []);
        if (!children.contains(turnIndicatorText!)) add(turnIndicatorText!);

      case GameState.gameOver:
        _showOnlyButtons(_gameOverBtns);
        turnIndicatorText?.removeFromParent();
        if (_gameOverBtns.length >= 2) {
          // "Next Round" is only visible to the host (who controls round starts).
          _gameOverBtns[0].hidden = !isHost;
          _gameOverBtns[1].hidden = false;
        }
    }
  }

  /// Removes all buttons from the scene and adds only those in [needed].
  void _showOnlyButtons(List<GameButton> needed) {
    for (final b in _waitingBtns + _bettingBtns + _playingBtns + _gameOverBtns) {
      if (b.parent != null) b.removeFromParent();
    }
    for (final b in needed) {
      add(b);
      b.hidden    = false;
      b.isEnabled = true;
    }
  }

  /// Updates the turn indicator text and colour to reflect the current phase.
  ///
  /// The indicator changes appearance based on whether it is this player's turn,
  /// another named player's turn, or the dealer's automated turn.
  void _updateTurnIndicator() {
    if (gameState == GameState.waiting) {
      turnIndicatorText?.text = '';
      return;
    }

    if (gameState == GameState.betting) {
      if (isMyTurn && currentBet == 0) {
        _setTurnText('🎯 YOUR TURN TO BET', AppColors.primaryNavyLight, largeFontSize, FontWeight.bold);
      } else if (currentBet > 0) {
        _setTurnText('✅ Bet placed - waiting for others', Colors.yellow, fontSize, FontWeight.normal);
      } else if (currentTurnPlayerId.isNotEmpty) {
        final other = otherPlayers[currentTurnPlayerId];
        if (other != null) {
          _setTurnText('⏳ ${other.username} is betting', Colors.orangeAccent, fontSize, FontWeight.normal);
        } else {
          turnIndicatorText?.text = '';
        }
      }
      return;
    }

    if (isMyTurn) {
      _setTurnText('🎯 YOUR TURN', AppColors.primaryNavyLight, largeFontSize, FontWeight.bold);
    } else if (currentTurnPlayerId.isNotEmpty) {
      final other = otherPlayers[currentTurnPlayerId];
      if (other != null) {
        _setTurnText('⏳ ${other.username}\'s turn', Colors.orangeAccent, largeFontSize, FontWeight.bold);
      } else {
        turnIndicatorText?.text = '';
      }
    } else if (gameState == GameState.dealerTurn) {
      _setTurnText('🎰 Dealer\'s Turn', Colors.redAccent, largeFontSize, FontWeight.bold);
    } else {
      turnIndicatorText?.text = '';
    }
  }

  /// Sets [turnIndicatorText] content and style in a single call.
  void _setTurnText(String text, Color color, double size, FontWeight weight) {
    turnIndicatorText?.text = text;
    turnIndicatorText?.textRenderer = TextPaint(
      style: TextStyle(fontFamily: 'Montserrat', color: color, fontSize: size, fontWeight: weight),
    );
  }

  /// Colours [gameResultText] according to whether the result is a win, push,
  /// or loss so the outcome is immediately clear without reading the text.
  void _updateGameResult(String result, {bool isWin = false}) {
    gameResultText?.text = result;

    Color colour = AppColors.textPrimary;
    final lower  = result.toLowerCase();
    if (lower.contains('win') || lower.contains('blackjack')) {
      colour = AppColors.primaryNavyLight;
    } else if (lower.contains('push')) {
      colour = Colors.yellow;
    } else if (lower.contains('dealer') || lower.contains('bust')) {
      colour = Colors.red;
    }

    gameResultText?.textRenderer = TextPaint(
      style: TextStyle(fontFamily: 'Montserrat', color: colour, fontSize: fontSize, fontWeight: FontWeight.normal),
    );
  }

  void _updateRoomInfo() {
    roomInfoText?.text  = '${roomId.substring(0, 8)}...';
    playerCountText?.text = '$playerCount/$maxPlayers';
  }

  // ─── State management ─────────────────────────────────────────────────────

  /// Sets [gameState] and fires [onGameStateChanged] so the host widget can
  /// respond. Always use this instead of assigning [gameState] directly.
  void _setGameState(GameState newState) {
    gameState = newState;
    onGameStateChanged?.call(newState);
  }

  // ─── Betting (side menu entry point) ──────────────────────────────────────

  /// Called by the Flutter side bet menu when the player confirms a bet amount.
  ///
  /// Validates the bet, deducts it from [bankroll], creates visual chips, and
  /// sends the bet to the server. Only accepted during this player's bet turn.
  void confirmBetFromMenu(double betAmount) {
    if (!isMyTurn || gameState != GameState.betting) return;
    if (betAmount <= 0 || betAmount > bankroll) return;

    bankroll  -= betAmount;
    currentBet = betAmount;

    _createBetChipsVisual(betAmount);
    socketService.placeBet(roomId: roomId, userId: user.id, betAmount: currentBet);

    _updateTexts();
    _updateButtonVisibility();
  }

  /// Decomposes [totalBet] into chip denominations (largest first) and places
  /// the resulting [BetChip] components around the pot circle.
  void _createBetChipsVisual(double totalBet) {
    _clearBetChips();

    double remaining = totalBet;
    final List<double> chips = [];

    for (int i = chipValues.length - 1; i >= 0; i--) {
      while (remaining >= chipValues[i]) {
        chips.add(chipValues[i]);
        remaining -= chipValues[i];
      }
    }

    for (int i = 0; i < chips.length; i++) {
      final chip = BetChip(
        position: _computeChipPosition(i, bettingCenter),
        value: chips[i],
        color: _getChipColor(chips[i]),
      )..priority = layerChips;
      betChips.add(chip);
      add(chip);
    }
  }

  Color _getChipColor(double value) {
    switch (value.toInt()) {
      case 1:   return const Color(0xFFE0E0E0);
      case 5:   return Colors.red;
      case 10:  return Colors.blue;
      case 25:  return AppColors.primaryNavyLight;
      case 50:  return Colors.purple;
      case 100: return AppColors.primaryNavyDark;
      default:  return Colors.grey;
    }
  }

  // ─── Socket setup ─────────────────────────────────────────────────────────

  void _setupSocketListeners() {
    _gameActionSub = socketService.onGameAction.listen(handleSocketEvent);

    _newRoundSub = socketService.onNewRoundStarting.listen((data) {
      allBetsPlaced = false;
      gameResult    = '';
      isMyTurn      = false;

      // Determine who bets first before setting game state, so the callback
      // fires with [isMyTurn] already correct.
      final players = (data['room']?['players'] as List?);
      if (players != null && players.isNotEmpty) {
        currentTurnPlayerId = players[0]['userId'];
        isMyTurn = (currentTurnPlayerId == user.id);
      }

      _setGameState(GameState.betting);
      _updateTexts();
      _updateButtonVisibility();
      _updateTurnIndicator();
    });

    _gameStartingSub = socketService.onGameStarting.listen((data) {
      allBetsPlaced = false;

      final players = (data['room']?['players'] as List?);
      if (players != null && players.isNotEmpty) {
        currentTurnPlayerId = players[0]['userId'];
        isMyTurn = (currentTurnPlayerId == user.id);
      }

      _setGameState(GameState.betting);
      _updateButtonVisibility();
      _updateTurnIndicator();
      _updateTexts();
    });
  }

  // ─── Socket event dispatch ────────────────────────────────────────────────

  void handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data'];

    switch (type) {
      case 'bet_placed':         _handleBetPlaced(data);        break;
      case 'next_player_bet_turn': _handleNextPlayerBetTurn(data); break;
      case 'all_bets_placed':    _handleAllBetsPlaced(data);    break;
      case 'round_started':      _handleRoundStarted(data);     break;
      case 'card_dealt':         _handleCardDealt(data);        break;
      case 'player_busted':      _handlePlayerBusted(data);     break;
      case 'player_stood':       _handlePlayerStood(data);      break;
      case 'next_player_turn':   _handleNextPlayerTurn(data);   break;
      case 'dealer_reveal':      _handleDealerReveal(data);     break;
      case 'dealer_card':        _handleDealerCard(data);       break;
      case 'round_ended':        _handleRoundEnded(data);       break;
      case 'doubled_down':       _handleDoubledDown(data);      break;
      case 'player_blackjack':   _handlePlayerBlackjack(data);  break;
    }
  }

  // ─── Individual event handlers ────────────────────────────────────────────

  void _handleBetPlaced(Map<String, dynamic> data) {
    final userId    = data['userId'];
    final betAmount = data['betAmount'];
    // Update the other player's displayed bet; own bet is already reflected locally.
    if (userId != user.id && otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.updateBet(betAmount.toDouble());
    }
  }

  void _handleNextPlayerBetTurn(Map<String, dynamic> data) {
    final userId = data['userId'];
    currentTurnPlayerId = userId;
    isMyTurn = (userId == user.id);
    // Fire the callback so the side menu shows/hides for the correct player.
    onGameStateChanged?.call(gameState);
    _updateButtonVisibility();
    _updateTurnIndicator();
  }

  void _handleAllBetsPlaced(Map<String, dynamic> data) {
    allBetsPlaced = true;
    // Enables the Start button for the host.
    _updateButtonVisibility();
  }

  /// Processes the full round start payload: deals initial cards for all players
  /// and sets up the first player's turn.
  void _handleRoundStarted(Map<String, dynamic> data) {
    _setGameState(GameState.playing);
    allBetsPlaced = false;

    final gameData = data['room']['gameState']['data'];
    final players  = data['room']['players'] as List;

    for (final card in [...myCards, ...dealerCards]) card.removeFromParent();
    myCards.clear();
    dealerCards.clear();
    myHand.clear();
    dealerHand.clear();

    _createOtherPlayers(players);

    final myHandData = gameData['playerHands'][user.id];
    if (myHandData != null) {
      for (final cardData in myHandData) _addCardToMyHand(cardData, false);
    }

    final dealerHandData = gameData['dealerHand'];
    if (dealerHandData != null) {
      for (final cardData in dealerHandData) {
        _addCardToDealerHand(cardData, cardData['hidden'] ?? false);
      }
    }

    // Show card count labels for other players (hand values are hidden).
    for (final player in players) {
      final id = player['userId'];
      if (id != user.id && otherPlayers.containsKey(id)) {
        final handData = gameData['playerHands'][id];
        if (handData != null) otherPlayers[id]!.setCardCount(handData.length);
      }
    }

    if (players.isNotEmpty) {
      currentTurnPlayerId = players[0]['userId'];
      isMyTurn = (currentTurnPlayerId == user.id);
    }

    _updateCardsPositions();
    _updateTexts();
    _updateButtonVisibility();
    _updateTurnIndicator();
  }

  void _handleCardDealt(Map<String, dynamic> data) {
    final userId   = data['userId'];
    final cardData = data['card'];

    if (userId == user.id) {
      _addCardToMyHand(cardData, false);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.addCard();
    }

    _updateCardsPositions();
    _updateTexts();
  }

  void _handlePlayerBusted(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId == user.id) {
      gameResult = 'Busted!';
      _updateGameResult(gameResult);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Busted');
    }
    _updateTexts();
  }

  void _handlePlayerStood(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (otherPlayers.containsKey(userId)) otherPlayers[userId]!.setStatus('Stood');
  }

  void _handleNextPlayerTurn(Map<String, dynamic> data) {
    final room         = data['room'];
    final players      = room['players'] as List;
    final currentIndex = room['gameState']['currentTurn'] as int;

    if (currentIndex < players.length) {
      currentTurnPlayerId = players[currentIndex]['userId'];
      isMyTurn = (currentTurnPlayerId == user.id);
    } else {
      isMyTurn = false;
      _setGameState(GameState.dealerTurn);
    }

    _updateButtonVisibility();
    _updateTurnIndicator();
    _updateTexts();
  }

  void _handleDealerReveal(Map<String, dynamic> data) {
    _setGameState(GameState.dealerTurn);
    for (final card in dealerCards) {
      if (card.isHidden) card.flip();
    }
    _updateTurnIndicator();
    _updateTexts();
  }

  void _handleDealerCard(Map<String, dynamic> data) {
    _addCardToDealerHand(data['card'], false);
    _updateCardsPositions();
    _updateTexts();
  }

  /// Resolves payouts, shows the result popup, and persists the new bankroll.
  void _handleRoundEnded(Map<String, dynamic> data) {
    _setGameState(GameState.gameOver);
    final results = data['results'];

    if (results.containsKey(user.id)) {
      final myResult = results[user.id];
      final outcome  = myResult['outcome'];
      final payout   = myResult['payout'];

      bankroll += payout.toDouble();

      String mainText, amountText;
      bool   isWin = false;

      switch (outcome) {
        case 'blackjack':
          mainText   = 'BLACKJACK!';
          amountText = '+£${payout.toStringAsFixed(0)}';
          isWin      = true;
          gameResult = 'Blackjack! +£${payout.toStringAsFixed(0)}';
        case 'win':
          mainText   = 'YOU WIN!';
          amountText = '+£${payout.toStringAsFixed(0)}';
          isWin      = true;
          gameResult = 'You win! +£${payout.toStringAsFixed(0)}';
        case 'loss':
          mainText   = 'DEALER WINS';
          amountText = '-£${currentBet.toStringAsFixed(0)}';
          gameResult = 'Dealer wins';
        case 'push':
          mainText   = 'PUSH';
          amountText = '£0';
          gameResult = 'Push';
        default:
          mainText   = outcome.toUpperCase();
          amountText = payout > 0 ? '+£${payout.toStringAsFixed(0)}' : '£0';
          isWin      = payout > 0;
          gameResult = outcome;
      }

      add(ResultPopupComponent(mainText: mainText, amountText: amountText, isWin: isWin));
      _syncBankrollToDatabase();
    }

    currentBet = 0;
    _clearBetChips();
    _updateTexts();
    _updateButtonVisibility();
  }

  /// Persists the updated bankroll to the server after a round ends.
  ///
  /// Fire-and-forget — failures are logged but do not affect the local game.
  Future<void> _syncBankrollToDatabase() async {
    try {
      final response = await http.put(
        Uri.parse('${socketService.baseUrl}/api/game/update-stats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gameType': 'blackjack',
          'bankroll': bankroll,
          'result':   gameResult.contains('win') ? 'win' : 'loss',
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('⚠️ Bankroll sync returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Failed to sync bankroll: $e');
    }
  }

  void _handleDoubledDown(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (otherPlayers.containsKey(userId)) otherPlayers[userId]!.setStatus('Doubled');
  }

  void _handlePlayerBlackjack(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId == user.id) {
      gameResult = 'BLACKJACK!';
      _updateGameResult(gameResult, isWin: true);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Blackjack!');
    }
  }

  // ─── Player actions ───────────────────────────────────────────────────────

  /// Only the host can start the round, and only once all players have bet.
  void startRound() {
    if (!isHost)        return;
    if (currentBet <= 0) return;
    if (!allBetsPlaced) return;
    socketService.startRound(roomId: roomId);
  }

  void hit() {
    if (!isMyTurn || gameState != GameState.playing) return;
    socketService.hit(roomId: roomId, userId: user.id);
  }

  void stand() {
    if (!isMyTurn || gameState != GameState.playing) return;
    socketService.stand(roomId: roomId, userId: user.id);
  }

  void doubleDown() {
    if (!isMyTurn || gameState != GameState.playing) return;
    if (myHand.length != 2) return;
    if (bankroll < currentBet) return;
    socketService.doubleDown(roomId: roomId, userId: user.id);
  }

  void newRound() {
    socketService.playerReadyNextRound(roomId: roomId, userId: user.id);
    _setGameState(GameState.betting);
    gameResult    = '';
    isMyTurn      = false;
    allBetsPlaced = false;

    for (final card in [...myCards, ...dealerCards]) card.removeFromParent();
    myCards.clear();
    dealerCards.clear();
    myHand.clear();
    dealerHand.clear();

    for (final player in otherPlayers.values) {
      player.clearCards();
      player.setStatus('Waiting');
    }

    _updateTexts();
    _updateButtonVisibility();
    _updateTurnIndicator();
  }

  void leaveRoom() => socketService.leaveRoom(roomId: roomId, userId: user.id);

  // ─── Player management ────────────────────────────────────────────────────

  void addOtherPlayer(String playerId, String username, double bankroll, int position) {
    if (otherPlayers.containsKey(playerId)) return;

    // Two other players are placed on the left and right flanks.
    final isRight   = position != 0;
    final anchorPos = isRight
        ? Vector2(screenWidth * 0.92, screenHeight * 0.62)
        : Vector2(screenWidth * 0.08, screenHeight * 0.62);
    final cardsPos  = isRight
        ? Vector2(screenWidth * 0.78, screenHeight * 0.62)
        : Vector2(screenWidth * 0.22, screenHeight * 0.62);

    final player = MultiplayerPlayerUI(
      playerId:    playerId,
      username:    username,
      bankroll:    bankroll,
      anchorPos:   anchorPos,
      cardsCenter: cardsPos,
      cardSize:    Vector2(cardWidth * 0.9, cardHeight * 0.9),
      rightSide:   isRight,
    )..priority = layerHud;

    otherPlayers[playerId] = player;
    add(player);
  }

  void removeOtherPlayer(String playerId) {
    otherPlayers.remove(playerId)?.removeFromParent();
  }

  // ─── Card helpers ─────────────────────────────────────────────────────────

  /// Converts a server rank string to its integer value for [PlayingCard].
  int _getCardValue(String rank) {
    if (rank == 'A') return 11;
    if (['J', 'Q', 'K'].contains(rank)) return 10;
    return int.parse(rank);
  }

  void _addCardToMyHand(Map<String, dynamic> cardData, bool hidden) {
    final card = PlayingCard(cardData['suit'], cardData['rank'], _getCardValue(cardData['rank']));
    myHand.add(card);
    final comp = CardComponent(position: deckPosition.clone(), size: Vector2(cardWidth, cardHeight), card: card, isHidden: hidden)
      ..priority = layerCards + 10;
    myCards.add(comp);
    add(comp);
  }

  void _addCardToDealerHand(Map<String, dynamic> cardData, bool hidden) {
    final card = PlayingCard(cardData['suit'], cardData['rank'], _getCardValue(cardData['rank']));
    dealerHand.add(card);
    final comp = CardComponent(position: deckPosition.clone(), size: Vector2(cardWidth, cardHeight), card: card, isHidden: hidden)
      ..priority = layerCards + 10;
    dealerCards.add(comp);
    add(comp);
  }

  /// Clears and rebuilds the [MultiplayerPlayerUI] for all non-local players.
  ///
  /// Players alternate between left (even index) and right (odd index) positions,
  /// matching the layout used for the two-player case in [addOtherPlayer].
  void _createOtherPlayers(List<dynamic> players) {
    for (final p in otherPlayers.values) p.removeFromParent();
    otherPlayers.clear();

    int otherIndex = 0;
    for (final playerData in players) {
      final id = playerData['userId'] as String;
      if (id == user.id) continue;

      final isRight = otherIndex % 2 == 0;
      final xPos    = isRight ? screenWidth * 0.92 : screenWidth * 0.08;
      final cardsX  = isRight ? screenWidth * 0.78 : screenWidth * 0.22;

      final ui = MultiplayerPlayerUI(
        playerId:    id,
        username:    playerData['username'],
        bankroll:    (playerData['bankroll'] as num?)?.toDouble() ?? 0.0,
        anchorPos:   Vector2(xPos, screenHeight * 0.62),
        cardsCenter: Vector2(cardsX, screenHeight * 0.62),
        cardSize:    Vector2(cardWidth * 0.9, cardHeight * 0.9),
        rightSide:   isRight,
      )..priority = layerHud;

      otherPlayers[id] = ui;
      add(ui);
      otherIndex++;
    }

    playerCount = players.length;
  }

  // ─── Game logic helpers ───────────────────────────────────────────────────

  /// Calculates the best Blackjack hand value, reducing Aces from 11 to 1
  /// as needed to avoid busting.
  int _handValue(List<PlayingCard> hand) {
    int value = 0;
    int aces  = 0;

    for (final card in hand) {
      if (card.rank == 'A') { aces++; value += 11; }
      else { value += card.value; }
    }

    while (value > 21 && aces > 0) { value -= 10; aces--; }
    return value;
  }

  void _updateTexts() {
    if (!_hudInit) return;
    onGameStateChanged?.call(gameState);

    betText?.text = 'Bet: £${currentBet.toStringAsFixed(0)}';
    _updateRoomInfo();

    myHandText?.text = myHand.isNotEmpty
        ? 'Player Hand: ${_handValue(myHand)}'
        : 'Player Hand';

    // Show dealer total only once the hole card has been revealed.
    dealerHandText?.text = dealerHand.isNotEmpty && gameState != GameState.playing
        ? 'Dealer Hand: ${_handValue(dealerHand)}'
        : 'Dealer Hand';
  }

  /// Fans cards symmetrically around the horizontal centre of the screen.
  void _updateCardsPositions() {
    final spacing = cardWidth * 1.15;

    for (int i = 0; i < myCards.length; i++) {
      final offset = (i - (myCards.length - 1) / 2) * spacing;
      myCards[i].position = Vector2(screenWidth / 2 + offset, myCardY);
    }

    for (int i = 0; i < dealerCards.length; i++) {
      final offset = (i - (dealerCards.length - 1) / 2) * spacing;
      dealerCards[i].position = Vector2(screenWidth / 2 + offset, dealerCardY);
    }
  }

  // ─── Chip management (ChipGameInterface) ─────────────────────────────────

  /// Creates [PaletteChip] components but never adds them to the scene —
  /// multiplayer uses the Flutter side menu for betting instead.
  void _setupChips() {
    final double spacing    = max(8.0, chipRadius * 0.20);
    final double btnR       = max(14.0, min(22.0, chipRadius * 0.38));
    final double desiredGap = 2 * btnR;
    final double stride     = (chipRadius * 2) + desiredGap;
    final totalWidth        = stride * chipValues.length;
    final startX            = (screenWidth - totalWidth) / 2 + (stride / 2);
    final chipY             = (screenHeight - hudPanelHeight) - margin * 0.6
                              - (btnR + spacing + chipRadius);

    for (int i = 0; i < chipValues.length; i++) {
      final chip = PaletteChip(
        position:  Vector2(startX + i * stride, chipY),
        radius:    chipRadius,
        value:     chipValues[i],
        chipColor: _getChipColor(chipValues[i]),
        layout:    ButtonsLayout.stackVertical,
        spacing:   spacing,
        minGapAfterButtons: desiredGap,
      )..priority = layerChips;
      paletteChips.add(chip);
      // Deliberately not added to the scene — controlled by updateChipPaletteState.
    }
  }

  /// Removes all palette chips from the scene.
  ///
  /// In multiplayer, the chip palette is permanently hidden in favour of the
  /// Flutter side bet menu, so this is called on every [_updateButtonVisibility].
  void updateChipPaletteState() {
    for (final chip in paletteChips) {
      if (chip.isMounted) chip.removeFromParent();
    }
  }

  @override
  void stageBet({required Vector2 from, required double amount, required Color color}) {
    if (gameState != GameState.betting || bankroll < amount) return;

    bankroll  -= amount;
    stagedBet += amount;

    final chip = BetChip(position: from.clone(), value: amount, color: color)
      ..priority = layerChips;
    stagedChips.add(chip);
    add(chip);
    chip.position = _computeChipPosition(stagedChips.length - 1, stagedCenter);

    _updateTexts();
    _updateButtonVisibility();
  }

  @override
  void removeStagedDenom(double denom) {
    if (gameState != GameState.betting) return;

    final idx = stagedChips.lastIndexWhere((c) => c.value == denom);
    if (idx == -1) return;

    final chip = stagedChips.removeAt(idx);
    bankroll  += chip.value;
    stagedBet -= chip.value;
    chip.removeFromParent();

    for (int i = 0; i < stagedChips.length; i++) {
      stagedChips[i].position = _computeChipPosition(i, stagedCenter);
    }

    _updateTexts();
    _updateButtonVisibility();
  }

  /// Commits staged chips to the pot and sends the bet to the server.
  /// Blocked if it is not this player's betting turn.
  Future<void> confirmStagedToPot() async {
    if (stagedBet <= 0 || !isMyTurn) return;

    currentBet += stagedBet;
    socketService.placeBet(roomId: roomId, userId: user.id, betAmount: currentBet);

    betChips.addAll(stagedChips);
    stagedChips.clear();

    for (int i = 0; i < betChips.length; i++) {
      betChips[i].position = _computeChipPosition(i, bettingCenter);
    }

    stagedBet = 0;
    _updateTexts();
    _updateButtonVisibility();
  }

  void cancelStaged() {
    if (stagedBet <= 0) return;
    bankroll += stagedBet;
    for (final chip in stagedChips) chip.removeFromParent();
    stagedChips.clear();
    stagedBet = 0;
    _updateTexts();
    _updateButtonVisibility();
  }

  void _clearBetChips() {
    for (final chip in betChips) chip.removeFromParent();
    betChips.clear();
  }

  /// Arranges chips in a loose spiral around [center] so stacks remain readable.
  Vector2 _computeChipPosition(int index, Vector2 center) {
    const double radius  = 60;
    const double spacing = 8;
    final angle  = (index * 2 * pi / 8) - pi / 2;
    final offset = Vector2(
      cos(angle) * (radius + (index % 3) * spacing),
      sin(angle) * (radius + (index % 3) * spacing),
    );
    return center + offset;
  }

  // ─── Rendering ────────────────────────────────────────────────────────────

  late Paint outerPaint, potFillPaint, innerBorderPaint, hudPanelPaint;
  Shader? greenGradientShader;

  /// Builds cached [Paint] objects and a green gradient shader for the table felt.
  /// Called on load and must be re-called after resize since the shader references
  /// absolute pixel dimensions.
  void _buildCachedPaintsAndShaders() {
    outerPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    potFillPaint = Paint()
      ..color = const Color(0xFF0F3D1F)
      ..style = PaintingStyle.fill;

    innerBorderPaint = Paint()
      ..color = const Color(0xFF8B4513) // Mahogany table border.
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    hudPanelPaint = Paint()
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    greenGradientShader = const LinearGradient(
      colors: [Color(0xFF0A5A1E), Color(0xFF1A8C3A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, screenWidth, screenHeight));
  }

  @override
  void render(Canvas canvas) {
    // Gradient table felt drawn before super.render so all components appear
    // on top of it.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      Paint()..shader = greenGradientShader,
    );

    canvas.drawCircle(bettingCenter.toOffset(), potRadius, potFillPaint);
    canvas.drawCircle(bettingCenter.toOffset(), potRadius, innerBorderPaint);

    super.render(canvas);
  }

  @override
  void onRemove() {
    _gameActionSub?.cancel();
    _newRoundSub?.cancel();
    _gameStartingSub?.cancel();
    super.onRemove();
  }
}