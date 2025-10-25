import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// Custom rectangular game button used in both single-player and multiplayer HUDs.
/// This version fixes tap detection so the onTap callback actually fires
/// (uses `onTapUp` instead of `onTapDown`).
class GameButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback? onTap;

  bool hidden = false;
  bool isEnabled = true;
  bool _isPressed = false; // for optional visual feedback

  GameButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    this.onTap,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    if (hidden) return;

    final rect = Rect.fromLTWH(
      -size.x / 2,
      -size.y / 2,
      size.x,
      size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Button background color
    final Color bgColor;
    if (!isEnabled) {
      bgColor = Colors.grey;
    } else if (_isPressed) {
      bgColor = Colors.blue.shade700; // darker while pressed
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
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);

    // Draw centered text
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  // Optional press visual
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
