// lib/components/uno_card_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/uno_card.dart';

class UnoCardComponent extends PositionComponent {
  final UnoCard card;
  bool isHidden;
  bool isSelected;

  UnoCardComponent({
    required Vector2 position,
    required Vector2 size,
    required this.card,
    this.isHidden = false,
    this.isSelected = false,
  }) : super(position: position, size: size, anchor: Anchor.center);

  void toggleSelected() {
    isSelected = !isSelected;
  }

  void setSelected(bool selected) {
    isSelected = selected;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    if (isHidden) {
      _renderCardBack(canvas, rrect);
    } else {
      _renderCardFace(canvas, rrect);
    }

    // Draw selection indicator if selected
    if (isSelected) {
      _renderSelectionIndicator(canvas, rrect);
    }
  }

  void _renderCardBack(Canvas canvas, RRect rrect) {
    // UNO card back - colorful pattern
    final backPaint = Paint()..color = Colors.black;
    canvas.drawRRect(rrect, backPaint);

    // Draw "UNO" text pattern
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: size.y * 0.15,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: 'UNO', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        size.x / 2 - textPainter.width / 2,
        size.y / 2 - textPainter.height / 2,
      ),
    );

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.red;
    canvas.drawRRect(rrect, borderPaint);
  }

  void _renderCardFace(Canvas canvas, RRect rrect) {
    // Card background
    final backgroundPaint = Paint()..color = card.displayColor;
    canvas.drawRRect(rrect, backgroundPaint);

    // Wild card special background
    if (card.isWild) {
      _drawWildBackground(canvas, rrect);
    }

    // White center oval
    final centerOval = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: size.x * 0.65,
        height: size.y * 0.85,
      ),
      const Radius.circular(60),
    );
    final centerPaint = Paint()..color = Colors.white;
    canvas.drawRRect(centerOval, centerPaint);

    // Draw value/symbol in center
    _drawCenterSymbol(canvas);

    // Top-left and bottom-right corner symbols
    _drawCornerSymbol(canvas, isTopLeft: true);
    _drawCornerSymbol(canvas, isTopLeft: false);

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawWildBackground(Canvas canvas, RRect rrect) {
    // Create quadrant colors for wild cards
    final colors = [
      const Color(0xFFE53935), // red
      const Color(0xFF1E88E5), // blue
      const Color(0xFF43A047), // green
      const Color(0xFFFDD835), // yellow
    ];

    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;

    // Draw four colored corners
    final cornerPaint = Paint();
    
    // Top-left: Red
    cornerPaint.color = colors[0];
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(halfWidth, 0)
        ..lineTo(halfWidth, halfHeight)
        ..lineTo(0, halfHeight)
        ..close(),
      cornerPaint,
    );

    // Top-right: Blue
    cornerPaint.color = colors[1];
    canvas.drawPath(
      Path()
        ..moveTo(halfWidth, 0)
        ..lineTo(size.x, 0)
        ..lineTo(size.x, halfHeight)
        ..lineTo(halfWidth, halfHeight)
        ..close(),
      cornerPaint,
    );

    // Bottom-left: Green
    cornerPaint.color = colors[2];
    canvas.drawPath(
      Path()
        ..moveTo(0, halfHeight)
        ..lineTo(halfWidth, halfHeight)
        ..lineTo(halfWidth, size.y)
        ..lineTo(0, size.y)
        ..close(),
      cornerPaint,
    );

    // Bottom-right: Yellow
    cornerPaint.color = colors[3];
    canvas.drawPath(
      Path()
        ..moveTo(halfWidth, halfHeight)
        ..lineTo(size.x, halfHeight)
        ..lineTo(size.x, size.y)
        ..lineTo(halfWidth, size.y)
        ..close(),
      cornerPaint,
    );
  }

  void _drawCenterSymbol(Canvas canvas) {
    final textStyle = TextStyle(
      color: card.isWild ? Colors.white : card.displayColor,
      fontSize: size.y * 0.35,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: card.displayText, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        size.x / 2 - textPainter.width / 2,
        size.y / 2 - textPainter.height / 2,
      ),
    );
  }

  void _drawCornerSymbol(Canvas canvas, {required bool isTopLeft}) {
    final textStyle = TextStyle(
      color: card.isWild ? Colors.white : card.displayColor,
      fontSize: size.y * 0.12,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: card.displayText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = isTopLeft
        ? Offset(size.x * 0.12, size.y * 0.08)
        : Offset(
            size.x - textPainter.width - size.x * 0.12,
            size.y - textPainter.height - size.y * 0.08,
          );

    canvas.save();
    if (!isTopLeft) {
      // Rotate bottom-right symbol 180 degrees
      canvas.translate(offset.dx + textPainter.width / 2, offset.dy + textPainter.height / 2);
      canvas.rotate(3.14159); // 180 degrees in radians
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
    } else {
      textPainter.paint(canvas, offset);
    }
    canvas.restore();
  }

  void _renderSelectionIndicator(Canvas canvas, RRect rrect) {
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.yellowAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawRRect(rrect, glowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.yellow;
    
    canvas.drawRRect(rrect, borderPaint);
  }
}