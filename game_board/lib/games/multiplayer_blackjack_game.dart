// ====================================
// lib/games/multiplayer_blackjack_game.dart
// Multiplayer Flame game with socket integration
// ====================================
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../models/playing_card.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../components/card_component.dart';
import '../components/chip_components.dart';
import '../components/multiplayer_player.dart';
import '../ui/multiplayer_hud.dart';
import '../services/socket_service.dart';

class MultiplayerBlackjackGame extends FlameGame {
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
  GameState gameState = GameState.betting;
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

  // Socket event subscriptions
  StreamSubscription? _gameActionSub;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    deck = CardDeck();
    bankroll = user.bankroll.toDouble();

    hud = MultiplayerHudManager(this);
    hud.setupHUD();

    _setupChips();
    _buildCachedPaintsAndShaders();
    _updateHUDTexts();
    _hudInit = true;

    // Subscribe to socket events
    _setupSocketListeners();
  }

  @override
  void onRemove() {
    _gameActionSub?.cancel();
    super.onRemove();
  }

  // ===========================================
  // SOCKET EVENT HANDLING
  // ===========================================
  
  void _setupSocketListeners() {
    _gameActionSub = socketService.onGameAction.listen((event) {
      handleSocketEvent(event);
    });
  }

  void handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data'];

    print('🎮 Socket event: $type');

    switch (type) {
      case 'bet_placed':
        _handleBetPlaced(data);
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

    print('💰 Bet placed: $betAmount by $userId');

    // Update other player's bet display
    if (userId != user.id && otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.updateBet(betAmount.toDouble());
    }
  }

  void _handleRoundStarted(Map<String, dynamic> data) {
    print('🎲 Round started!');
    
    gameState = GameState.playing;
    final room = data['room'];
    final gameData = room['gameState']['data'];

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

    // Deal my cards
    final myHandData = gameData['playerHands'][user.id];
    if (myHandData != null) {
      for (final cardData in myHandData) {
        final card = PlayingCard(
          suit: cardData['suit'],
          rank: cardData['rank'],
        );
        myHand.add(card);
        
        final cardComp = CardComponent(
          position: deckPosition,
          size: Vector2(cardWidth, cardHeight),
          card: card,
          isHidden: false,
        )..priority = layerCards;
        myCards.add(cardComp);
        add(cardComp);
      }
    }

    // Deal dealer cards
    final dealerHandData = gameData['dealerHand'];
    if (dealerHandData != null) {
      for (final cardData in dealerHandData) {
        final card = PlayingCard(
          suit: cardData['suit'],
          rank: cardData['rank'],
        );
        dealerHand.add(card);
        
        final cardComp = CardComponent(
          position: deckPosition,
          size: Vector2(cardWidth, cardHeight),
          card: card,
          isHidden: cardData['hidden'] ?? false,
        )..priority = layerCards;
        dealerCards.add(cardComp);
        add(cardComp);
      }
    }

    // Update other players' card counts
    final players = room['players'] as List;
    for (final player in players) {
      final playerId = player['userId'];
      if (playerId != user.id && otherPlayers.containsKey(playerId)) {
        final playerHandData = gameData['playerHands'][playerId];
        if (playerHandData != null) {
          otherPlayers[playerId]!.setCardCount(playerHandData.length);
        }
      }
    }

    // Position cards
    _updateCardsPositions();
    
    // Check whose turn it is
    final currentIndex = room['gameState']['currentTurn'];
    if (currentIndex < players.length) {
      currentTurnPlayerId = players[currentIndex]['userId'];
      isMyTurn = (currentTurnPlayerId == user.id);
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
    hud.updateTurnIndicator();
  }

  void _handleCardDealt(Map<String, dynamic> data) {
    final userId = data['userId'];
    final cardData = data['card'];
    
    print('🃏 Card dealt to: $userId');
    
    if (userId == user.id) {
      // Card dealt to me
      final card = PlayingCard(
        suit: cardData['suit'],
        rank: cardData['rank'],
      );
      myHand.add(card);
      
      final cardComp = CardComponent(
        position: deckPosition,
        size: Vector2(cardWidth, cardHeight),
        card: card,
        isHidden: false,
      )..priority = layerCards;
      myCards.add(cardComp);
      add(cardComp);
      
      _updateCardsPositions();
    } else if (otherPlayers.containsKey(userId)) {
      // Card dealt to other player
      otherPlayers[userId]!.addCard();
    }
    
    _updateHUDTexts();
  }

  void _handlePlayerBusted(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    print('💥 $username busted!');
    
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
    
    print('✋ $username stood');
    
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
      
      print('➡️ Next turn: ${players[currentIndex]['username']}');
    } else {
      isMyTurn = false;
      gameState = GameState.dealerTurn;
    }
    
    hud.updateHudVisibility();
    hud.updateTurnIndicator();
    _updateHUDTexts();
  }

  void _handleDealerReveal(Map<String, dynamic> data) {
    print('👁️ Dealer reveals hidden card');
    
    gameState = GameState.dealerTurn;
    
    // Reveal all dealer cards
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
    
    print('🎴 Dealer hits');
    
    final card = PlayingCard(
      suit: cardData['suit'],
      rank: cardData['rank'],
    );
    dealerHand.add(card);
    
    final cardComp = CardComponent(
      position: deckPosition,
      size: Vector2(cardWidth, cardHeight),
      card: card,
      isHidden: false,
    )..priority = layerCards;
    dealerCards.add(cardComp);
    add(cardComp);
    
    _updateCardsPositions();
    _updateHUDTexts();
  }

  void _handleRoundEnded(Map<String, dynamic> data) {
    print('🏁 Round ended!');
    
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
    }
    
    currentBet = 0;
    _clearBetChips();
    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void _handleDoubledDown(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    print('💰x2 $username doubled down');
    
    if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Doubled');
    }
  }

  void _handlePlayerBlackjack(Map<String, dynamic> data) {
    final userId = data['userId'];
    final username = data['username'];
    
    print('🎰 $username has BLACKJACK!');
    
    if (userId == user.id) {
      gameResult = 'BLACKJACK!';
      hud.updateGameResult(gameResult, isWin: true);
    } else if (otherPlayers.containsKey(userId)) {
      otherPlayers[userId]!.setStatus('Blackjack!');
    }
  }

  // ===========================================
  // CHIP MANAGEMENT
  // ===========================================
  
  void _setupChips() {
    const double baseX = 50;
    final double startY = screenHeight * 0.85;
    const double horizontalSpacing = 90;
    const double verticalSpacing = 30;

    for (int i = 0; i < chipValues.length; i++) {
      final value = chipValues[i];
      final x = baseX + (i * horizontalSpacing);

      final plusBtn = ChipButton(
        position: Vector2(x, startY - verticalSpacing),
        radius: chipRadius * 0.5,
        label: '+',
        onTap: () => _addChipToStaging(value),
      )..priority = layerChips;

      final chip = PaletteChip(
        position: Vector2(x, startY),
        radius: chipRadius,
        value: value,
        onTap: () => _addChipToStaging(value),
      )..priority = layerChips;

      final minusBtn = ChipButton(
        position: Vector2(x, startY + verticalSpacing),
        radius: chipRadius * 0.5,
        label: '-',
        onTap: () => _removeChipFromStaging(value),
      )..priority = layerChips;

      add(plusBtn);
      add(chip);
      add(minusBtn);
      paletteChips.add(chip);
    }
  }

  void _addChipToStaging(double value) {
    if (gameState != GameState.betting) return;
    if (bankroll < value) return;

    bankroll -= value;
    stagedBet += value;

    final position = _computeChipPosition(stagedChips.length, stagedCenter);
    final chip = BetChip(
      position: position,
      radius: chipRadius,
      value: value,
    )..priority = layerChips;

    stagedChips.add(chip);
    add(chip);
    _updateHUDTexts();
  }

  void _removeChipFromStaging(double value) {
    if (gameState != GameState.betting) return;
    if (stagedChips.isEmpty) return;

    for (int i = stagedChips.length - 1; i >= 0; i--) {
      if (stagedChips[i].value == value) {
        bankroll += value;
        stagedBet -= value;
        stagedChips[i].removeFromParent();
        stagedChips.removeAt(i);
        _updateHUDTexts();
        return;
      }
    }
  }

  Future<void> confirmStagedToPot() async {
    if (stagedBet <= 0) return;

    currentBet += stagedBet;
    
    // Send bet to server
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
    if (!isHost) return;
    if (currentBet <= 0) return;
    
    print('🎲 Starting round...');
    socketService.startRound(roomId: roomId);
  }

  void hit() {
    if (!isMyTurn || gameState != GameState.playing) return;
    
    print('🃏 Hit!');
    socketService.hit(
      roomId: roomId,
      userId: user.id,
    );
  }

  void stand() {
    if (!isMyTurn || gameState != GameState.playing) return;
    
    print('✋ Stand');
    socketService.stand(
      roomId: roomId,
      userId: user.id,
    );
  }

  void doubleDown() {
    if (!isMyTurn || gameState != GameState.playing) return;
    if (myHand.length != 2) return;
    if (bankroll < currentBet) return;
    
    print('💰x2 Double down');
    socketService.doubleDown(
      roomId: roomId,
      userId: user.id,
    );
  }

  void newRound() {
    gameState = GameState.betting;
    gameResult = '';
    isMyTurn = false;

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

    // Clear other players' cards
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
      hud.myHandText?.text = 'Your Hand: ${_handValue(myHand)}';
    } else {
      hud.myHandText?.text = 'Your Hand';
    }

    if (dealerHand.isNotEmpty && gameState != GameState.playing) {
      hud.dealerHandText?.text = 'Dealer: ${_handValue(dealerHand)}';
    } else if (dealerHand.isNotEmpty) {
      // During play, only show visible cards
      final visibleCards = dealerCards.where((c) => !c.isHidden).map((c) => c.card).toList();
      hud.dealerHandText?.text = 'Dealer: ${_handValue(visibleCards)}';
    } else {
      hud.dealerHandText?.text = 'Dealer Hand';
    }
  }

  void _updateCardsPositions({bool animated = true}) {
    final spacing = cardWidth * 1.15;

    // My cards
    for (int i = 0; i < myCards.length; i++) {
      final offset = (i - (myCards.length - 1) / 2) * spacing;
      myCards[i].position = Vector2(screenWidth / 2 + offset, myCardY);
    }

    // Dealer cards
    for (int i = 0; i < dealerCards.length; i++) {
      final offset = (i - (dealerCards.length - 1) / 2) * spacing;
      dealerCards[i].position = Vector2(screenWidth / 2 + offset, dealerCardY);
    }
  }

  // ===========================================
  // RENDERING
  // ===========================================
  
  late Paint outerPaint, potFillPaint, innerBorderPaint;
  
  void _buildCachedPaintsAndShaders() {
    outerPaint = Paint()
      ..color = Colors.amber[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    potFillPaint = Paint()
      ..color = Colors.green[900]!.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    innerBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw table felt
    final feltRect = Rect.fromLTWH(0, 0, screenWidth, screenHeight);
    final feltPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.green[900]!,
          Colors.green[700]!,
        ],
      ).createShader(feltRect);
    canvas.drawRect(feltRect, feltPaint);

    // Draw betting area
    canvas.drawCircle(bettingCenter.toOffset(), potRadius, potFillPaint);
    canvas.drawCircle(bettingCenter.toOffset(), potRadius, outerPaint);
    canvas.drawCircle(bettingCenter.toOffset(), potRadius * 0.85, innerBorderPaint);
  }

  // Add other players dynamically
  void addOtherPlayer(String playerId, String username, double bankroll, int position) {
    if (otherPlayers.containsKey(playerId)) return;

    Vector2 anchorPos;
    Vector2 cardsCenter;
    bool rightSide = false;

    // Position players around the table
    if (position == 0) {
      // Left player
      anchorPos = Vector2(screenWidth * 0.08, screenHeight * 0.62);
      cardsCenter = Vector2(screenWidth * 0.22, screenHeight * 0.62);
    } else {
      // Right player
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
}