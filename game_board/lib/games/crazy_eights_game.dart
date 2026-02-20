// lib/games/crazy_eights_game.dart
import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/crazy_eights_card.dart';
import '../models/user.dart';
import '../components/crazy_eights_card_component.dart';
import '../theme/app_theme.dart';

/// Four-player Crazy Eights game (1 human, 3 AI) built on [FlameGame].
///
/// Special card rules implemented:
/// - **Queen**: +2 draw, stackable with other Queens.
/// - **King**: Change suit only.
/// - **Ace**: +4 draw, stackable with other Aces.
/// - **Jack**: Player's choice — skip the next player or reverse direction.
/// - **Eight**: Wild (standard Crazy Eights rule).
///
/// The "Crazy Eights call" mechanic requires any player with one card to
/// declare it; failure to do so before the next turn allows other players
/// to challenge and force a two-card penalty draw.
class CrazyEightsGame extends FlameGame with TapCallbacks {
  final User user;

  CrazyEightsGame({required this.user});

  // ─── Layer priorities ─────────────────────────────────────────────────────
  static const int layerBackground = 0;
  static const int layerTable      = 1;
  static const int layerCards      = 2;
  static const int layerHud        = 3;
  static const int layerOverlay    = 4;

  // ─── Game state ───────────────────────────────────────────────────────────
  late CrazyEightsDeck deck;
  final List<CrazyEightsCard> discardPile = [];

  /// Active suit override set when a King or Ace is played. Null when no
  /// suit change is in effect, i.e. the top card's suit applies normally.
  CardSuit? currentChosenSuit;

  final List<CrazyEightsCard> playerHand = [];
  final List<List<CrazyEightsCard>> aiHands = [[], [], []];

  final List<CrazyEightsCardComponent> playerCardComponents = [];
  CrazyEightsCardComponent? discardTopComponent;
  DrawPileComponent? drawPileComponent;
  CrazyEightsButton? crazyEightsButton;
  CrazyEightsButton? challengeButton;
  final List<int> aiCardCounts = [0, 0, 0];

  // ─── Turn tracking ────────────────────────────────────────────────────────
  int currentPlayerIndex = 0; // 0 = human, 1-3 = AI players.
  bool clockwise = true;

  /// Accumulated penalty cards the next player must draw if they cannot stack.
  int drawCount = 0;
  bool isDrawStacking = false;

  // ─── Crazy Eights call state ──────────────────────────────────────────────
  /// Index matches player index (0 = human, 1-3 = AI).
  final List<bool> hasCalledCrazyEights = [false, false, false, false];
  bool canChallenge = false;
  int? challengeablePlayer;

  /// Cancels the challenge window after 5 seconds if no challenge is made.
  async_timer.Timer? challengeTimer;

  // ─── Jack / suit picker state ─────────────────────────────────────────────
  bool isAwaitingJackChoice = false;
  CrazyEightsCard? pendingJackCard;

  // ─── UI state ─────────────────────────────────────────────────────────────
  CrazyEightsCardComponent? selectedCard;
  bool showSuitPicker = false;
  bool showJackChoice = false;
  bool gameOver = false;
  String? winner;

  String statusMessage = 'Your turn! Play a card or draw.';

