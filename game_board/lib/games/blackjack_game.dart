// lib/games/blackjack_game.dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../components/result_popup_component.dart';
import '../components/card_component.dart';
import '../components/chip_components.dart';
import '../models/playing_card.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../ui/hud.dart';

/// Single-player Blackjack game built on [FlameGame].
///
/// Implements [ChipGameInterface] so [PaletteChip] components can call
/// [stageBet] and [removeStagedDenom] without importing this class directly,
/// keeping the chip components decoupled from game-specific logic.
///
/// [onGameStateChanged] is called whenever [gameState] transitions, allowing
/// the host Flutter widget (e.g. a game screen) to react to state changes —
/// for example, showing a side menu only during the betting phase.
class BlackjackGame extends FlameGame implements ChipGameInterface {
  final User user;
  final Function(GameState)? onGameStateChanged;

  BlackjackGame({
    required this.user,
    this.onGameStateChanged,
  });

  // ─── Layer priorities ─────────────────────────────────────────────────────
  // Explicit constants prevent magic numbers from scattering across the file
  // and make the rendering order easy to reason about at a glance.
  static const int layerBackground = 0;
  static const int layerTable      = 1;
  static const int layerChips      = 2;
  static const int layerCards      = 3;
  static const int layerHud        = 4;
  static const int layerHudPanel   = 5;

  late CardDeck deck;
  late HudManager hud;

  final List<CardComponent> playerCards = [];
  final List<CardComponent> dealerCards = [];

  final List<PaletteChip> paletteChips = [];
  final List<BetChip> betChips    = []; // Chips committed to the current pot.
  final List<BetChip> stagedChips = []; // Chips placed but not yet confirmed.

  // ─── Adaptive sizing ──────────────────────────────────────────────────────
  // All dimensions are derived from screen size so the layout scales correctly
  // across mobile and web without hardcoded pixel values.
  double get screenWidth  => size.x;
  double get screenHeight => size.y;

  /// Scales UI elements relative to a 720-height baseline, clamped so the
  /// layout doesn't become unusably small on very compact screens.
  double get uiScale => (screenHeight / 720.0).clamp(0.6, 1.0);

  double get cardHeight    => screenHeight * 0.15 * uiScale;
  double get cardWidth     => cardHeight * 0.68;
  double get hudPanelHeight => screenHeight * 0.15 * uiScale;
  double get chipRadius    => screenWidth * 0.026 * uiScale;
  double get buttonWidth   => screenWidth * 0.15 * uiScale;
  double get buttonHeight  => screenHeight * 0.10 * uiScale;
  double get fontSize      => screenWidth * 0.02 * uiScale;
  double get largeFontSize => screenWidth * 0.028 * uiScale;
  double get margin        => screenWidth * 0.011 * uiScale;

  double get playerCardY => screenHeight * 0.90;
  double get dealerCardY => screenHeight * 0.22;

  /// Cards animate from off-screen above the dealer before sliding into place.
  Vector2 get deckPosition => Vector2(screenWidth / 2, -cardHeight);

  Vector2 get bettingCenter => Vector2(screenWidth / 2, screenHeight / 2);

  /// Visual radius of the pot circle drawn at the table centre.
  double get potRadius => min(screenWidth, screenHeight) * 0.14 * uiScale;

  /// Staged chips are displayed just below the pot so they are visually
  /// distinct from committed chips before the player confirms their bet.
  Vector2 get stagedCenter => bettingCenter + Vector2(0, potRadius * 1.35);

  final List<double> chipValues = [1, 5, 10, 25, 50, 100];

  // ─── Game state ───────────────────────────────────────────────────────────

  List<PlayingCard> playerHand = [];
  List<PlayingCard> dealerHand = [];
  GameState _gameState = GameState.betting;
  String gameResult = '';
  int playerWins = 0;
  int dealerWins = 0;

  /// Setting [gameState] notifies [onGameStateChanged] so the host widget
  /// can update its own UI (e.g. enabling/disabling the side bet menu)
  /// without polling or tight coupling to the game loop.
  GameState get gameState => _gameState;
  set gameState(GameState newState) {
    _gameState = newState;
    onGameStateChanged?.call(newState);
  }

  double bankroll  = 1000.0;
  double currentBet = 0.0;
  double stagedBet  = 0.0;

  /// Guards against [_updateHUDTexts] being called before [hud] is ready.
  bool _hudInit = false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    deck = CardDeck();
    hud  = HudManager(this);

    await hud.setupHUD();

    _setupChips();
    _buildCachedPaintsAndShaders();
    _updateHUDTexts();

