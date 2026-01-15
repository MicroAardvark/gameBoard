// lib/components/mock_player.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MockPlayerUI extends PositionComponent {
  final String name;
  final double bank;
  final Vector2 anchorPos;
  final Vector2 cardsCenter;
  final Vector2 cardSize;
  final bool rightSide;

  MockPlayerUI({
    required this.name,
    required this.bank,
    required this.anchorPos,
    required this.cardsCenter,
    required this.cardSize,
    this.rightSide = false,
  }) : super(position: anchorPos, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    // name + bank
    final nameTp = TextPainter(
      text: TextSpan(
        text: '$name  •  £${bank.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nameTp.paint(canvas, Offset(-nameTp.width / 2, -30));

    // two facedown cards (simple backs)
    void drawCardBack(Offset center) {
      final rect = Rect.fromCenter(center: center, width: cardSize.x, height: cardSize.y);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      final fill = Paint()..color = const Color(0xFF0B3A79);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primaryNavyDark.withValues(alpha: 0.5);
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
    }

    final dx = rightSide ? -cardSize.x * 0.55 : cardSize.x * 0.55;
    drawCardBack(Offset(cardsCenter.x - dx, cardsCenter.y));
    drawCardBack(Offset(cardsCenter.x + dx, cardsCenter.y));
  }
}