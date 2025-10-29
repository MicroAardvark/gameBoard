// ====================================
// lib/games/multiplayer_blackjack_game.dart
// Multiplayer Flame game with socket integration - UPDATED WITH TURN-BASED BETTING
// ====================================
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/playing_card.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../components/card_component.dart';
import '../components/chip_components.dart';
import '../components/multiplayer_player.dart';
import '../ui/multiplayer_hud.dart';
import '../services/socket_service.dart';

class MultiplayerBlackjackGame extends FlameGame implements ChipGameInterface {
  final User user;
  final String roomId;
  final SocketService socketService;

  MultiplayerBlackjackGame({
    required this.user,
    required this.roomId,
    required this.socketService,
  });

  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerChips = 2;
  static const int layerCards = 3;
  static const int layerHud = 4;
  static const int layerHudPanel = 5;

  late CardDeck deck;
  late MultiplayerHudManager hud;

  // Cards and hands
  final List<CardComponent> myCards = [];
  final List<CardComponent> dealerCards = [];

  // Other players
  final Map<String, MultiplayerPlayerUI> otherPlayers = {};
  
  // Chips
  final List<PaletteChip> paletteChips = [];
  final List<BetChip> betChips = [];
  final List<BetChip> stagedChips = [];

  // Adaptive sizing
  double get screenWidth => size.x;
  double get screenHeight => size.y;
  double get uiScale => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight => screenHeight * 0.34 * uiScale;
  double get cardWidth => cardHeight * 0.68;
  double get chipRadius => screenWidth * 0.026 * uiScale;
  double get buttonWidth => screenWidth * 0.15 * uiScale;
  double get buttonHeight => screenHeight * 0.10 * uiScale;
  double get fontSize => screenWidth * 0.02 * uiScale;
  double get largeFontSize => screenWidth * 0.028 * uiScale;
  double get hudPanelHeight => size.y * 0.16 * uiScale;
  double get margin => screenWidth * 0.011 * uiScale;

  double get myCardY => screenHeight * 0.70;
  double get dealerCardY => screenHeight * 0.22;
  Vector2 get deckPosition => Vector2(screenWidth / 2, -cardHeight);
  Vector2 get bettingCenter => Vector2(screenWidth / 2, screenHeight / 2);
  double get potRadius => min(screenWidth, screenHeight) * 0.14 * uiScale;
  Vector2 get stagedCenter => bettingCenter + Vector2(0, potRadius * 1.35);

  final List<double> chipValues = [1, 5, 10, 25, 50, 100];

  // Game state
  List<PlayingCard> myHand = [];
  List<PlayingCard> dealerHand = [];
  GameState gameState = GameState.waiting;
  String gameResult = '';
  
  double bankroll = 1000.0;
  double currentBet = 0.0;
  double stagedBet = 0.0;
  
  bool _hudInit = false;
  bool isMyTurn = false;
  bool isHost = false;
  String currentTurnPlayerId = '';
  int playerCount = 1;
  int maxPlayers = 3;
  bool allBetsPlaced = false; // NEW: Track if all bets are placed

  // Socket event subscriptions
  StreamSubscription? _gameActionSub;
  StreamSubscription? _newRoundSub;
  StreamSubscription? _gameStartingSub;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    deck = CardDeck();
    bankroll = user.bankroll.toDouble();

    debugPrint('🎮 [GAME] onLoad - Initial state: $gameState');

    hud = MultiplayerHudManager(this);
    await hud.setupHUD();

    debugPrint('🎮 [GAME] HUD setup complete'); 

    _setupChips();
    _buildCachedPaintsAndShaders();
    _updateHUDTexts();
    _hudInit = true;

    debugPrint('🎮 [GAME] Game state after init: $gameState');

