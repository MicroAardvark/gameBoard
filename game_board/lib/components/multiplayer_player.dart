// lib/components/multiplayer_player.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders a remote player's name, bankroll, status, and hidden cards
/// as a lightweight HUD element positioned around the table edge.
///
/// [rightSide] flips text alignment and card layout so the component reads
/// correctly whether it is placed on the left or right side of the screen.
class MultiplayerPlayerUI extends PositionComponent {
  final String playerId;
  String username;
  double bankroll;
  final Vector2 anchorPos;
  final Vector2 cardsCenter;
  final Vector2 cardSize;
  final bool rightSide;

  int cardCount = 0;
  double currentBet = 0;
  String status = '';
  bool isReady = false;
  bool isActive = true;
  bool isCurrentTurn = false;

  MultiplayerPlayerUI({
    required this.playerId,
    required this.username,
    required this.bankroll,
    required this.anchorPos,
    required this.cardsCenter,
    required this.cardSize,
    this.rightSide = false,
  }) : super(position: anchorPos);

  // ─── State update methods ────────────────────────────────────────────────

  void updateBankroll(double newBankroll) => bankroll = newBankroll;

  /// Updates the displayed bet amount and sets the status label to match.
  void updateBet(double bet) {
    currentBet = bet;
    status = 'Bet: £${bet.toStringAsFixed(0)}';
  }

  void setStatus(String newStatus) => status = newStatus;
  void setReady(bool ready)        => isReady = ready;
  void setActive(bool active)      => isActive = active;
  void setTurn(bool isTurn)        => isCurrentTurn = isTurn;
  void addCard()                   => cardCount++;
  void setCardCount(int count)     => cardCount = count;
  void clearCards()                => cardCount = 0;

  /// Resets per-round state while preserving identity fields
  /// ([playerId], [username], [bankroll], [isActive]).
  void reset() {
    cardCount = 0;
    currentBet = 0;
    status = '';
    isCurrentTurn = false;
  }

  // ─── Rendering ───────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    _drawPlayerInfo(canvas);
    if (cardCount > 0) _drawCards(canvas);
  }

  /// Draws the combined name/bankroll label, optional status line, and
  /// the turn indicator dot when it is this player's turn to act.
  void _drawPlayerInfo(Canvas canvas) {
    final displayText = '$username • £${bankroll.toStringAsFixed(0)}';

    // Amber text and bold weight signal whose turn it currently is.
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          fontFamily: 'Inter',
          color: isCurrentTurn ? Colors.amber : AppColors.textPrimary,
          fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.w600,
          fontSize: 16,
          shadows: [
            Shadow(
              blurRadius: 8,
              color: AppColors.primaryNavyDark.withValues(alpha: 0.8),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: rightSide ? TextAlign.right : TextAlign.left,
    )..layout();

    // Right-side players are right-aligned, so shift by their own width
    // to keep the text flush with the anchor rather than overflowing inward.
    textPainter.paint(canvas, rightSide ? Offset(-textPainter.width, 0) : Offset.zero);

    if (status.isNotEmpty) {
      final statusPainter = TextPainter(
        text: TextSpan(
          text: status,
          style: TextStyle(
            fontFamily: 'Inter',
            color: _getStatusColor(),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                blurRadius: 6,
                color: AppColors.primaryNavyDark.withValues(alpha: 0.8),
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: rightSide ? TextAlign.right : TextAlign.left,
      )..layout();

      statusPainter.paint(
        canvas,
        rightSide ? Offset(-statusPainter.width, 25) : const Offset(0, 25),
      );
    }

    if (isCurrentTurn) _drawTurnIndicator(canvas);
  }

  /// Maps the current [status] string to a colour so players can read
  /// game outcomes at a glance without parsing the text.
  Color _getStatusColor() {
    if (status.contains('Won') || status.contains('Blackjack')) {
      return AppColors.primaryNavyLight;
    } else if (status.contains('Lost') || status.contains('Busted')) {
      return Colors.redAccent;
    } else if (status.contains('Stand')) {
      return Colors.lightBlueAccent;
    } else if (status.contains('Bet')) {
      return Colors.amber;
    }
    return AppColors.textPrimary;
  }

  /// Draws [cardCount] face-down card backs fanned out below the player label.
  ///
  /// Cards fan leftward for right-side players so they remain visible
  /// and don't overlap the table centre.
  void _drawCards(Canvas canvas) {
    const cardStartY = 50.0;
    final spacing = cardSize.x * 0.7;

    for (int i = 0; i < cardCount; i++) {
      final x = rightSide
          ? -(i * spacing) - cardSize.x / 2
          : (i * spacing);
      _drawCardBack(canvas, Offset(x, cardStartY));
    }
  }

  /// Draws a single face-down card with a navy fill, faint border, and
  /// a circular pattern matching the single-player card back style.
  void _drawCardBack(Canvas canvas, Offset position) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(position.dx, position.dy, cardSize.x, cardSize.y),
      const Radius.circular(8),
    );

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0B3A79));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textPrimary.withValues(alpha: 0.3),
    );

    // Single circle pattern kept minimal to avoid visual noise at small card sizes.
    canvas.drawCircle(
      Offset(position.dx + cardSize.x / 2, position.dy + cardSize.y / 2),
      cardSize.x * 0.25,
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Draws a gold dot with an outer glow adjacent to the player label
  /// to clearly indicate it is this player's turn to act.
  void _drawTurnIndicator(Canvas canvas) {
    const radius = 6.0;
    // Offset places the dot just outside the left edge of the name label
    // on both sides of the table without overlapping the text.
    final offset = rightSide ? const Offset(-10, 8) : const Offset(-15, 8);

    canvas.drawCircle(
      offset,
      radius + 3,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      offset,
      radius,
      Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill,
    );
  }
}