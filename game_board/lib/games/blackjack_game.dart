// lib/blackjack_game.dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../components/card_component.dart';
import '../components/chip_components.dart';
import '../components/mock_player.dart';
import '../ui/hud.dart';
import '../theme/app_theme.dart';

class BlackjackGame extends FlameGame implements ChipGameInterface {
  final User user;
  BlackjackGame({required this.user});
  // Layer priorities
  static const int layerBackground = 0;
  static const int layerTable = 1;
  static const int layerChips = 2;
  static const int layerCards = 3;
  static const int layerHud = 4;
  static const int layerHudPanel = 5;

  late CardDeck deck;

  // UI managers
  late HudManager hud;

  // HUD sizing
  double get hudPanelHeight => size.y * 0.16 * uiScale;

  // Cards and hands
  final List<CardComponent> playerCards = [];
  final List<CardComponent> dealerCards = [];

  // Chips
  final List<PaletteChip> paletteChips = [];
  final List<BetChip> betChips = [];     // confirmed in pot
  final List<BetChip> stagedChips = [];  // staged before confirm

  // Mock players (UI only)
  //late MockPlayerUI mockLeft;
  //late MockPlayerUI mockRight;

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
  double get margin => screenWidth * 0.011 * uiScale;

  double get playerCardY => screenHeight * 0.70;
  double get dealerCardY => screenHeight * 0.22;
  Vector2 get deckPosition => Vector2(screenWidth / 2, -cardHeight);

  Vector2 get bettingCenter => Vector2(screenWidth / 2, screenHeight / 2);
  double get potRadius => min(screenWidth, screenHeight) * 0.14 * uiScale;

  /// Where staged chips gather (just below the pot)
  Vector2 get stagedCenter => bettingCenter + Vector2(0, potRadius * 1.35);

  final List<double> chipValues = [1, 5, 10, 25, 50, 100];

  // Game state
  List<PlayingCard> playerHand = [];
  List<PlayingCard> dealerHand = [];
  GameState gameState = GameState.betting;
  String gameResult = '';
  int playerWins = 0;
  int dealerWins = 0;

  // Bankroll & betting
  double bankroll = 1000.0;

  /// Amount that is actually in the pot (already confirmed)
  double currentBet = 0.0;

  /// Amount the player is staging (can be confirmed or cancelled)
  double stagedBet = 0.0;

  bool _hudInit = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    deck = CardDeck();

    hud = HudManager(this);
    hud.setupHUD();

    _setupChips();
    //_addMockPlayers();

