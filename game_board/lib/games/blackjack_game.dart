// ====================================
// lib/games/blackjack_game.dart
// Single-player blackjack game with betting side menu support - UPDATED
// ====================================
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/card_component.dart';
import '../components/chip_components.dart';
import '../models/playing_card.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../ui/hud.dart';

class BlackjackGame extends FlameGame implements ChipGameInterface {
  final User user;
  final Function(GameState)? onGameStateChanged; // NEW: Callback for state changes

  BlackjackGame({
    required this.user,
    this.onGameStateChanged, // NEW: Optional callback
  });

  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerChips = 2;
  static const int layerCards = 3;
  static const int layerHud = 4;
  static const int layerHudPanel = 5;

  late CardDeck deck;
  late HudManager hud;

  // Cards
  final List<CardComponent> playerCards = [];
  final List<CardComponent> dealerCards = [];

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
  double get hudPanelHeight => screenHeight * 0.15 * uiScale;
  double get chipRadius => screenWidth * 0.026 * uiScale;
  double get buttonWidth => screenWidth * 0.15 * uiScale;
  double get buttonHeight => screenHeight * 0.10 * uiScale;
  double get fontSize => screenWidth * 0.02 * uiScale;
  double get largeFontSize => screenWidth * 0.028 * uiScale;
  double get margin => screenWidth * 0.011 * uiScale;

  double get playerCardY => screenHeight * 0.70;
  double get dealerCardY => screenHeight * 0.22;
  Vector2 get deckPosition => Vector2(screenWidth / 2, -cardHeight);

  Vector2 get bettingCenter => Vector2(screenWidth / 2, screenHeight / 2);
  double get potRadius => min(screenWidth, screenHeight) * 0.14 * uiScale;
  Vector2 get stagedCenter => bettingCenter + Vector2(0, potRadius * 1.35);

  final List<double> chipValues = [1, 5, 10, 25, 50, 100];

  // Game state
  List<PlayingCard> playerHand = [];
  List<PlayingCard> dealerHand = [];
  GameState _gameState = GameState.betting;
  String gameResult = '';
  int playerWins = 0;
  int dealerWins = 0;

  // NEW: Getter and setter for game state with callback
  GameState get gameState => _gameState;
  set gameState(GameState newState) {
    _gameState = newState;
    onGameStateChanged?.call(newState); // Notify the screen
  }

  // Bankroll & betting
  double bankroll = 1000.0;
  double currentBet = 0.0;
  double stagedBet = 0.0;

  bool _hudInit = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    deck = CardDeck();
    hud = HudManager(this);
    await hud.setupHUD();

