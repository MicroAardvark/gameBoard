// ==================================================================================
// FILE: game_board/lib/components/button_component.dart
// FINAL VERSION - Anchor.centerLeft with proper tap detection
// ==================================================================================

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom rectangular game button with Anchor.centerLeft
/// Position = left edge of button (simplest positioning)
class GameButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback? onTap;

  bool hidden = false;
  bool isEnabled = true;
  bool _isPressed = false;

  GameButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    this.onTap,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.centerLeft,
        );

  @override
  void render(Canvas canvas) {
    if (hidden) return;

    // Rect starts at (0, -size.y/2) for centerLeft anchor
    final rect = Rect.fromLTWH(
      0,              // Left edge at anchor position
      -size.y / 2,    // Vertically centered
      size.x,
      size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Button background color
    final Color bgColor;
    if (!isEnabled) {
      bgColor = Colors.grey;
    } else if (_isPressed) {
      bgColor = Colors.blue.shade700;
    } else {
      bgColor = Colors.blue;
    }

    final paint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);

    // Button text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Inter', 
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);

    // Draw text centered horizontally in the button
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        -textPainter.height / 2,
      ),
    );
  }

  // CRITICAL: Override tap detection to match rendered area
  @override
  bool containsLocalPoint(Vector2 point) {
    if (hidden) return false;
    
    // For centerLeft anchor, button extends from (0, -size.y/2) to (size.x, size.y/2)
    return point.x >= 0 && 
           point.x <= size.x && 
           point.y >= -size.y / 2 && 
           point.y <= size.y / 2;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (hidden || !isEnabled) return;
    _isPressed = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (hidden) return;
    if (isEnabled && onTap != null) {
      onTap!();
    }
    _isPressed = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isPressed = false;
  }
}

// ==================================================================================
// This version uses Anchor.centerLeft with proper tap detection override
// Use with simple positioning: position.x = leftMargin (e.g., 20)
// ==================================================================================