    _buildCachedPaintsAndShaders();
    _updateHUDTexts();
    _hudInit = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_hudInit) return;

    hud.removeHUD();
    for (var p in paletteChips) {
      p.removeFromParent();
    }
    paletteChips.clear();
    //mockLeft.removeFromParent();
    //mockRight.removeFromParent();

    hud.setupHUD();
    _setupChips();
    //_addMockPlayers();

    _buildCachedPaintsAndShaders();
    _updateHUDTexts();
    hud.updateHudVisibility();

    if (gameState != GameState.betting) {
      _updateCardsPositions(animated: false);
    }
  }

  // -----------------------------
  // Mock players (UI-only)
  // -----------------------------
  // void _addMockPlayers() {
  //   mockLeft = MockPlayerUI(
  //     name: 'Player 2',
  //     bank: 1000,
  //     anchorPos: Vector2(screenWidth * 0.08, screenHeight * 0.62),
  //     cardsCenter: Vector2(screenWidth * 0.22, screenHeight * 0.62),
  //     cardSize: Vector2(cardWidth * 0.9, cardHeight * 0.9),
  //   )..priority = layerHud;
  //   add(mockLeft);

  //   mockRight = MockPlayerUI(
  //     name: 'Player 3',
  //     bank: 1000,
  //     anchorPos: Vector2(screenWidth * 0.92, screenHeight * 0.62),
  //     cardsCenter: Vector2(screenWidth * 0.78, screenHeight * 0.62),
  //     cardSize: Vector2(cardWidth * 0.9, cardHeight * 0.9),
  //     rightSide: true,
  //   )..priority = layerHud;
  //   add(mockRight);
  // }

  // -----------------------------
  // Chips row (VERTICAL layout)
  // -----------------------------
  void _setupChips() {
    // Vertical layout: (+) above, chip in middle, (-) below. Bigger horizontal gap.
    final double spacing = max(8.0, chipRadius * 0.20);
    final double btnR = max(14.0, min(22.0, chipRadius * 0.38));

    final double desiredGap = 2 * btnR;
    final double stride = (chipRadius * 2) + desiredGap;

    final totalWidth = stride * chipValues.length;
    final startX = (screenWidth - totalWidth) / 2 + (stride / 2);

    final double bottomSafeY = (screenHeight - hudPanelHeight) - margin * 0.6;
    final double chipY = bottomSafeY - (btnR + spacing + chipRadius);

    Color colorFor(int v) {
      switch (v) {
        case 1:
          return const Color(0xFFE0E0E0);
        case 5:
          return Colors.red;
        case 10:
          return Colors.blue;
        case 25:
          return AppColors.primaryNavyLight;
        case 50:
          return Colors.purple;
        case 100:
          return AppColors.primaryNavyDark;
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
        chipColor: colorFor(chipValues[i].toInt()),
        layout: ButtonsLayout.stackVertical,
        spacing: spacing,
        minGapAfterButtons: desiredGap,
      )..priority = layerChips;
      paletteChips.add(chip);
      add(chip);
    }
  }

  // -----------------------------
  // STAGED betting actions
  // -----------------------------
  @override
  void stageBet({
    required Vector2 from,
    required double amount,
    required Color color,
  }) {
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

    // Find the last chip of this denomination in staged
    final idx = stagedChips.lastIndexWhere((c) => c.value == denom);
    if (idx == -1) return;

    final chip = stagedChips[idx];
    stagedChips.removeAt(idx);

    bankroll += chip.value;
    stagedBet -= chip.value;

    chip.removeFromParent();

    // Reposition remaining staged chips
    for (int i = 0; i < stagedChips.length; i++) {
      stagedChips[i].position = _computeChipPosition(i, stagedCenter);
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  Future<void> confirmStagedToPot() async {
    if (stagedBet <= 0) {
      // If no staged but have current bet, can still proceed
      if (currentBet > 0) return;
      return;
    }

    currentBet += stagedBet;
    stagedBet = 0;

    // Move all staged chips to pot
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

    // Return all staged chips to bankroll
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

  // -----------------------------
  // Game flow
  // -----------------------------
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

    // Reveal dealer's hidden card
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

    // Clear cards
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

    // Player cards
    for (int i = 0; i < playerCards.length; i++) {
      final offset = (i - (playerCards.length - 1) / 2) * spacing;
      playerCards[i].position = Vector2(screenWidth / 2 + offset, playerCardY);
    }

    // Dealer cards
    for (int i = 0; i < dealerCards.length; i++) {
      final offset = (i - (dealerCards.length - 1) / 2) * spacing;
      dealerCards[i].position = Vector2(screenWidth / 2 + offset, dealerCardY);
    }
  }

  Future<void> startRound() async {
    startGame();
  }

  // -----------------------------
  // Cached paints/shaders & rendering
  // -----------------------------
  late Paint outerPaint, potFillPaint, innerBorderPaint, hudPanelPaint;
  Shader? feltShader, potStrokeShader, radialHighlightShader;

  void _buildCachedPaintsAndShaders() {
    outerPaint = Paint()..color = const Color(0xFF2F1B14);
    innerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.25);

    final innerRect = Rect.fromLTWH(18, 18, size.x - 36, size.y - 36);
    feltShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A6B3A), Color(0xFF124B2A)],
    ).createShader(innerRect);

    potFillPaint = Paint()..shader = feltShader;

    potStrokeShader = const SweepGradient(
      colors: [
        Color(0xFFFFFFFF),
        Color(0x99FFFFFF),
        Color(0xFFFFFFFF),
      ],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 100));

    radialHighlightShader = const RadialGradient(
      colors: [Color(0x11FFFFFF), Color(0x00000000)],
      stops: [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 100));
  }

  @override
  void render(Canvas canvas) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.x - 16, size.y - 16),
      const Radius.circular(24),
    );
    canvas.drawRRect(outer, outerPaint);

    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(18, 18, size.x - 36, size.y - 36),
      const Radius.circular(20),
    );
    canvas.drawRRect(inner, Paint()..shader = feltShader);

    // HUD panel strip at bottom
    final hudRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, size.y - hudPanelHeight, size.x, hudPanelHeight),
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
    );
    hudPanelPaint = Paint()..color = const Color(0xCC0D0F11);
    canvas.drawRRect(hudRect, hudPanelPaint);
    canvas.drawRRect(hudRect, innerBorderPaint);

    // Pot
    final potCenter = Offset(bettingCenter.x, bettingCenter.y);
    final potFillPaint = Paint()
      ..shader = radialHighlightShader
      ..blendMode = BlendMode.plus;
    final potStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = potStrokeShader;
    canvas.drawCircle(potCenter, potRadius, potFillPaint);
    canvas.drawCircle(potCenter, potRadius, potStroke);

    // staged ring hint
    final stagedStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.textPrimary.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(stagedCenter.x, stagedCenter.y), potRadius * 0.7, stagedStroke);

    super.render(canvas);
  }
}