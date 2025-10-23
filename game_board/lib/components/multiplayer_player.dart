// ====================================
// lib/components/multiplayer_player.dart
// Component for displaying other players - UPDATED TO MATCH SINGLE PLAYER STYLE
// ====================================
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MultiplayerPlayerUI extends PositionComponent {
  final String playerId;
  String username;
  double bankroll;
  final Vector2 anchorPos;
  final Vector2 cardsCenter;
  final Vector2 cardSize;
  final bool rightSide;

  // State
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

  // ===========================================
  // Update Methods
  // ===========================================
  
  void updateBankroll(double newBankroll) {
    bankroll = newBankroll;
  }

  void updateBet(double bet) {
    currentBet = bet;
    status = 'Bet: £${bet.toStringAsFixed(0)}';
  }

  void setStatus(String newStatus) {
    status = newStatus;
  }

  void setReady(bool ready) {
    isReady = ready;
  }

  void setActive(bool active) {
    isActive = active;
  }

  void setTurn(bool isTurn) {
    isCurrentTurn = isTurn;
  }

  void addCard() {
    cardCount++;
  }

  void setCardCount(int count) {
    cardCount = count;
  }

  void clearCards() {
    cardCount = 0;
  }

  void reset() {
    cardCount = 0;
    currentBet = 0;
    status = '';
    isCurrentTurn = false;
  }

  // ===========================================
  // Rendering - UPDATED: Simpler style like single player
  // ===========================================
  
  @override
  void render(Canvas canvas) {
    if (!isActive) return;

    // Draw player name and bankroll (simpler, cleaner style)
    _drawPlayerInfo(canvas);

    // Draw cards if any
    if (cardCount > 0) {
      _drawCards(canvas);
    }
  }

  void _drawPlayerInfo(Canvas canvas) {
    // UPDATED: Simple text display like single player mock players
    // Format: "Player 2 • £1000"
    final displayText = '$username • £${bankroll.toStringAsFixed(0)}';
    
    final textStyle = TextStyle(
      color: isCurrentTurn ? Colors.amber : Colors.white,
      fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.w600,
      fontSize: 16,
      shadows: [
        Shadow(
          blurRadius: 8,
          color: Colors.black.withValues(alpha: 0.8),
          offset: const Offset(1, 1),
        ),
      ],
    );
    
    final textPainter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: rightSide ? TextAlign.right : TextAlign.left,
    )..layout();
    
    final textOffset = rightSide 
        ? Offset(-textPainter.width, 0)
        : Offset(0, 0);
    
    textPainter.paint(canvas, textOffset);

    // Show status below name if present
    if (status.isNotEmpty) {
      final statusStyle = TextStyle(
        color: _getStatusColor(),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.8),
            offset: const Offset(1, 1),
          ),
        ],
      );
      
      final statusPainter = TextPainter(
        text: TextSpan(text: status, style: statusStyle),
        textDirection: TextDirection.ltr,
        textAlign: rightSide ? TextAlign.right : TextAlign.left,
      )..layout();
      
      final statusOffset = rightSide 
          ? Offset(-statusPainter.width, 25)
          : Offset(0, 25);
      
      statusPainter.paint(canvas, statusOffset);
    }

    // Turn indicator (small dot)
    if (isCurrentTurn) {
      _drawTurnIndicator(canvas);
    }
  }

  Color _getStatusColor() {
    if (status.contains('Won') || status.contains('Blackjack')) {
      return Colors.greenAccent;
    } else if (status.contains('Lost') || status.contains('Busted')) {
      return Colors.redAccent;
    } else if (status.contains('Stand')) {
      return Colors.lightBlueAccent;
    } else if (status.contains('Bet')) {
      return Colors.amber;
    } else {
      return Colors.white70;
    }
  }

  void _drawCards(Canvas canvas) {
    // Position cards near the player name
    final cardStartY = 50.0;
    final spacing = cardSize.x * 0.7;
    
    for (int i = 0; i < cardCount; i++) {
      final x = rightSide 
          ? -(i * spacing) - cardSize.x / 2
          : (i * spacing);
      final y = cardStartY;
      
      _drawCardBack(canvas, Offset(x, y));
    }
  }

  void _drawCardBack(Canvas canvas, Offset position) {
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      cardSize.x,
      cardSize.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    
    // Card back color
    final backPaint = Paint()..color = const Color(0xFF0B3A79);
    canvas.drawRRect(rrect, backPaint);
    
    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawRRect(rrect, borderPaint);
    
    // Simple pattern
    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final centerX = position.dx + cardSize.x / 2;
    final centerY = position.dy + cardSize.y / 2;
    canvas.drawCircle(Offset(centerX, centerY), cardSize.x * 0.25, patternPaint);
  }

  void _drawTurnIndicator(Canvas canvas) {
    // Small pulsing indicator next to name
    final radius = 6.0;
    final offset = rightSide 
        ? Offset(-10, 8)
        : Offset(-15, 8);
    
    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, radius + 3, glowPaint);
    
    // Inner dot
    final dotPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, radius, dotPaint);
  }
}