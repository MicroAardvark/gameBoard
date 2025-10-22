import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class GameButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback? onTap;
  bool hidden = false;
  bool isEnabled = true;

  GameButton({
    required Vector2 position,
    required Vector2 size,
    required this.text,
    this.onTap,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    if (hidden) return;
    
    // Create the button rectangle centered around (0, 0) in local coordinates
    // Since anchor is center, we need to draw from negative coordinates
    final rect = Rect.fromLTWH(
      -size.x / 2,  // Start from left edge
      -size.y / 2,  // Start from top edge
      size.x,       // Width
      size.y,       // Height
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    
    // Draw button background
    final paint = Paint()
      ..color = isEnabled ? Colors.blue : Colors.grey
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);

    // Draw button text
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,  // Explicit font size for visibility
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    
    // Center the text around (0, 0)
    tp.paint(
      canvas,
      Offset(-tp.width / 2, -tp.height / 2),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (hidden) return;
    if (isEnabled && onTap != null) onTap!();
  }
}