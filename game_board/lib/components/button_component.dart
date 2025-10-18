import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class GameButton extends RectangleComponent with TapCallbacks {
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
    final rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12));
    final paint = Paint()
      ..color = isEnabled ? Colors.blue : Colors.grey
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2));
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (hidden) return;
    if (isEnabled && onTap != null) onTap!();
  }
}