  // ─── Adaptive sizing ──────────────────────────────────────────────────────
  double get screenWidth  => size.x;
  double get screenHeight => size.y;
  double get uiScale  => (screenHeight / 720.0).clamp(0.6, 1.0);
  double get cardHeight => screenHeight * 0.34 * uiScale;
  double get cardWidth  => cardHeight * 0.68;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    super.onLoad();
    deck = CrazyEightsDeck();
    _dealInitialCards();
    _placeFirstDiscardCard();
    await _renderCards();
    _createCrazyEightsButton();
  }

  /// Deals 7 cards to the human player and each AI, then sorts the human hand.
  void _dealInitialCards() {
    for (var i = 0; i < 7; i++) {
      playerHand.add(deck.drawCard());
      for (var j = 0; j < 3; j++) {
        aiHands[j].add(deck.drawCard());
      }
    }
    _sortPlayerHand();
    for (var i = 0; i < 3; i++) aiCardCounts[i] = aiHands[i].length;
  }

  /// Draws cards until a non-action card is found for the opening discard,
  /// preventing the game from starting with an immediate special effect.
  void _placeFirstDiscardCard() {
    CrazyEightsCard firstCard;
    do {
      firstCard = deck.drawCard();
    } while (firstCard.isAction);
    discardPile.add(firstCard);
  }

  /// Sorts the human hand by suit then rank so related cards are grouped together.
  void _sortPlayerHand() {
    playerHand.sort((a, b) {
      if (a.suit.index != b.suit.index) return a.suit.index.compareTo(b.suit.index);
      return a.rank.index.compareTo(b.rank.index);
    });
  }

  // ─── HUD ──────────────────────────────────────────────────────────────────

  void _createCrazyEightsButton() {
    crazyEightsButton?.removeFromParent();
    crazyEightsButton = CrazyEightsButton(
      position: Vector2(screenWidth * 0.85, screenHeight * 0.85),
      size: Vector2(screenWidth * 0.12, screenHeight * 0.08),
      text: 'CrazyEights!',
      onTap: _handleCrazyEightsCall,
    )..priority = layerHud;
    add(crazyEightsButton!);
  }

  void _handleCrazyEightsCall() {
    if (playerHand.length == 1 && !hasCalledCrazyEights[0]) {
      hasCalledCrazyEights[0] = true;
      statusMessage = '🎯 Crazy Eights called!';
    } else if (playerHand.length != 1) {
      statusMessage = 'You can only call Crazy Eights with 1 card!';
    } else {
      statusMessage = 'You already called Crazy Eights!';
    }
  }

  // ─── Challenge mechanic ───────────────────────────────────────────────────

  /// Checks whether [playerIndex] has one card but hasn't called Crazy Eights,
  /// and if so opens a 5-second challenge window.
  void _checkCrazyEightsViolation(int playerIndex) {
    final hand = playerIndex == 0 ? playerHand : aiHands[playerIndex - 1];
    if (hand.length != 1 || hasCalledCrazyEights[playerIndex]) return;

    canChallenge = true;
    challengeablePlayer = playerIndex;

    // Show the challenge button only when a human player could issue the challenge.
    if (currentPlayerIndex != 0 && playerIndex != 0) _showChallengeButton();

    // AI players will automatically challenge 70% of the time after 2 seconds.
    if (playerIndex != 0) {
      async_timer.Future.delayed(const Duration(seconds: 2), () {
        if (canChallenge && challengeablePlayer == playerIndex) _performAiChallenge();
      });
    }

    // Close the window after 5 seconds whether or not a challenge was made.
    challengeTimer?.cancel();
    challengeTimer = async_timer.Timer(const Duration(seconds: 5), () {
      canChallenge = false;
      challengeablePlayer = null;
      challengeButton?.removeFromParent();
      challengeButton = null;
    });
  }

  void _showChallengeButton() {
    challengeButton?.removeFromParent();
    challengeButton = CrazyEightsButton(
      position: Vector2(screenWidth * 0.85, screenHeight * 0.73),
      size: Vector2(screenWidth * 0.12, screenHeight * 0.08),
      text: 'Challenge!',
      onTap: _handleChallenge,
    )..priority = layerHud;
    add(challengeButton!);
  }

  /// Issues a challenge against the player who failed to call Crazy Eights,
  /// forcing them to draw two penalty cards.
  void _handleChallenge() {
    if (!canChallenge || challengeablePlayer == null) return;

    final target = challengeablePlayer!;
    if (target == 0) {
      playerHand.add(deck.drawCard());
      playerHand.add(deck.drawCard());
      _sortPlayerHand();
      statusMessage = '❌ You were challenged! Drew 2 cards.';
    } else {
      aiHands[target - 1].add(deck.drawCard());
      aiHands[target - 1].add(deck.drawCard());
      aiCardCounts[target - 1] += 2;
      statusMessage = '✅ Player ${target + 1} challenged! Drew 2 cards.';
    }

    _renderCards();
    canChallenge = false;
    challengeablePlayer = null;
    challengeButton?.removeFromParent();
    challengeButton = null;
  }

  /// AI challenges with 70% probability to keep the mechanic interesting
  /// without being punishing every single time.
  void _performAiChallenge() {
    if (Random().nextDouble() < 0.7) _handleChallenge();
  }

  // ─── Rendering ────────────────────────────────────────────────────────────

  /// Rebuilds all card components from current hand state.
  ///
  /// Called after every move rather than incrementally updating, so the visual
  /// state is always a clean reflection of the logical state without needing
  /// to track individual component mutations.
  Future<void> _renderCards() async {
    for (var card in playerCardComponents) card.removeFromParent();
    playerCardComponents.clear();
    discardTopComponent?.removeFromParent();
    discardTopComponent = null;
    drawPileComponent?.removeFromParent();
    drawPileComponent = null;

    // Fan player hand across the bottom of the screen.
    final handSpacing = cardWidth * 0.8;
    final totalWidth  = (playerHand.length - 1) * handSpacing + cardWidth;
    final startX      = (screenWidth - totalWidth) / 2 + cardWidth / 2;
    final cardY       = screenHeight - (cardHeight / 2) - 30.0;

    for (var i = 0; i < playerHand.length; i++) {
      final cardComp = CrazyEightsCardComponent(
        position: Vector2(startX + i * handSpacing, cardY),
        size: Vector2(cardWidth, cardHeight),
        card: playerHand[i],
        onTap: (tappedCard) {
          final index = playerCardComponents.indexOf(tappedCard);
          if (index >= 0) _handleCardTap(index);
        },
      )..priority = layerCards + 10 + i;

      playerCardComponents.add(cardComp);
      add(cardComp);
    }

    if (discardPile.isNotEmpty) {
      final topCard = discardPile.last;
      discardTopComponent = CrazyEightsCardComponent(
        position: Vector2(screenWidth / 2 + cardWidth * 0.7, screenHeight / 2),
        size: Vector2(cardWidth, cardHeight),
        card: topCard,
        // Pass the chosen suit so King/Ace cards show which suit is currently active.
        displaySuit: topCard.canChangeSuit ? currentChosenSuit : null,
        onTap: (_) => _handleDiscardPileTap(),
      )..priority = layerCards;
      add(discardTopComponent!);
    }

    drawPileComponent = DrawPileComponent(
      position: Vector2(screenWidth / 2 - cardWidth * 0.7, screenHeight / 2),
      size: Vector2(cardWidth, cardHeight),
      remainingCards: deck.remainingCards,
      onTap: _handleDrawCard,
    )..priority = layerCards;
    add(drawPileComponent!);

    for (var i = 0; i < 3; i++) aiCardCounts[i] = aiHands[i].length;
  }

  @override
  void render(Canvas canvas) {
    // Green felt background drawn before super.render so all components
    // appear on top of it.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      Paint()..color = const Color(0xFF1B5E20),
    );

    _drawGameInfo(canvas);
    _drawAIPlayers(canvas);

    super.render(canvas);

    // Overlay dialogs are drawn after super.render so they appear above cards.
    if (showSuitPicker) _drawSuitPicker(canvas);
    if (showJackChoice) _drawJackChoice(canvas);
    if (gameOver)       _drawGameOver(canvas);
  }

  /// Draws the status message, active draw stack count, play direction, and
  /// current chosen suit label across the top of the screen.
  void _drawGameInfo(Canvas canvas) {
    _paintCentredText(
      canvas,
      text: statusMessage,
      style: TextStyle(
        fontFamily: 'Inter',
        color: AppColors.textPrimary,
        fontSize: 20 * uiScale,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 4, color: AppColors.primaryNavyDark.withValues(alpha: 0.5), offset: const Offset(2, 2))],
      ),
      x: screenWidth / 2,
      y: screenHeight * 0.05,
      maxWidth: screenWidth * 0.8,
    );

    if (drawCount > 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: '🎴 STACK: +$drawCount',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.redAccent,
            fontSize: 24 * uiScale,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 6, color: AppColors.primaryNavyDark.withValues(alpha: 0.7), offset: const Offset(2, 2))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(screenWidth * 0.05, screenHeight * 0.12));
    }

    final directionText = clockwise ? '→ Clockwise' : '← Counter-Clockwise';
    final dirPainter = TextPainter(
      text: TextSpan(
        text: directionText,
        style: TextStyle(fontFamily: 'Inter', color: Colors.amber, fontSize: 18 * uiScale, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dirPainter.paint(canvas, Offset(screenWidth * 0.72, screenHeight * 0.05));

    // Clear the chosen suit once the top card no longer requires one.
    if (currentChosenSuit != null && !discardPile.last.canChangeSuit) {
      currentChosenSuit = null;
    }

    if (currentChosenSuit != null) {
      final suitNames = {
        CardSuit.hearts: '♥ Hearts', CardSuit.diamonds: '♦ Diamonds',
        CardSuit.clubs: '♣ Clubs',   CardSuit.spades: '♠ Spades',
      };
      final painter = TextPainter(
        text: TextSpan(
          text: 'Suit: ${suitNames[currentChosenSuit]}',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _getSuitColor(currentChosenSuit!),
            fontSize: 16 * uiScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(screenWidth * 0.05, screenHeight * 0.05));
    }
  }

  /// Red for hearts/diamonds (traditional), dark navy for clubs/spades.
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

  void _drawAIPlayers(Canvas canvas) {
    // Fixed positions place the three AI players left, top-centre, and right.
    final positions = [
      Offset(screenWidth * 0.1, screenHeight * 0.3),
      Offset(screenWidth * 0.5, screenHeight * 0.1),
      Offset(screenWidth * 0.9, screenHeight * 0.3),
    ];

    for (var i = 0; i < 3; i++) {
      _drawAIPlayer(canvas, positions[i], i, currentPlayerIndex == i + 1);
    }
  }

  /// Renders a single AI player's label and a fan of face-down card backs.
  ///
  /// Up to 5 cards are shown; if the AI holds more, a "+N more" label
  /// is added so the hand size remains legible without excessive overlap.
  void _drawAIPlayer(Canvas canvas, Offset position, int aiIndex, bool isActive) {
    final name      = 'Player ${aiIndex + 2}';
    final cardCount = '${aiCardCounts[aiIndex]} card${aiCardCounts[aiIndex] != 1 ? 's' : ''}';
    final ceStatus  = hasCalledCrazyEights[aiIndex + 1] && aiCardCounts[aiIndex] == 1 ? ' 🎯CE' : '';

    final namePainter = TextPainter(
      text: TextSpan(
        text: '$name\n$cardCount$ceStatus',
        style: TextStyle(
          fontFamily: 'Inter',
          color: isActive ? Colors.amber : AppColors.textPrimary,
          fontSize: 16 * uiScale,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          shadows: [Shadow(blurRadius: 4, color: AppColors.primaryNavyDark.withValues(alpha: 0.7), offset: const Offset(1, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    namePainter.paint(canvas, Offset(position.dx - namePainter.width / 2, position.dy));

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
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0B3A79));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.textPrimary.withValues(alpha: 0.5),
      );
    }

    if (aiCardCounts[aiIndex] > 5) {
      final morePainter = TextPainter(
        text: TextSpan(
          text: '+${aiCardCounts[aiIndex] - 5} more',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 12 * uiScale),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      morePainter.paint(
        canvas,
        Offset(position.dx - morePainter.width / 2, position.dy + 40 + cardBackSize.height + 5),
      );
    }
  }

  // ─── Modal dialogs ────────────────────────────────────────────────────────

  /// Draws the suit-picker dialog as a horizontal row of four suit buttons.
  ///
  /// Hit-testing for taps on these buttons is handled separately in
  /// [_handleSuitPickerTap] using matching geometry, since this is drawn
  /// directly onto the Canvas rather than as a Flutter widget.
  void _drawSuitPicker(Canvas canvas) {
    _drawModalOverlay(canvas);

    final dialogW = screenWidth * 0.6;
    final dialogH = screenHeight * 0.25;
    final dialogRect = _centredRRect(dialogW, dialogH, 20);

    canvas.drawRRect(dialogRect, Paint()..color = AppColors.textPrimary);
    _paintCentredText(
      canvas,
      text: 'Choose a Suit',
      style: TextStyle(fontFamily: 'Inter', color: AppColors.primaryNavyDark, fontSize: 20 * uiScale, fontWeight: FontWeight.bold),
      x: screenWidth / 2,
      y: screenHeight / 2 - dialogH / 2 + 15,
    );

    final buttonSize  = screenWidth * 0.11;
    final gap         = screenWidth * 0.02;
    final totalWidth  = buttonSize * 4 + gap * 3;
    final startX      = screenWidth / 2 - totalWidth / 2;
    final buttonY     = screenHeight / 2 + dialogH / 4;

    final suits = [
      {'suit': CardSuit.hearts,   'symbol': '♥', 'color': const Color(0xFFE53935)},
      {'suit': CardSuit.diamonds, 'symbol': '♦', 'color': const Color(0xFFE53935)},
      {'suit': CardSuit.clubs,    'symbol': '♣', 'color': AppColors.primaryNavyDark},
      {'suit': CardSuit.spades,   'symbol': '♠', 'color': AppColors.primaryNavyDark},
    ];

    for (var i = 0; i < 4; i++) {
      final x = startX + i * (buttonSize + gap);
      final buttonRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize),
        const Radius.circular(12),
      );

      canvas.drawRRect(buttonRect, Paint()..color = Colors.grey.shade200);
      canvas.drawRRect(
        buttonRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.primaryNavyDark.withValues(alpha: 0.3),
      );

      final symbolPainter = TextPainter(
        text: TextSpan(
          text: suits[i]['symbol'] as String,
          style: TextStyle(fontFamily: 'Inter', color: suits[i]['color'] as Color, fontSize: buttonSize * 0.5, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      symbolPainter.paint(
        canvas,
        Offset(x + buttonSize / 2 - symbolPainter.width / 2, buttonY - symbolPainter.height / 2),
      );
    }
  }

  /// Draws the Jack action dialog offering "Skip Next" or "Reverse" buttons.
  void _drawJackChoice(Canvas canvas) {
    _drawModalOverlay(canvas);

    final dialogW = screenWidth * 0.65;
    final dialogH = screenHeight * 0.22;
    final dialogRect = _centredRRect(dialogW, dialogH, 20);

    canvas.drawRRect(dialogRect, Paint()..color = AppColors.textPrimary);
    _paintCentredText(
      canvas,
      text: 'Choose Jack Action',
      style: TextStyle(fontFamily: 'Inter', color: AppColors.primaryNavyDark, fontSize: 20 * uiScale, fontWeight: FontWeight.bold),
      x: screenWidth / 2,
      y: screenHeight / 2 - dialogH / 2 + 15,
    );

    final buttonW = screenWidth * 0.25;
    final buttonH = screenHeight * 0.07;
    final spacing = screenWidth * 0.04;
    final buttonY = screenHeight / 2 + dialogH / 4;

    // Skip button (blue) — left of centre.
    final skipCx = screenWidth / 2 - buttonW / 2 - spacing / 2;
    _drawDialogButton(canvas, text: 'Skip Next', color: Colors.blue, cx: skipCx, cy: buttonY, w: buttonW, h: buttonH);

    // Reverse button (orange) — right of centre.
    final reverseCx = screenWidth / 2 + buttonW / 2 + spacing / 2;
    _drawDialogButton(canvas, text: 'Reverse', color: Colors.orange, cx: reverseCx, cy: buttonY, w: buttonW, h: buttonH);
  }

  /// Shared helper that draws a single labelled button inside a dialog.
  void _drawDialogButton(Canvas canvas, {
    required String text,
    required Color color,
    required double cx,
    required double cy,
    required double w,
    required double h,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = color);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(cx - painter.width / 2, cy - painter.height / 2));
  }

  void _drawGameOver(Canvas canvas) {
    _drawModalOverlay(canvas, alpha: 0.8);

    final isPlayerWin  = winner == 'player';
    final resultText   = isPlayerWin ? 'YOU WIN!' : 'YOU LOSE!';
    final subtitleText = isPlayerWin ? '🎉 Congratulations! 🎉' : 'Better luck next time!';

    _paintCentredText(
      canvas,
      text: resultText,
      style: TextStyle(
        fontFamily: 'Inter',
        color: isPlayerWin ? AppColors.primaryNavyLight : Colors.redAccent,
        fontSize: 48 * uiScale,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 10, color: AppColors.primaryNavyDark, offset: const Offset(2, 2))],
      ),
      x: screenWidth / 2,
      y: screenHeight / 2 - 30,
    );

    _paintCentredText(
      canvas,
      text: subtitleText,
      style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 20 * uiScale),
      x: screenWidth / 2,
      y: screenHeight / 2 + 50,
    );
  }

  // ─── Shared drawing helpers ───────────────────────────────────────────────

  /// Semi-transparent navy overlay used as a backdrop for all modal dialogs.
  void _drawModalOverlay(Canvas canvas, {double alpha = 0.7}) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      Paint()..color = AppColors.primaryNavyDark.withValues(alpha: alpha),
    );
  }

  /// Creates a rounded rect centred on screen with given [w] and [h].
  RRect _centredRRect(double w, double h, double radius) {
    return RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(screenWidth / 2, screenHeight / 2), width: w, height: h),
      Radius.circular(radius),
    );
  }

  /// Paints [text] horizontally centred at ([x], [y]).
  void _paintCentredText(Canvas canvas, {
    required String text,
    required TextStyle style,
    required double x,
    required double y,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, Offset(x - painter.width / 2, y));
  }

  // ─── Input handling ───────────────────────────────────────────────────────

  void _handleDiscardPileTap() {
    if (gameOver || currentPlayerIndex != 0 || showSuitPicker || showJackChoice) return;
    if (selectedCard == null) return;

    final cardIndex = playerCardComponents.indexOf(selectedCard!);
    if (cardIndex < 0) return;

    // King/Ace require a suit choice before the card is committed.
    if (playerHand[cardIndex].canChangeSuit) {
      _showSuitPicker();
    } else {
      _playCard(cardIndex, null);
    }
  }

  void _handleCardTap(int cardIndex) {
    if (gameOver || showSuitPicker || showJackChoice) return;

    final card    = playerHand[cardIndex];
    final cardComp = playerCardComponents[cardIndex];

    // Jump-in: an identical card may be played out of turn.
    if (currentPlayerIndex != 0) {
      if (card.isIdenticalTo(discardPile.last)) {
        _performJumpIn(cardIndex);
      } else {
        statusMessage = 'Not your turn!';
      }
      return;
    }

    // Tapping the already-selected card deselects it.
    if (selectedCard == cardComp) {
      cardComp.setSelected(false);
      selectedCard = null;
      statusMessage = 'Card deselected. Pick another or draw.';
      return;
    }

    // When a draw stack is active, only stackable cards can be selected.
    if (drawCount > 0) {
      if (_canStackDrawCard(card)) {
        selectedCard?.setSelected(false);
        selectedCard = cardComp;
        cardComp.setSelected(true);
        statusMessage = 'Stack +${card.isQueen ? '2' : '4'}! Click discard to play.';
      } else {
        statusMessage = 'You must stack or draw $drawCount cards!';
      }
      return;
    }

    if (!card.canPlayOn(discardPile.last, currentChosenSuit)) {
      statusMessage = 'Cannot play that card! Match suit or rank.';
      return;
    }

    selectedCard?.setSelected(false);
    selectedCard = cardComp;
    cardComp.setSelected(true);

    statusMessage = card.canChangeSuit
        ? '${card.rankText} selected! Click discard pile to choose suit.'
        : 'Click the discard pile to play ${card.displayText}';
  }

  /// Queens stack with Queens; Aces stack with Aces.
  bool _canStackDrawCard(CrazyEightsCard card) {
    if (drawCount == 0) return false;
    final top = discardPile.last;
    return (top.isQueen && card.isQueen) || (top.isAce && card.isAce);
  }

  /// Plays a card out of turn when the human holds an identical card to the
  /// current discard top. Resets [currentPlayerIndex] to 0 (human).
  void _performJumpIn(int cardIndex) {
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);
    statusMessage = '⚡ JUMP-IN! You played ${card.displayText}!';

    if (playerHand.length == 1) hasCalledCrazyEights[0] = false;

    currentPlayerIndex = 0;

    if (card.isJack) {
      pendingJackCard = card;
      showJackChoice  = true;
      statusMessage   = '⚡ JUMP-IN! Choose Jack action...';
      return;
    }

    _handleCardAction(card);
    _renderCards();

    if (playerHand.isEmpty) { _endGame('player'); return; }

    _checkCrazyEightsViolation(0);
    async_timer.Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) _nextTurn();
    });
  }

  void _showSuitPicker() {
    showSuitPicker = true;
    statusMessage  = 'Choose a suit!';
  }

  void _handleSuitPickerTap(Offset position) {
    if (!showSuitPicker) return;

    final buttonSize = screenWidth * 0.11;
    final gap        = screenWidth * 0.02;
    final totalWidth = buttonSize * 4 + gap * 3;
    final startX     = screenWidth / 2 - totalWidth / 2;
    final buttonY    = screenHeight / 2 + screenHeight * 0.25 / 4;

    final suits = [CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs, CardSuit.spades];

    for (var i = 0; i < 4; i++) {
      final x = startX + i * (buttonSize + gap);
      if (Rect.fromLTWH(x, buttonY - buttonSize / 2, buttonSize, buttonSize).contains(position)) {
        final cardIndex = playerCardComponents.indexOf(selectedCard!);
        if (cardIndex >= 0) _playCard(cardIndex, suits[i]);
        showSuitPicker = false;
        selectedCard   = null;
        return;
      }
    }
  }

  void _handleJackChoiceTap(Offset position) {
    if (!showJackChoice) return;

    final buttonW = screenWidth * 0.25;
    final buttonH = screenHeight * 0.07;
    final spacing = screenWidth * 0.04;
    final buttonY = screenHeight / 2 + screenHeight * 0.22 / 4;

    final skipRect    = Rect.fromCenter(center: Offset(screenWidth / 2 - buttonW / 2 - spacing / 2, buttonY), width: buttonW, height: buttonH);
    final reverseRect = Rect.fromCenter(center: Offset(screenWidth / 2 + buttonW / 2 + spacing / 2, buttonY), width: buttonW, height: buttonH);

    if (skipRect.contains(position)) {
      _executeJackChoice('skip');
    } else if (reverseRect.contains(position)) {
      _executeJackChoice('reverse');
    }
  }

  void _executeJackChoice(String choice) {
    showJackChoice      = false;
    isAwaitingJackChoice = false;

    if (choice == 'skip') {
      statusMessage += ' → Skipped next player!';
      _skipNextPlayer();
    } else {
      clockwise      = !clockwise;
      statusMessage += ' → Direction reversed!';
    }

    pendingJackCard = null;
    async_timer.Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) _nextTurn();
    });
  }

  void _handleDrawCard() {
    if (gameOver || currentPlayerIndex != 0 || showSuitPicker || showJackChoice) return;

    selectedCard?.setSelected(false);
    selectedCard = null;

    if (drawCount > 0) {
      // Player is accepting the penalty rather than stacking.
      for (var i = 0; i < drawCount; i++) playerHand.add(deck.drawCard());
      _sortPlayerHand();
      _renderCards();
      statusMessage  = 'Drew $drawCount penalty card(s).';
      drawCount      = 0;
      isDrawStacking = false;
      _nextTurn();
    } else {
      final drawnCard = deck.drawCard();
      playerHand.add(drawnCard);
      _sortPlayerHand();
      _renderCards();

      if (drawnCard.canPlayOn(discardPile.last, currentChosenSuit)) {
        statusMessage = 'Drew a card — you can play it or end turn.';
      } else {
        statusMessage = 'Drew a card — turn ending...';
        async_timer.Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver && currentPlayerIndex == 0) _nextTurn();
        });
      }
    }
  }

  // ─── Game logic ───────────────────────────────────────────────────────────

  void _playCard(int cardIndex, CardSuit? chosenSuit) {
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);

    selectedCard?.setSelected(false);
    selectedCard = null;

    currentChosenSuit = card.canChangeSuit ? chosenSuit : null;
    statusMessage     = 'You played ${card.displayText}!';

    if (playerHand.length != 1) hasCalledCrazyEights[0] = false;

    // Jack requires a player choice before the turn advances.
    if (card.isJack) {
      pendingJackCard = card;
      showJackChoice  = true;
      _renderCards();
      return;
    }

    _handleCardAction(card);
    _renderCards();

    if (playerHand.isEmpty) { _endGame('player'); return; }

    _checkCrazyEightsViolation(0);
    async_timer.Future.delayed(const Duration(milliseconds: 800), () {
      if (!gameOver) _nextTurn();
    });
  }

  /// Applies the special effect of [card] to the game state.
  ///
  /// Jack is excluded here because its effect depends on a UI choice and is
  /// handled asynchronously via [showJackChoice] / [_executeJackChoice].
  void _handleCardAction(CrazyEightsCard card) {
    if (card.isJack) return; // Resolved via dialog.

    if (card.isQueen) {
      drawCount      += 2;
      isDrawStacking  = true;
      statusMessage  += ' +2 added! Total: +$drawCount';
    } else if (card.isAce) {
      drawCount      += 4;
      isDrawStacking  = true;
      statusMessage  += ' +4 added! Total: +$drawCount';
    }
    // Kings only change suit, which is handled via [currentChosenSuit].
  }

  void _skipNextPlayer() => _advanceTurn();

  /// Advances the turn and either prompts the human player or triggers the AI.
  void _nextTurn() {
    _advanceTurn();

    if (currentPlayerIndex == 0) {
      if (drawCount > 0) {
        final stackable = [for (var i = 0; i < playerHand.length; i++) if (_canStackDrawCard(playerHand[i])) i];

        if (stackable.isNotEmpty) {
          statusMessage = 'Draw $drawCount cards or stack! Select a card.';
        } else {
          // No stackable cards — auto-draw the penalty and skip the turn.
          for (var i = 0; i < drawCount; i++) playerHand.add(deck.drawCard());
          _sortPlayerHand();
          statusMessage  = 'Drew $drawCount penalty card(s).';
          drawCount      = 0;
          isDrawStacking = false;
          _renderCards();
          async_timer.Future.delayed(const Duration(milliseconds: 800), () {
            if (!gameOver) _nextTurn();
          });
          return;
        }
      } else {
        statusMessage = 'Your turn! Play a card or draw.';
      }
    } else {
      statusMessage = 'Player ${currentPlayerIndex + 1}\'s turn...';
      _aiTakeTurn();
    }
  }

  void _advanceTurn() {
    if (clockwise) {
      currentPlayerIndex = (currentPlayerIndex + 1) % 4;
    } else {
      currentPlayerIndex = (currentPlayerIndex - 1 + 4) % 4;
    }
  }

  // ─── AI logic ─────────────────────────────────────────────────────────────

  /// Runs the AI turn after a 1.5-second thinking delay.
  ///
  /// Priority order: stack a draw card (80% chance) > play a legal card > draw.
  void _aiTakeTurn() {
    async_timer.Future.delayed(const Duration(milliseconds: 1500), () {
      if (gameOver) return;

      final aiIndex = currentPlayerIndex - 1;
      final aiHand  = aiHands[aiIndex];
      final topCard = discardPile.last;

      // Call Crazy Eights when the AI reaches 2 cards (pre-emptive declaration
      // before they might play down to 1 on their turn).
      if (aiHand.length == 2 && !hasCalledCrazyEights[currentPlayerIndex]) {
        hasCalledCrazyEights[currentPlayerIndex] = true;
      }

      if (drawCount > 0) {
        final stackable = [for (var i = 0; i < aiHand.length; i++) if (_canStackDrawCard(aiHand[i])) i];

        if (stackable.isNotEmpty && Random().nextDouble() < 0.8) {
          final card = aiHand.removeAt(stackable[0]);
          discardPile.add(card);
          aiCardCounts[aiIndex] = aiHand.length;

          if (card.canChangeSuit) currentChosenSuit = _aiChooseSuit(aiHand);
          drawCount     += card.isQueen ? 2 : 4;
          statusMessage  = 'Player ${currentPlayerIndex + 1} stacked! Total: +$drawCount';

          _renderCards();
          if (aiHand.isEmpty) { _endGame('ai${aiIndex + 1}'); return; }

          _checkCrazyEightsViolation(currentPlayerIndex);
          async_timer.Future.delayed(const Duration(milliseconds: 800), () {
            if (!gameOver) _nextTurn();
          });
          return;
        } else {
          for (var i = 0; i < drawCount; i++) aiHand.add(deck.drawCard());
          aiCardCounts[aiIndex] = aiHand.length;
          statusMessage  = 'Player ${currentPlayerIndex + 1} drew $drawCount penalty card(s).';
          drawCount      = 0;
          isDrawStacking = false;
          async_timer.Future.delayed(const Duration(milliseconds: 800), () {
            if (!gameOver) _nextTurn();
          });
          return;
        }
      }

      final playable = [for (var i = 0; i < aiHand.length; i++) if (aiHand[i].canPlayOn(topCard, currentChosenSuit)) i];

      if (playable.isEmpty) {
        aiHand.add(deck.drawCard());
        aiCardCounts[aiIndex] = aiHand.length;
        statusMessage = 'Player ${currentPlayerIndex + 1} drew a card.';
        async_timer.Future.delayed(const Duration(milliseconds: 800), () {
          if (!gameOver) _nextTurn();
        });
        return;
      }

      final card = aiHand.removeAt(_aiChooseCard(playable, aiHand));
      discardPile.add(card);
      aiCardCounts[aiIndex] = aiHand.length;

      if (card.canChangeSuit) {
        currentChosenSuit = _aiChooseSuit(aiHand);
        final suitNames   = {CardSuit.hearts: 'Hearts', CardSuit.diamonds: 'Diamonds', CardSuit.clubs: 'Clubs', CardSuit.spades: 'Spades'};
        statusMessage     = 'Player ${currentPlayerIndex + 1} played ${card.displayText} (chose ${suitNames[currentChosenSuit]})';
      } else {
        currentChosenSuit = null;
        statusMessage     = 'Player ${currentPlayerIndex + 1} played ${card.displayText}';
      }

      if (aiHand.length != 1) hasCalledCrazyEights[currentPlayerIndex] = false;

      if (card.isJack) {
        final choice = _aiChooseJackAction();
        if (choice == 'skip') {
          statusMessage += ' (skip)';
          _skipNextPlayer();
        } else {
          statusMessage += ' (reverse)';
          clockwise = !clockwise;
        }
      } else {
        _handleCardAction(card);
      }

      if (aiHand.isEmpty) { _endGame('ai${aiIndex + 1}'); return; }

      _renderCards();
      _checkCrazyEightsViolation(currentPlayerIndex);
      async_timer.Future.delayed(const Duration(milliseconds: 800), () {
        if (!gameOver) _nextTurn();
      });
    });
  }

  /// Chooses the best card to play using a simple priority hierarchy:
  /// Ace > Queen > Jack > King > highest number card.
  int _aiChooseCard(List<int> playable, List<CrazyEightsCard> hand) {
    var bestIndex = playable[0];
    var bestCard  = hand[playable[0]];

    for (var index in playable) {
      final card = hand[index];
      if (card.isAce)                                                 { return index; }
      if (card.isQueen && !bestCard.isAce)                            { bestIndex = index; bestCard = card; continue; }
      if (card.isJack  && !bestCard.isQueen && !bestCard.isAce)       { bestIndex = index; bestCard = card; continue; }
      if (card.isKing  && !bestCard.isAction)                         { bestIndex = index; bestCard = card; continue; }
      if (!card.isAction && !bestCard.isAction && card.numericValue > bestCard.numericValue) {
        bestIndex = index; bestCard = card;
      }
    }

    return bestIndex;
  }

  /// AI skips the next player if they have few cards (threatening to win);
  /// otherwise chooses randomly between skip and reverse.
  String _aiChooseJackAction() {
    final nextIndex = clockwise
        ? (currentPlayerIndex + 1) % 4
        : (currentPlayerIndex - 1 + 4) % 4;
    final nextCards = nextIndex == 0
        ? playerHand.length
        : aiHands[nextIndex - 1].length;

    return nextCards <= 2 ? 'skip' : (Random().nextBool() ? 'skip' : 'reverse');
  }

  /// Chooses the suit the AI holds the most of, maximising playability on
  /// the next turn.
  CardSuit _aiChooseSuit(List<CrazyEightsCard> hand) {
    final counts = {CardSuit.hearts: 0, CardSuit.diamonds: 0, CardSuit.clubs: 0, CardSuit.spades: 0};
    for (var card in hand) {
      if (!card.canChangeSuit) counts[card.suit] = (counts[card.suit] ?? 0) + 1;
    }

    var best  = CardSuit.hearts;
    var bestN = 0;
    counts.forEach((suit, n) { if (n > bestN) { bestN = n; best = suit; } });
    return best;
  }

  void _endGame(String winnerName) {
    gameOver      = true;
    winner        = winnerName == 'player' ? 'player' : 'ai';
    statusMessage = winner == 'player' ? 'YOU WIN!' : 'You lose!';
    challengeTimer?.cancel();
  }

  @override
  void onTapDown(TapDownEvent info) {
    final position = info.localPosition.toOffset();
    if (showSuitPicker) {
      _handleSuitPickerTap(position);
    } else if (showJackChoice) {
      _handleJackChoiceTap(position);
    }
  }
}

/// A face-down draw pile showing the remaining card count.
class DrawPileComponent extends PositionComponent with TapCallbacks {
  final VoidCallback onTap;
  final int remainingCards;

  DrawPileComponent({
    required Vector2 position,
    required Vector2 size,
    required this.onTap,
    required this.remainingCards,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final rect  = Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0B3A79));

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DRAW\n$remainingCards',
        style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: size.y * 0.1,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.textPrimary.withValues(alpha: 0.5),
    );
  }

  @override
  void onTapUp(TapUpEvent event) => onTap();
}

/// A red labelled button used for both the "Crazy Eights!" call and
/// the "Challenge!" action. Darkens on press for tactile feedback.
class CrazyEightsButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onTap;
  bool _isPressed = false;

  CrazyEightsButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    required this.onTap,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final rect  = Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.drawRRect(rrect, Paint()..color = _isPressed ? Colors.red.shade700 : Colors.red);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.textPrimary,
    );
  }

  @override
  void onTapDown(TapDownEvent event)   { _isPressed = true; }

  @override
  void onTapUp(TapUpEvent event)       { _isPressed = false; onTap(); }

  @override
  void onTapCancel(TapCancelEvent event) { _isPressed = false; }
}