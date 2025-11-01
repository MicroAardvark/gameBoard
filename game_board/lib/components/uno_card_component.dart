// lib/components/uno_card_component.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/uno_card.dart';

class UnoCardComponent extends PositionComponent with TapCallbacks {
  final UnoCard card;
  bool isHidden;
  bool isSelected;
  final Function(UnoCardComponent)? onTap;
  
  // Store original position and size for animation
  Vector2? _originalPosition;
  Vector2? _originalSize;
  int? _originalPriority;

  UnoCardComponent({
    required Vector2 position,
    required Vector2 size,
    required this.card,
    this.isHidden = false,
    this.isSelected = false,
    this.onTap,
  }) : super(position: position, size: size, anchor: Anchor.center);

  void toggleSelected() {
    isSelected = !isSelected;
    _updateSelectionVisuals();
  }

  void setSelected(bool selected) {
    if (isSelected != selected) {
      isSelected = selected;
      _updateSelectionVisuals();
    }
  }

  void _updateSelectionVisuals() {
    if (isSelected) {
      // Store original values
      _originalPosition = position.clone();
      _originalSize = size.clone();
      _originalPriority = priority;
      
      // Scale up and move forward
      size = _originalSize! * 1.3;
      position = Vector2(_originalPosition!.x, _originalPosition!.y - 40);
      priority = 1000; // Move to front
    } else {
      // Restore original values
      if (_originalPosition != null) {
        position = _originalPosition!.clone();
      }
      if (_originalSize != null) {
        size = _originalSize!.clone();
      }
      if (_originalPriority != null) {
        priority = _originalPriority!;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // FIXED: Since anchor is center, draw relative to (0,0) which is the center
    final rect = Rect.fromCenter(
      center: Offset.zero,
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
        -textPainter.width / 2,
        -textPainter.height / 2,
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
        center: Offset.zero,
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

    // Draw four colored corners relative to center (0,0)
    final cornerPaint = Paint();
    
    // Top-left: Red
    cornerPaint.color = colors[0];
    canvas.drawPath(
      Path()
        ..moveTo(-halfWidth, -halfHeight)
        ..lineTo(0, -halfHeight)
        ..lineTo(0, 0)
        ..lineTo(-halfWidth, 0)
        ..close(),
      cornerPaint,
    );

    // Top-right: Blue
    cornerPaint.color = colors[1];
    canvas.drawPath(
      Path()
        ..moveTo(0, -halfHeight)
        ..lineTo(halfWidth, -halfHeight)
        ..lineTo(halfWidth, 0)
        ..lineTo(0, 0)
        ..close(),
      cornerPaint,
    );

    // Bottom-left: Green
    cornerPaint.color = colors[2];
    canvas.drawPath(
      Path()
        ..moveTo(-halfWidth, 0)
        ..lineTo(0, 0)
        ..lineTo(0, halfHeight)
        ..lineTo(-halfWidth, halfHeight)
        ..close(),
      cornerPaint,
    );

    // Bottom-right: Yellow
    cornerPaint.color = colors[3];
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(halfWidth, 0)
        ..lineTo(halfWidth, halfHeight)
        ..lineTo(0, halfHeight)
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
        -textPainter.width / 2,
        -textPainter.height / 2,
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

    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;

    final offset = isTopLeft
        ? Offset(-halfWidth + size.x * 0.12, -halfHeight + size.y * 0.08)
        : Offset(
            halfWidth - textPainter.width - size.x * 0.12,
            halfHeight - textPainter.height - size.y * 0.08,
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

  // Tap detection
  @override
  void onTapUp(TapUpEvent event) {
    if (!isHidden && onTap != null) {
      onTap!(this);
    }
    super.onTapUp(event);
  }
}