    // Subscribe to socket events
    _setupSocketListeners();
    Future.delayed(Duration(milliseconds: 100), () {
      hud.updateHudVisibility();
    });
  }

  @override
  void onRemove() {
    _gameActionSub?.cancel();
    _newRoundSub?.cancel();
    _gameStartingSub?.cancel();
    super.onRemove();
  }

  // ===========================================
  // SOCKET EVENT HANDLING
  // ===========================================

  int _getCardValue(String rank) {
    if (rank == 'A') return 11;
    if (['J', 'Q', 'K'].contains(rank)) return 10;
    return int.parse(rank);
  }
  
  void _setupSocketListeners() {
    _gameActionSub = socketService.onGameAction.listen((event) {
      handleSocketEvent(event);
    });
    
    _newRoundSub = socketService.onNewRoundStarting.listen((data) {
      debugPrint('🔄 New round starting - all players ready!');
      gameState = GameState.betting;
      allBetsPlaced = false;
      
      // Reset turn state for new betting round
      final room = data['room'];
      if (room != null) {
        final players = room['players'] as List?;
        if (players != null && players.isNotEmpty) {
          // First player starts betting
          currentTurnPlayerId = players[0]['userId'];
          isMyTurn = (currentTurnPlayerId == user.id);
          debugPrint('🎯 Betting starts with: ${players[0]['username']} (isMyTurn: $isMyTurn)');
        }
      }
      
      hud.updateHudVisibility();
      hud.updateTurnIndicator();
    });

    _gameStartingSub = socketService.onGameStarting.listen((data) {
      debugPrint('🎮 Game starting! All players are ready - moving to betting phase');
      gameState = GameState.betting;
      allBetsPlaced = false;
      
      // Initialize turn state - first player's turn
      final room = data['room'];
      if (room != null) {
        final players = room['players'] as List?;
        if (players != null && players.isNotEmpty) {
          currentTurnPlayerId = players[0]['userId'];
          isMyTurn = (currentTurnPlayerId == user.id);
          debugPrint('🎯 First player to bet: ${players[0]['username']} (isMyTurn: $isMyTurn)');
        }
      }
      
      hud.updateHudVisibility();
      hud.updateTurnIndicator();
      _updateHUDTexts();
    });
  }

  void handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data'];

    debugPrint('🎮 Socket event: $type');

    switch (type) {
      case 'bet_placed':
        _handleBetPlaced(data);
        break;
      case 'next_player_bet_turn': // NEW
        _handleNextPlayerBetTurn(data);
        break;
      case 'all_bets_placed': // NEW
        _handleAllBetsPlaced(data);
        break;
      case 'round_started':
        _handleRoundStarted(data);
        break;
      case 'card_dealt':
        _handleCardDealt(data);
        break;
      case 'player_busted':
        _handlePlayerBusted(data);
        break;
      case 'player_stood':
        _handlePlayerStood(data);
        break;
      case 'next_player_turn':
        _handleNextPlayerTurn(data);
        break;
      case 'dealer_reveal':
        _handleDealerReveal(data);
        break;
      case 'dealer_card':
        _handleDealerCard(data);
        break;
      case 'round_ended':
        _handleRoundEnded(data);
        break;
      case 'doubled_down':
        _handleDoubledDown(data);
        break;
      case 'player_blackjack':
        _handlePlayerBlackjack(data);
        break;
    }
  }

  void _handleBetPlaced(Map<String, dynamic> data) {
    final userId = data['userId'];
    final betAmount = data['betAmount'];

    debugPrint('💰 Bet placed: $betAmount by $userId');

    if (userId != user.id && otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.updateBet(betAmount.toDouble());
    }
  }

  // NEW: Handle next player's turn to bet
  void _handleNextPlayerBetTurn(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    debugPrint('➡️ Next player bet turn: $username');
    
    currentTurnPlayerId = userId;
    isMyTurn = (userId == user.id);
    
    if (isMyTurn) {
      debugPrint('🎯 It\'s YOUR turn to bet!');
    }
    
    hud.updateHudVisibility();
    hud.updateTurnIndicator();
  }

  // NEW: Handle all bets placed notification
  void _handleAllBetsPlaced(Map<String, dynamic> data) {
    debugPrint('✅ All bets placed! Host can start the round');
    allBetsPlaced = true;
    
    // Enable start button for host
    hud.updateHudVisibility();
  }

  void _handleRoundStarted(Map<String, dynamic> data) {
    debugPrint('🎲 Round started!');
    
    gameState = GameState.playing;
    allBetsPlaced = false; // Reset for next round
    final room = data['room'];
    final gameData = room['gameState']['data'];
    final players = room['players'] as List;

    // ADDED: Debug logging
    debugPrint('📊 Game Data keys: ${gameData.keys}');
    debugPrint('👥 Players count: ${players.length}');

    // Clear previous cards
    for (final card in myCards) {
      card.removeFromParent();
    }
    for (final card in dealerCards) {
      card.removeFromParent();
    }
    myCards.clear();
    dealerCards.clear();
    myHand.clear();
    dealerHand.clear();

    // Create other player UI components if they don't exist
    _createOtherPlayers(players);

    // Deal my cards
    final myHandData = gameData['playerHands'][user.id];
    debugPrint('🃏 My hand data: $myHandData'); // ADDED
    
    if (myHandData != null) {
      for (final cardData in myHandData) {
        debugPrint('   Adding card: ${cardData['rank']} of ${cardData['suit']}'); // ADDED
        _addCardToMyHand(cardData, false);
      }
      debugPrint('✅ Added ${myCards.length} cards to my hand'); // ADDED
    } else {
      debugPrint('❌ No hand data found for user: ${user.id}'); // ADDED
    }

    // Deal dealer cards
    final dealerHandData = gameData['dealerHand'];
    debugPrint('🎴 Dealer hand data: $dealerHandData'); // ADDED
    
    if (dealerHandData != null) {
      for (final cardData in dealerHandData) {
        final isHidden = cardData['hidden'] ?? false;
        debugPrint('   Adding dealer card: ${cardData['rank']} of ${cardData['suit']} (hidden: $isHidden)'); // ADDED
        _addCardToDealerHand(cardData, isHidden);
      }
      debugPrint('✅ Added ${dealerCards.length} dealer cards'); // ADDED
    } else {
      debugPrint('❌ No dealer hand data found'); // ADDED
    }

    // Deal cards to other players (visual count only)
    for (final player in players) {
      final playerId = player['userId'];
      if (playerId != user.id && otherPlayers.containsKey(playerId)) {
        final playerHandData = gameData['playerHands'][playerId];
        if (playerHandData != null) {
          otherPlayers[playerId]!.setCardCount(playerHandData.length);
        }
      }
    }

    // Set first player's turn
    if (players.isNotEmpty) {
      currentTurnPlayerId = players[0]['userId'];
      isMyTurn = (currentTurnPlayerId == user.id);
      debugPrint('🎯 First turn: ${players[0]['username']} (isMyTurn: $isMyTurn)'); // ADDED
    }

    _updateCardsPositions();
    _updateHUDTexts();
    hud.updateHudVisibility();
    hud.updateTurnIndicator();
    
    debugPrint('🎮 Round started complete. Cards rendered: ${myCards.length + dealerCards.length}'); // ADDED
  }

  void _handleCardDealt(Map<String, dynamic> data) {
    final userId = data['userId'];
    final cardData = data['card'];
    
    debugPrint('🃏 Card dealt to: $userId');

    if (userId == user.id) {
      _addCardToMyHand(cardData, false);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.addCard();
    }

    _updateCardsPositions();
    _updateHUDTexts();
  }

  // UPDATED: Higher priority and debug logging
  void _addCardToMyHand(Map<String, dynamic> cardData, bool hidden) {
    final card = PlayingCard(
      cardData['suit'],
      cardData['rank'],
      _getCardValue(cardData['rank'])
    );
    myHand.add(card);
    
    final cardComp = CardComponent(
      position: deckPosition.clone(),
      size: Vector2(cardWidth, cardHeight),
      card: card,
      isHidden: hidden,
    )..priority = layerCards + 10; // CHANGED: Higher priority
    
    myCards.add(cardComp);
    add(cardComp);
    
    debugPrint('   ✅ Card component added: ${card.rank} of ${card.suit}'); // ADDED
  }

  // UPDATED: Higher priority and debug logging
  void _addCardToDealerHand(Map<String, dynamic> cardData, bool hidden) {
    final card = PlayingCard(
      cardData['suit'],
      cardData['rank'],
      _getCardValue(cardData['rank'])
    );
    dealerHand.add(card);
    
    final cardComp = CardComponent(
      position: deckPosition.clone(),
      size: Vector2(cardWidth, cardHeight),
      card: card,
      isHidden: hidden,
    )..priority = layerCards + 10; // CHANGED: Higher priority
    
    dealerCards.add(cardComp);
    add(cardComp);
    
    debugPrint('   ✅ Dealer card added: ${hidden ? "HIDDEN" : "${card.rank} of ${card.suit}"}'); // ADDED
  }

  // UPDATED: Position players like single-player mock players
  void _createOtherPlayers(List<dynamic> players) {
    // Clear existing
    for (final player in otherPlayers.values) {
      player.removeFromParent();
    }
    otherPlayers.clear();

    int otherPlayerIndex = 0;
    for (final playerData in players) {
      final playerId = playerData['userId'];
      if (playerId == user.id) continue;

      final username = playerData['username'];
      final bankroll = playerData['bankroll']?.toDouble() ?? 0.0;
      
      // Position players on left and right like single player
      final isRightSide = otherPlayerIndex % 2 == 0;
      final xPos = isRightSide ? screenWidth * 0.92 : screenWidth * 0.08;
      final yPos = screenHeight * 0.62;
      final cardsX = isRightSide ? screenWidth * 0.78 : screenWidth * 0.22;

      final playerUI = MultiplayerPlayerUI(
        playerId: playerId,
        username: username,
        bankroll: bankroll,
        anchorPos: Vector2(xPos, yPos),
        cardsCenter: Vector2(cardsX, yPos),
        cardSize: Vector2(cardWidth * 0.9, cardHeight * 0.9),
        rightSide: isRightSide,
      )..priority = layerHud;

      otherPlayers[playerId] = playerUI;
      add(playerUI);
      otherPlayerIndex++;
    }

    playerCount = players.length;
  }

  void _handlePlayerBusted(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    debugPrint('💥 $username busted');
    
    if (userId == user.id) {
      gameResult = 'Busted!';
      hud.updateGameResult(gameResult);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Busted');
    }
    
    _updateHUDTexts();
  }

  void _handlePlayerStood(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    debugPrint('✋ $username stood');
    
    if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Stood');
    }
  }

  void _handleNextPlayerTurn(Map<String, dynamic> data) {
    final room = data['room'];
    final players = room['players'] as List;
    final currentIndex = room['gameState']['currentTurn'];
    
    if (currentIndex < players.length) {
      currentTurnPlayerId = players[currentIndex]['userId'];
      isMyTurn = (currentTurnPlayerId == user.id);
      
      debugPrint('➡️ Next turn: ${players[currentIndex]['username']}');
    } else {
      isMyTurn = false;
      gameState = GameState.dealerTurn;
    }
    
    hud.updateHudVisibility();
    hud.updateTurnIndicator();
    _updateHUDTexts();
  }

  void _handleDealerReveal(Map<String, dynamic> data) {
    debugPrint('👁️ Dealer reveals hidden card');
    
    gameState = GameState.dealerTurn;
    
    for (final cardComp in dealerCards) {
      if (cardComp.isHidden) {
        cardComp.flip();
      }
    }
    
    hud.updateTurnIndicator();
    _updateHUDTexts();
  }

  void _handleDealerCard(Map<String, dynamic> data) {
    final cardData = data['card'];
    
    debugPrint('🎴 Dealer hits');
    
    _addCardToDealerHand(cardData, false);
    _updateCardsPositions();
    _updateHUDTexts();
  }

  void _handleRoundEnded(Map<String, dynamic> data) {
    debugPrint('🏁 Round ended!');
    
    gameState = GameState.gameOver;
    final results = data['results'];
    
    if (results.containsKey(user.id)) {
      final myResult = results[user.id];
      final outcome = myResult['outcome'];
      final payout = myResult['payout'];
      
      bankroll += payout.toDouble();
      
      switch (outcome) {
        case 'blackjack':
          gameResult = 'Blackjack! +£${payout.toStringAsFixed(0)}';
          break;
        case 'win':
          gameResult = 'You win! +£${payout.toStringAsFixed(0)}';
          break;
        case 'loss':
          gameResult = 'Dealer wins';
          break;
        case 'push':
          gameResult = 'Push';
          break;
        default:
          gameResult = outcome;
      }
      
      hud.updateGameResult(gameResult, isWin: outcome == 'win' || outcome == 'blackjack');
      
      _syncBankrollToDatabase();
    }
    
    currentBet = 0;
    _clearBetChips();
    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  Future<void> _syncBankrollToDatabase() async {
    try {
      final response = await http.put(
        Uri.parse('${socketService.baseUrl}/api/game/update-stats'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'gameType': 'blackjack',
          'bankroll': bankroll,
          'result': gameResult.contains('win') ? 'win' : 'loss',
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Bankroll synced to database');
      }
    } catch (e) {
      debugPrint('❌ Failed to sync bankroll: $e');
    }
  }

  void _handleDoubledDown(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    debugPrint('💰x2 $username doubled down');
    
    if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Doubled');
    }
  }

  void _handlePlayerBlackjack(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    debugPrint('🎰 $username has BLACKJACK!');
    
    if (userId == user.id) {
      gameResult = 'BLACKJACK!';
      hud.updateGameResult(gameResult, isWin: true);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Blackjack!');
    }
  }

  // ===========================================
  // CHIP MANAGEMENT - VERTICAL LAYOUT LIKE SINGLE PLAYER
  // ===========================================
  
  void _setupChips() {
    // Vertical layout: (+) above, chip in middle, (-) below
    final double spacing = max(8.0, chipRadius * 0.20);
    final double btnR = max(14.0, min(22.0, chipRadius * 0.38));

    final double desiredGap = 2 * btnR;
    final double stride = (chipRadius * 2) + desiredGap;

    final totalWidth = stride * chipValues.length;
    final startX = (screenWidth - totalWidth) / 2 + (stride / 2);

    final double bottomSafeY = (screenHeight - hudPanelHeight) - margin * 0.6;
    final double chipY = bottomSafeY - (btnR + spacing + chipRadius);

    Color colorFor(double v) {
      switch (v.toInt()) {
        case 1:
          return const Color(0xFFE0E0E0);
        case 5:
          return Colors.red;
        case 10:
          return Colors.blue;
        case 25:
          return Colors.green;
        case 50:
          return Colors.purple;
        case 100:
          return Colors.black;
        default:
          return Colors.grey;
      }
    }

    for (int i = 0; i < chipValues.length; i++) {
      final center = Vector2(startX + i * stride, chipY);
      final chip = PaletteChip(
        position: center,
        radius: chipRadius,
        value: chipValues[i],
        chipColor: colorFor(chipValues[i]),
        layout: ButtonsLayout.stackVertical,
        spacing: spacing,
        minGapAfterButtons: desiredGap,
      )..priority = layerChips;
      paletteChips.add(chip);
      add(chip);
    }
  }

  // ADDED: Method to hide/show chip palette based on game state
  void updateChipPaletteState() {
    final shouldShow = gameState == GameState.betting && isMyTurn;
    
    for (final chip in paletteChips) {
      if (shouldShow) {
        chip.priority = layerChips;
      } else {
        chip.priority = -100; // Hide behind everything
      }
    }
  }

  // ===========================================
  // CHIP GAME INTERFACE IMPLEMENTATION
  // ===========================================
  
  @override
  void stageBet({required Vector2 from, required double amount, required Color color}) {
    if (gameState != GameState.betting) return;
    if (bankroll < amount) return;

    bankroll -= amount;
    stagedBet += amount;

    final chip = BetChip(
      position: from.clone(),
      value: amount,
      color: color,
    )..priority = layerChips;

    stagedChips.add(chip);
    add(chip);

    // Animate to staged area
    final target = _computeChipPosition(stagedChips.length - 1, stagedCenter);
    chip.position = target;

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  @override
  void removeStagedDenom(double denom) {
    if (gameState != GameState.betting) return;

    final idx = stagedChips.lastIndexWhere((c) => c.value == denom);
    if (idx == -1) return;

    final chip = stagedChips[idx];
    stagedChips.removeAt(idx);

    bankroll += chip.value;
    stagedBet -= chip.value;

    chip.removeFromParent();

    for (int i = 0; i < stagedChips.length; i++) {
      stagedChips[i].position = _computeChipPosition(i, stagedCenter);
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  Future<void> confirmStagedToPot() async {
    if (stagedBet <= 0) return;
    
    // 🔧 FIX: Add turn check to prevent out-of-turn betting
    if (!isMyTurn) {
      debugPrint('❌ Cannot confirm bet - not your turn!');
      return;
    }

    currentBet += stagedBet;
    
    socketService.placeBet(
      roomId: roomId,
      userId: user.id,
      betAmount: currentBet,
    );

    for (final chip in stagedChips) {
      betChips.add(chip);
    }
    stagedChips.clear();

    for (int i = 0; i < betChips.length; i++) {
      betChips[i].position = _computeChipPosition(i, bettingCenter);
    }

    stagedBet = 0;
    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void cancelStaged() {
    if (stagedBet <= 0) return;

    bankroll += stagedBet;
    for (final chip in stagedChips) {
      chip.removeFromParent();
    }
    stagedChips.clear();
    stagedBet = 0;
    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void _clearBetChips() {
    for (final chip in betChips) {
      chip.removeFromParent();
    }
    betChips.clear();
  }

  Vector2 _computeChipPosition(int index, Vector2 center) {
    const double radius = 60;
    const double spacing = 8;
    final angle = (index * 2 * pi / 8) - pi / 2;
    final offset = Vector2(
      cos(angle) * (radius + (index % 3) * spacing),
      sin(angle) * (radius + (index % 3) * spacing),
    );
    return center + offset;
  }

  // ===========================================
  // PLAYER ACTIONS
  // ===========================================
  
  void startRound() {
    debugPrint('🔍 startRound called');
    debugPrint('   isHost: $isHost');
    debugPrint('   currentBet: $currentBet');
    debugPrint('   allBetsPlaced: $allBetsPlaced');
    debugPrint('   gameState: $gameState');
    
    if (!isHost){
      debugPrint('❌ Cannot start - not host');
      return;
    }
    if (currentBet <= 0) {
      debugPrint('❌ Cannot start - host has not placed bet');
      return;
    }
    if (!allBetsPlaced) {
      debugPrint('❌ Cannot start - not all players have placed bets');
      return;
    }
    
    debugPrint('🎲 Starting round...');
    socketService.startRound(roomId: roomId);
  }

  void hit() {
    if (!isMyTurn || gameState != GameState.playing) return;
    
    debugPrint('🃏 Hit!');
    socketService.hit(
      roomId: roomId,
      userId: user.id,
    );
  }

  void stand() {
    if (!isMyTurn || gameState != GameState.playing) return;
    
    debugPrint('✋ Stand');
    socketService.stand(
      roomId: roomId,
      userId: user.id,
    );
  }

  void doubleDown() {
    if (!isMyTurn || gameState != GameState.playing) return;
    if (myHand.length != 2) return;
    if (bankroll < currentBet) return;
    
    debugPrint('💰x2 Double down');
    socketService.doubleDown(
      roomId: roomId,
      userId: user.id,
    );
  }

  void newRound() {
    socketService.playerReadyNextRound(
      roomId: roomId,
      userId: user.id,
    );
    
    gameState = GameState.betting;
    gameResult = '';
    isMyTurn = false;
    allBetsPlaced = false;

    for (final card in myCards) {
      card.removeFromParent();
    }
    for (final card in dealerCards) {
      card.removeFromParent();
    }
    myCards.clear();
    dealerCards.clear();
    myHand.clear();
    dealerHand.clear();

    for (final player in otherPlayers.values) {
      player.clearCards();
      player.setStatus('Waiting');
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
    hud.updateTurnIndicator();
  }

  void leaveRoom() {
    socketService.leaveRoom(
      roomId: roomId,
      userId: user.id,
    );
  }

  // ===========================================
  // PLAYER MANAGEMENT
  // ===========================================

  void addOtherPlayer(String playerId, String username, double bankroll, int position) {
    if (otherPlayers.containsKey(playerId)) return;

    Vector2 anchorPos;
    Vector2 cardsCenter;
    bool rightSide = false;

    if (position == 0) {
      anchorPos = Vector2(screenWidth * 0.08, screenHeight * 0.62);
      cardsCenter = Vector2(screenWidth * 0.22, screenHeight * 0.62);
    } else {
      anchorPos = Vector2(screenWidth * 0.92, screenHeight * 0.62);
      cardsCenter = Vector2(screenWidth * 0.78, screenHeight * 0.62);
      rightSide = true;
    }

    final player = MultiplayerPlayerUI(
      playerId: playerId,
      username: username,
      bankroll: bankroll,
      anchorPos: anchorPos,
      cardsCenter: cardsCenter,
      cardSize: Vector2(cardWidth * 0.9, cardHeight * 0.9),
      rightSide: rightSide,
    )..priority = layerHud;

    otherPlayers[playerId] = player;
    add(player);
  }

  void removeOtherPlayer(String playerId) {
    final player = otherPlayers.remove(playerId);
    player?.removeFromParent();
  }

  // ===========================================
  // HELPER METHODS
  // ===========================================
  
  int _handValue(List<PlayingCard> hand) {
    int value = 0;
    int aces = 0;

    for (final card in hand) {
      if (card.rank == 'A') {
        aces++;
        value += 11;
      } else {
        value += card.value;
      }
    }

    while (value > 21 && aces > 0) {
      value -= 10;
      aces--;
    }

    return value;
  }

  void _updateHUDTexts() {
    if (!_hudInit) return;

    hud.bankrollText?.text = 'Bankroll: £${bankroll.toStringAsFixed(0)}';
    hud.betText?.text = 'Bet: £${currentBet.toStringAsFixed(0)} | Staged: £${stagedBet.toStringAsFixed(0)}';
    
    hud.updateRoomInfo(roomId, playerCount, maxPlayers);

    if (myHand.isNotEmpty) {
      hud.myHandText?.text = 'Player Hand: ${_handValue(myHand)}';
    } else {
      hud.myHandText?.text = 'Player Hand';
    }

    if (dealerHand.isNotEmpty && gameState != GameState.playing) {
      hud.dealerHandText?.text = 'Dealer Hand: ${_handValue(dealerHand)}';
    } else {
      hud.dealerHandText?.text = 'Dealer Hand';
    }
  }

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

  // ===========================================
  // RENDERING
  // ===========================================

  late Paint outerPaint, potFillPaint, innerBorderPaint, hudPanelPaint;
  Shader? greenGradientShader;

  void _buildCachedPaintsAndShaders() {
    outerPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    
    potFillPaint = Paint()
      ..color = const Color(0xFF0F3D1F)
      ..style = PaintingStyle.fill;

    innerBorderPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    hudPanelPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    greenGradientShader = const LinearGradient(
      colors: [Color(0xFF0A5A1E), Color(0xFF1A8C3A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, screenWidth, screenHeight));
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..shader = greenGradientShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, screenWidth, screenHeight), bgPaint);

    canvas.drawCircle(
      Offset(bettingCenter.x, bettingCenter.y),
      potRadius,
      potFillPaint,
    );
    canvas.drawCircle(
      Offset(bettingCenter.x, bettingCenter.y),
      potRadius,
      innerBorderPaint,
    );

    super.render(canvas);
  }
}