    _hudInit = true;
  }

  /// Rebuilds layout-dependent elements whenever the game canvas is resized
  /// (e.g. device rotation or browser window resize).
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    _resizeAndRepositionCards();
    _recreatePaletteChips();
    _resizeBetChips();
    _resizeStagedChips();
    _repositionButtons();
    _buildCachedPaintsAndShaders(); // Shaders reference absolute pixel dimensions.
  }

  void _resizeAndRepositionCards() {
    final newCardSize = Vector2(cardWidth, cardHeight);
    final spacing = cardWidth * 1.15;

    for (int i = 0; i < playerCards.length; i++) {
      playerCards[i].size = newCardSize;
      final offset = (i - (playerCards.length - 1) / 2) * spacing;
      playerCards[i].position = Vector2(screenWidth / 2 + offset, playerCardY);
    }

    for (int i = 0; i < dealerCards.length; i++) {
      dealerCards[i].size = newCardSize;
      final offset = (i - (dealerCards.length - 1) / 2) * spacing;
      dealerCards[i].position = Vector2(screenWidth / 2 + offset, dealerCardY);
    }
  }

  void _recreatePaletteChips() {
    for (final chip in paletteChips) {
      chip.removeFromParent();
    }
    paletteChips.clear();
    _setupChips();
  }

  void _resizeBetChips() {
    if (betChips.isEmpty) return;
    final newSize = chipRadius * 2;
    for (int i = 0; i < betChips.length; i++) {
      betChips[i].size = Vector2.all(newSize);
      betChips[i].position = _computeChipPosition(i, bettingCenter);
    }
  }

  void _resizeStagedChips() {
    if (stagedChips.isEmpty) return;
    final newSize = chipRadius * 2;
    for (int i = 0; i < stagedChips.length; i++) {
      stagedChips[i].size = Vector2.all(newSize);
      stagedChips[i].position = _computeChipPosition(i, stagedCenter);
    }
  }

  void _repositionButtons() {
    if (_hudInit) hud.repositionButtons();
  }

  // ─── Betting ──────────────────────────────────────────────────────────────

  /// Entry point used by the Flutter side-bet menu to place a bet and
  /// start a round in a single action, bypassing the in-game chip palette.
  void confirmBetAndStart(double betAmount) {
    if (betAmount <= 0 || betAmount > bankroll) return;

    bankroll  -= betAmount;
    currentBet = betAmount;

    _createBetChipsVisual(betAmount);
    _updateHUDTexts();
    hud.updateHudVisibility();

    startGame();
  }

  /// Decomposes [totalBet] into the largest available chip denominations
  /// and places the resulting [BetChip] components in the pot area.
  void _createBetChipsVisual(double totalBet) {
    _clearBetChips();

    double remaining = totalBet;
    final List<double> chipsToCreate = [];

    // Greedy decomposition from largest denomination down.
    for (int i = chipValues.length - 1; i >= 0; i--) {
      final chipValue = chipValues[i];
      while (remaining >= chipValue) {
        chipsToCreate.add(chipValue);
        remaining -= chipValue;
      }
    }

    for (int i = 0; i < chipsToCreate.length; i++) {
      final chip = BetChip(
        position: _computeChipPosition(i, bettingCenter),
        value: chipsToCreate[i],
        color: _getChipColor(chipsToCreate[i]),
      )..priority = layerChips;
      betChips.add(chip);
      add(chip);
    }
  }

  /// Maps chip values to distinct colours so players can read stack
  /// composition at a glance without counting individual chips.
  Color _getChipColor(double value) {
    switch (value.toInt()) {
      case 1:   return const Color(0xFFE0E0E0);
      case 5:   return Colors.red;
      case 10:  return Colors.blue;
      case 25:  return const Color(0xFF1a237e);
      case 50:  return Colors.purple;
      case 100: return const Color(0xFF0d1b2a);
      default:  return Colors.grey;
    }
  }

  /// Creates [PaletteChip] instances for the in-game chip palette.
  ///
  /// Chips are not added to the scene here — [HudManager] controls their
  /// visibility based on the current [gameState].
  void _setupChips() {
    final double spacing   = max(8.0, chipRadius * 0.20);
    final double btnR      = max(14.0, min(22.0, chipRadius * 0.38));
    final double desiredGap = 2 * btnR;
    final double stride    = (chipRadius * 2) + desiredGap;

    final totalWidth = stride * chipValues.length;
    final startX     = (screenWidth - totalWidth) / 2 + (stride / 2);
    final double chipY = (screenHeight - hudPanelHeight) - margin * 0.6
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
    }
  }

  // ─── ChipGameInterface ────────────────────────────────────────────────────

  /// Moves [amount] from the bankroll into the staged area, creating a
  /// visual [BetChip] at [from] and repositioning it to [stagedCenter].
  @override
  void stageBet({required Vector2 from, required double amount, required Color color}) {
    if (gameState != GameState.betting) return;
    if (bankroll < amount) return;

    bankroll   -= amount;
    stagedBet  += amount;

    final chip = BetChip(position: from.clone(), value: amount, color: color)
      ..priority = layerChips;

    stagedChips.add(chip);
    add(chip);

    chip.position = _computeChipPosition(stagedChips.length - 1, stagedCenter);

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  /// Removes the most recently staged chip of denomination [denom] and
  /// returns its value to the bankroll.
  @override
  void removeStagedDenom(double denom) {
    if (gameState != GameState.betting) return;

    final idx = stagedChips.lastIndexWhere((c) => c.value == denom);
    if (idx == -1) return;

    final chip = stagedChips.removeAt(idx);
    bankroll  += chip.value;
    stagedBet -= chip.value;
    chip.removeFromParent();

    // Repack remaining staged chips so the layout stays tidy.
    for (int i = 0; i < stagedChips.length; i++) {
      stagedChips[i].position = _computeChipPosition(i, stagedCenter);
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  /// Moves all staged chips into the committed pot, adding their value to
  /// [currentBet]. Called when the player taps the confirm button.
  Future<void> confirmStagedToPot() async {
    if (stagedBet <= 0) return;

    currentBet += stagedBet;
    stagedBet   = 0;

    final movedChips = List<BetChip>.from(stagedChips);
    stagedChips.clear();

    for (int i = 0; i < movedChips.length; i++) {
      betChips.add(movedChips[i]);
      movedChips[i].position = _computeChipPosition(betChips.length - 1, bettingCenter);
    }

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void confirmStaged() => confirmStagedToPot();

  /// Returns all staged chips to the bankroll without committing them.
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

  /// Arranges chips in a loose spiral around [center] so stacks of
  /// different sizes remain readable rather than fully overlapping.
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

  // ─── Game flow ────────────────────────────────────────────────────────────

  /// Deals the initial four cards and transitions to the playing state.
  /// Exits early if no bet has been placed.
  void startGame() {
    if (currentBet <= 0) return;

    gameState = GameState.playing;
    playerHand.clear();
    dealerHand.clear();
    gameResult = '';

    _dealCard(isPlayer: true);
    _dealCard(isPlayer: false);
    _dealCard(isPlayer: true);
    _dealCard(isPlayer: false, hidden: true); // Dealer's hole card.

    _updateHUDTexts();
    hud.updateHudVisibility();

    _checkForBlackjack();
  }

  /// Draws the top card from [deck] and adds it to the appropriate hand.
  ///
  /// [hidden] is used for the dealer's hole card, which is revealed when
  /// the dealer takes their turn in [stand].
  void _dealCard({required bool isPlayer, bool hidden = false}) {
    final card = deck.drawCard();
    final cardComp = CardComponent(
      position: deckPosition,
      size: Vector2(cardWidth, cardHeight),
      card: card,
      isHidden: hidden,
    )..priority = layerCards;

    if (isPlayer) {
      playerHand.add(card);
      playerCards.add(cardComp);
    } else {
      dealerHand.add(card);
      dealerCards.add(cardComp);
    }

    add(cardComp);
    _updateCardsPositions();
  }

  /// Checks for a natural Blackjack immediately after the opening deal.
  void _checkForBlackjack() {
    if (_handValue(playerHand) == 21 && playerHand.length == 2) {
      _endRound(RoundOutcome.playerBlackjack);
    }
  }

  void hit() {
    if (gameState != GameState.playing) return;
    _dealCard(isPlayer: true);
    if (_handValue(playerHand) > 21) _endRound(RoundOutcome.dealerWin);
    _updateHUDTexts();
  }

  /// Reveals the dealer's hole card and starts the dealer's automated turn.
  void stand() {
    if (gameState != GameState.playing) return;

    gameState = GameState.dealerTurn;
    hud.updateHudVisibility();

    if (dealerCards.length > 1 && dealerCards[1].isHidden) {
      dealerCards[1].flip();
    }

    _dealerPlay();
  }

  /// Doubles the current bet, deals exactly one more card, then stands.
  /// Only permitted on the opening two-card hand.
  void doubleDown() {
    if (gameState != GameState.playing) return;
    if (playerHand.length != 2) return;
    if (bankroll < currentBet) return;

    bankroll   -= currentBet;
    currentBet *= 2;

    _dealCard(isPlayer: true);
    _updateHUDTexts();

    if (_handValue(playerHand) > 21) {
      _endRound(RoundOutcome.dealerWin);
    } else {
      stand();
    }
  }

  /// Runs the dealer's turn: draws until 17 or higher, with delays between
  /// cards so the player can follow the action.
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

  /// Resolves the round, applies the payout to [bankroll], shows the result
  /// popup, and resets betting state ready for the next round.
  void _endRound(RoundOutcome outcome) {
    gameState = GameState.gameOver;

    String mainText;
    String amountText;
    bool   isWin   = false;
    double payout  = 0.0;

    switch (outcome) {
      case RoundOutcome.playerBlackjack:
        // 3:2 payout — player receives their stake plus 1.5× profit.
        payout    = currentBet * 2.5;
        bankroll += payout;
        mainText  = 'BLACKJACK!';
        amountText = '+£${payout.toStringAsFixed(0)}';
        isWin      = true;
        gameResult = 'Blackjack! You win!';
        playerWins++;
        break;

      case RoundOutcome.playerWin:
        payout    = currentBet * 2;
        bankroll += payout;
        mainText  = 'YOU WIN!';
        amountText = '+£${payout.toStringAsFixed(0)}';
        isWin      = true;
        gameResult = 'You win!';
        playerWins++;
        break;

      case RoundOutcome.push:
        // Stake returned; neither side wins.
        payout    = currentBet;
        bankroll += payout;
        mainText  = 'PUSH';
        amountText = '£0';
        gameResult = 'Push';
        break;

      case RoundOutcome.dealerWin:
        mainText  = 'DEALER WINS';
        amountText = '-£${currentBet.toStringAsFixed(0)}';
        gameResult = 'Dealer wins';
        dealerWins++;
        break;
    }

    add(ResultPopupComponent(
      mainText:   mainText,
      amountText: amountText,
      isWin:      isWin,
    ));

    currentBet = 0;
    _clearBetChips();
    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  void _clearBetChips() {
    for (final chip in betChips) chip.removeFromParent();
    betChips.clear();
  }

  /// Resets all per-round state and returns to the betting phase.
  void newRound() {
    gameState  = GameState.betting;
    gameResult = '';

    for (final card in [...playerCards, ...dealerCards]) {
      card.removeFromParent();
    }
    playerCards.clear();
    dealerCards.clear();
    playerHand.clear();
    dealerHand.clear();

    _updateHUDTexts();
    hud.updateHudVisibility();
  }

  /// Calculates the best Blackjack hand value for [hand].
  ///
  /// Aces start as 11 and are reduced to 1 one at a time to avoid busting,
  /// matching standard Blackjack rules.
  int _handValue(List<PlayingCard> hand) {
    int value = 0;
    int aces  = 0;

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

    hud.bankrollText?.text  = 'Bankroll: £${bankroll.toStringAsFixed(0)}';
    hud.betText?.text       = 'Bet: £${currentBet.toStringAsFixed(0)} | Staged: £${stagedBet.toStringAsFixed(0)}';
    hud.winsText?.text      = 'W/L: $playerWins / $dealerWins';
    hud.gameResultText?.text = gameResult;

    hud.playerHandText?.text = playerHand.isNotEmpty
        ? 'Player: ${_handValue(playerHand)}'
        : 'Player Hand';

    // Show the dealer's true total only once their hole card has been revealed.
    hud.dealerHandText?.text = dealerHand.isNotEmpty && gameState != GameState.playing
        ? 'Dealer: ${_handValue(dealerHand)}'
        : 'Dealer Hand';
  }

  /// Fans cards symmetrically around the horizontal centre of the screen.
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

  Future<void> startRound() async => startGame();

  // ─── Rendering ────────────────────────────────────────────────────────────

  // Cached to avoid allocating new Paint objects every frame.
  late Paint outerPaint, potFillPaint, innerBorderPaint, hudPanelPaint;

  /// Builds [Paint] objects that depend on screen dimensions (e.g. gradient
  /// shaders). Called on load and again on every resize.
  void _buildCachedPaintsAndShaders() {
    outerPaint = Paint()
      ..color = const Color(0xFF2C5F2D) // Casino-green table felt.
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
    // Background is drawn manually before [super.render] so that all
    // Flame components (cards, chips, HUD) are composited on top of it.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      outerPaint,
    );

    canvas.drawCircle(bettingCenter.toOffset(), potRadius, potFillPaint);
    canvas.drawCircle(bettingCenter.toOffset(), potRadius, innerBorderPaint);

    super.render(canvas);
  }
}