    _setupChips();
    _buildCachedPaintsAndShaders();
    _updateHUDTexts();
    _hudInit = true;
  }

  // NEW: Method to confirm bet directly from side menu and start game
  void confirmBetAndStart(double betAmount) {
    if (betAmount <= 0 || betAmount > bankroll) return;
    
    // Deduct from bankroll and set current bet
    bankroll -= betAmount;
    currentBet = betAmount;

    // Create visual chips for the bet
    _createBetChipsVisual(betAmount);

    // Update HUD
    _updateHUDTexts();
    hud.updateHudVisibility();

    // Start the game
    startGame();
  }

  // Helper method to create visual chips for the bet
  void _createBetChipsVisual(double totalBet) {
    // Clear any existing bet chips
    _clearBetChips();

    double remaining = totalBet;
    final List<double> chipsToCreate = [];

    // Break down the bet into chip denominations
    for (int i = chipValues.length - 1; i >= 0; i--) {
      final chipValue = chipValues[i];
      while (remaining >= chipValue) {
        chipsToCreate.add(chipValue);
        remaining -= chipValue;
      }
    }

    // Create and position the chips
    for (int i = 0; i < chipsToCreate.length; i++) {
      final chipValue = chipsToCreate[i];
      final chip = BetChip(
        position: _computeChipPosition(i, bettingCenter),
        value: chipValue,
        color: _getChipColor(chipValue),
      )..priority = layerChips;
      
      betChips.add(chip);
      add(chip);
    }
  }

  Color _getChipColor(double value) {
    switch (value.toInt()) {
      case 1: return const Color(0xFFE0E0E0);
      case 5: return Colors.red;
      case 10: return Colors.blue;
      case 25: return const Color(0xFF1a237e); // Navy
      case 50: return Colors.purple;
      case 100: return const Color(0xFF0d1b2a); // Dark navy
      default: return Colors.grey;
    }
  }

  // Setup chip palette (hidden when using side menu)
  void _setupChips() {
    final double spacing = max(8.0, chipRadius * 0.20);
    final double btnR = max(14.0, min(22.0, chipRadius * 0.38));
    final double desiredGap = 2 * btnR;
    final double stride = (chipRadius * 2) + desiredGap;

    final totalWidth = stride * chipValues.length;
    final startX = (screenWidth - totalWidth) / 2 + (stride / 2);
    final double bottomSafeY = (screenHeight - hudPanelHeight) - margin * 0.6;
    final double chipY = bottomSafeY - (btnR + spacing + chipRadius);

    for (int i = 0; i < chipValues.length; i++) {
      final center = Vector2(startX + i * stride, chipY);
      final chip = PaletteChip(
        position: center,
        radius: chipRadius,
        value: chipValues[i],
        chipColor: _getChipColor(chipValues[i]),
        layout: ButtonsLayout.stackVertical,
        spacing: spacing,
        minGapAfterButtons: desiredGap,
      )..priority = layerChips;
      paletteChips.add(chip);
      
      // Don't add chips to game initially - they're controlled by HUD visibility
      // add(chip);
    }
  }

  // ChipGameInterface implementation
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
    if (stagedBet <= 0) {
      if (currentBet > 0) return;
      return;
    }

    currentBet += stagedBet;
    stagedBet = 0;

    final movedChips = List<BetChip>.from(stagedChips);
    stagedChips.clear();

    for (int i = 0; i < movedChips.length; i++) {
      final chip = movedChips[i];
      betChips.add(chip);
      final target = _computeChipPosition(betChips.length - 1, bettingCenter);
      chip.position = target;
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void confirmStaged() {
    confirmStagedToPot();
  }

  void cancelStaged() {
    if (gameState != GameState.betting) return;

    for (final chip in stagedChips) {
      bankroll += chip.value;
      chip.removeFromParent();
    }

    stagedBet = 0;
    stagedChips.clear();

    _updateHUDTexts();
    hud.updateHudVisibility();
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

  // Game flow
  void startGame() {
    if (currentBet <= 0) return;
    
    gameState = GameState.playing;
    playerHand.clear();
    dealerHand.clear();
    gameResult = '';

    // Deal initial cards
    _dealCard(isPlayer: true);
    _dealCard(isPlayer: false);
    _dealCard(isPlayer: true);
    _dealCard(isPlayer: false, hidden: true);

    _updateHUDTexts();
    hud.updateHudVisibility();
    _checkForBlackjack();
  }

  void _dealCard({required bool isPlayer, bool hidden = false}) {
    final card = deck.drawCard();
    
    if (isPlayer) {
      playerHand.add(card);
      final cardComp = CardComponent(
        position: deckPosition,
        size: Vector2(cardWidth, cardHeight),
        card: card,
        isHidden: hidden,
      )..priority = layerCards;
      playerCards.add(cardComp);
      add(cardComp);
    } else {
      dealerHand.add(card);
      final cardComp = CardComponent(
        position: deckPosition,
        size: Vector2(cardWidth, cardHeight),
        card: card,
        isHidden: hidden,
      )..priority = layerCards;
      dealerCards.add(cardComp);
      add(cardComp);
    }

    _updateCardsPositions();
  }

  void _checkForBlackjack() {
    if (_handValue(playerHand) == 21 && playerHand.length == 2) {
      _endRound(RoundOutcome.playerBlackjack);
    }
  }

  void hit() {
    if (gameState != GameState.playing) return;

    _dealCard(isPlayer: true);
    
    if (_handValue(playerHand) > 21) {
      _endRound(RoundOutcome.dealerWin);
    }

    _updateHUDTexts();
  }

  void stand() {
    if (gameState != GameState.playing) return;

    gameState = GameState.dealerTurn;
    hud.updateHudVisibility();

    if (dealerCards.length > 1 && dealerCards[1].isHidden) {
      dealerCards[1].flip();
    }

    _dealerPlay();
  }

  void doubleDown() {
    if (gameState != GameState.playing) return;
    if (playerHand.length != 2) return;
    if (bankroll < currentBet) return;

    bankroll -= currentBet;
    currentBet *= 2;

    _dealCard(isPlayer: true);
    _updateHUDTexts();

    if (_handValue(playerHand) > 21) {
      _endRound(RoundOutcome.dealerWin);
    } else {
      stand();
    }
  }

  Future<void> _dealerPlay() async {
    await Future.delayed(const Duration(milliseconds: 500));

    while (_handValue(dealerHand) < 17) {
      await Future.delayed(const Duration(milliseconds: 800));
      _dealCard(isPlayer: false);
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _determineWinner();
  }

  void _determineWinner() {
    final playerVal = _handValue(playerHand);
    final dealerVal = _handValue(dealerHand);

    if (dealerVal > 21 || playerVal > dealerVal) {
      _endRound(RoundOutcome.playerWin);
    } else if (playerVal == dealerVal) {
      _endRound(RoundOutcome.push);
    } else {
      _endRound(RoundOutcome.dealerWin);
    }
  }

  void _endRound(RoundOutcome outcome) {
    gameState = GameState.gameOver;

    switch (outcome) {
      case RoundOutcome.playerBlackjack:
        bankroll += currentBet * 2.5;
        gameResult = 'Blackjack! You win!';
        playerWins++;
        break;
      case RoundOutcome.playerWin:
        bankroll += currentBet * 2;
        gameResult = 'You win!';
        playerWins++;
        break;
      case RoundOutcome.push:
        bankroll += currentBet;
        gameResult = 'Push';
        break;
      case RoundOutcome.dealerWin:
        gameResult = 'Dealer wins';
        dealerWins++;
        break;
    }

    currentBet = 0;
    _clearBetChips();
    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void _clearBetChips() {
    for (final chip in betChips) {
      chip.removeFromParent();
    }
    betChips.clear();
  }

  void newRound() {
    gameState = GameState.betting;
    gameResult = '';

    for (final card in playerCards) {
      card.removeFromParent();
    }
    for (final card in dealerCards) {
      card.removeFromParent();
    }
    playerCards.clear();
    dealerCards.clear();
    playerHand.clear();
    dealerHand.clear();

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

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
    hud.winsText?.text = 'W/L: $playerWins / $dealerWins';
    hud.gameResultText?.text = gameResult;

    if (playerHand.isNotEmpty) {
      hud.playerHandText?.text = 'Player: ${_handValue(playerHand)}';
    } else {
      hud.playerHandText?.text = 'Player Hand';
    }

    if (dealerHand.isNotEmpty && gameState != GameState.playing) {
      hud.dealerHandText?.text = 'Dealer: ${_handValue(dealerHand)}';
    } else {
      hud.dealerHandText?.text = 'Dealer Hand';
    }
  }

  void _updateCardsPositions({bool animated = true}) {
    final spacing = cardWidth * 1.15;

    for (int i = 0; i < playerCards.length; i++) {
      final offset = (i - (playerCards.length - 1) / 2) * spacing;
      playerCards[i].position = Vector2(screenWidth / 2 + offset, playerCardY);
    }

    for (int i = 0; i < dealerCards.length; i++) {
      final offset = (i - (dealerCards.length - 1) / 2) * spacing;
      dealerCards[i].position = Vector2(screenWidth / 2 + offset, dealerCardY);
    }
  }

  Future<void> startRound() async {
    startGame();
  }

  // Rendering
  late Paint outerPaint, potFillPaint, innerBorderPaint, hudPanelPaint;
  Shader? hudGradientShader;

  void _buildCachedPaintsAndShaders() {
    outerPaint = Paint()
      ..color = const Color(0xFF2C5F2D)
      ..style = PaintingStyle.fill;

    potFillPaint = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..style = PaintingStyle.fill;

    innerBorderPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    hudPanelPaint = Paint()..style = PaintingStyle.fill;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      outerPaint,
    );

    canvas.drawCircle(bettingCenter.toOffset(), potRadius, potFillPaint);
    canvas.drawCircle(bettingCenter.toOffset(), potRadius, innerBorderPaint);

    if (hudGradientShader == null) {
      final rect = Rect.fromLTWH(
        0,
        screenHeight - hudPanelHeight,
        screenWidth,
        hudPanelHeight,
      );
      hudGradientShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0d1b2a), Color(0xFF1a1a2e)],
      ).createShader(rect);
      hudPanelPaint.shader = hudGradientShader;
    }

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        screenHeight - hudPanelHeight,
        screenWidth,
        hudPanelHeight,
      ),
      hudPanelPaint,
    );
  }

  void onDispose() {
    // Clean up if needed
  }
}