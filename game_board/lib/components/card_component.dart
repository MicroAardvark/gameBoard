// lib/components/card_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../theme/app_theme.dart';

class CardComponent extends PositionComponent {
  final PlayingCard card;
  bool isHidden;

  CardComponent({
    required Vector2 position,
    required Vector2 size,
    required this.card,
    this.isHidden = false,
  }) : super(position: position, size: size, anchor: Anchor.center);

  void flip() {
    isHidden = !isHidden;
  }

  @override
  void render(Canvas canvas) {
    // FIXED: Use Offset.zero because Anchor.center means (0,0) is at center
    final rect = Rect.fromCenter(
      center: Offset.zero,  // CHANGED from Offset(size.x / 2, size.y / 2)
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    if (isHidden) {
      // Card back
      final backPaint = Paint()..color = const Color(0xFF0B3A79);
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primaryNavyDark.withValues(alpha: 0.5);
      
      canvas.drawRRect(rrect, backPaint);
      canvas.drawRRect(rrect, borderPaint);
      
      // Optional: Add pattern to card back
      final patternPaint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset.zero,  // CHANGED from Offset(size.x / 2, size.y / 2)
        size.x * 0.3,
        patternPaint,
      );
    } else {
      // Card face
      final facePaint = Paint()..color = AppColors.textPrimary;
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primaryNavyDark.withValues(alpha: 0.3);
      
      canvas.drawRRect(rrect, facePaint);
      canvas.drawRRect(rrect, borderPaint);

      // Draw rank and suit
      final textStyle = TextStyle(
        fontFamily: 'Inter', 
        color: card.suitColor,
        fontSize: size.y * 0.25,
        fontWeight: FontWeight.bold,
      );

      // Top left corner - FIXED: Offset from center
      final topLeftPainter = TextPainter(
        text: TextSpan(text: card.display, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      topLeftPainter.paint(
        canvas, 
        Offset(-size.x * 0.4, -size.y * 0.4)  // CHANGED from Offset(size.x * 0.1, size.y * 0.1)
      );

      // Center (larger)
      final centerStyle = textStyle.copyWith(fontSize: size.y * 0.35);
      final centerPainter = TextPainter(
        text: TextSpan(text: card.suit, style: centerStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      centerPainter.paint(
        canvas,
        Offset(
          -centerPainter.width / 2,   // CHANGED: Center relative to (0,0)
          -centerPainter.height / 2,
        ),
      );

      // Bottom right corner (rotated) - FIXED: Offset from center
      canvas.save();
      canvas.translate(size.x * 0.4, size.y * 0.4);  // CHANGED from (size.x * 0.9, size.y * 0.9)
      canvas.rotate(3.14159); // 180 degrees
      final bottomRightPainter = TextPainter(
        text: TextSpan(text: card.display, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      bottomRightPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    super.render(canvas);
  }
}