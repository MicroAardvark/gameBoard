// ====================================
// lib/components/multiplayer_player.dart
// Component for displaying other players in multiplayer blackjack
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
  String status = 'Waiting'; // 'Waiting', 'Betting', 'Playing', 'Stand', 'Busted', 'Blackjack!', 'Won', 'Lost'
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
  }) : super(position: anchorPos, anchor: Anchor.center);

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
    status = 'Waiting';
    isCurrentTurn = false;
  }

  // ===========================================
  // Rendering
  // ===========================================
  
  @override
  void render(Canvas canvas) {
    if (!isActive) return;

    // Draw background panel
    _drawPanel(canvas);

    // Draw player info
    _drawPlayerInfo(canvas);

    // Draw cards if any
    if (cardCount > 0) {
      _drawCards(canvas);
    }

    // Draw turn indicator
    if (isCurrentTurn) {
      _drawTurnIndicator(canvas);
    }

    // Draw ready indicator
    if (isReady && status == 'Waiting') {
      _drawReadyIndicator(canvas);
    }
  }

  void _drawPanel(Canvas canvas) {
    final panelWidth = cardSize.x * 2.5;
    final panelHeight = cardSize.y * 1.4;
    
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: panelWidth,
      height: panelHeight,
    );
    
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    
    // Background with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: (0.6)),
        Colors.black.withValues(alpha: (0.8)),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(rrect, paint);
    
    // Border
    final borderPaint = Paint()
      ..color = isCurrentTurn ? Colors.amber : Colors.white.withValues(alpha: (0.3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCurrentTurn ? 3 : 2;
    
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawPlayerInfo(Canvas canvas) {
    // Username
    final namePainter = TextPainter(
      text: TextSpan(
        text: username,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    namePainter.paint(
      canvas,
      Offset(-namePainter.width / 2, -cardSize.y * 0.55),
    );

    // Bankroll
    final bankrollPainter = TextPainter(
      text: TextSpan(
        text: '£${bankroll.toStringAsFixed(0)}',
        style: TextStyle(
          color: Colors.amber[400],
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    bankrollPainter.paint(
      canvas,
      Offset(-bankrollPainter.width / 2, -cardSize.y * 0.35),
    );

    // Status
    final statusPainter = TextPainter(
      text: TextSpan(
        text: status,
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    statusPainter.paint(
      canvas,
      Offset(-statusPainter.width / 2, cardSize.y * 0.35),
    );
  }

  Color _getStatusColor() {
    if (status.contains('Won') || status.contains('Blackjack')) {
      return Colors.greenAccent;
    } else if (status.contains('Lost') || status.contains('Busted')) {
      return Colors.redAccent;
    } else if (status.contains('Stand')) {
      return Colors.lightBlueAccent;
    } else if (isCurrentTurn) {
      return Colors.amber;
    } else {
      return Colors.white70;
    }
  }

  void _drawCards(Canvas canvas) {
    final spacing = cardSize.x * 0.6;
    final startX = -(cardCount - 1) * spacing / 2;

    for (int i = 0; i < cardCount; i++) {
      final x = startX + (i * spacing);
      final y = 0.0;
      
      _drawCardBack(canvas, Offset(x, y));
    }
  }

  void _drawCardBack(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(
      center: center,
      width: cardSize.x,
      height: cardSize.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    
    // Card back color
    final backPaint = Paint()..color = const Color(0xFF0B3A79);
    canvas.drawRRect(rrect, backPaint);
    
    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black.withValues(alpha: (0.5));
    canvas.drawRRect(rrect, borderPaint);
    
    // Pattern
    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.15))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, cardSize.x * 0.25, patternPaint);
  }

  void _drawTurnIndicator(Canvas canvas) {
    final radius = 8.0;
    final position = Offset(0, -cardSize.y * 0.7);
    
    // Pulsing circle
    final pulsePaint = Paint()
      ..color = Colors.amber.withValues(alpha: (0.4))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius + 4, pulsePaint);
    
    // Inner circle
    final indicatorPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius, indicatorPaint);
  }

  void _drawReadyIndicator(Canvas canvas) {
    final checkSize = 20.0;
    final position = Offset(cardSize.x * 0.7, -cardSize.y * 0.5);
    
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, checkSize / 2, bgPaint);
    
    // Checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final path = Path()
      ..moveTo(position.dx - checkSize * 0.25, position.dy)
      ..lineTo(position.dx - checkSize * 0.08, position.dy + checkSize * 0.2)
      ..lineTo(position.dx + checkSize * 0.25, position.dy - checkSize * 0.2);
    
    canvas.drawPath(path, checkPaint);
  }
}