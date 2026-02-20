// ==================================================================================
// FILE: game_board/lib/components/button_component.dart
// Function: Custom rectangular game button
// ==================================================================================

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable rectangular button built as a Flame [PositionComponent].
///
/// Flame does not provide a built-in button primitive, so this component
/// handles its own rendering and tap detection rather than delegating to Flutter widgets.
class GameButton extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback? onTap;

  bool hidden = false;
  bool isEnabled = true;
  bool _isPressed = false; // Tracks press state to drive visual feedback

  /// Creates a button centred on the left anchor point.
  ///
  /// [position] and [size] are in Flame's coordinate space (logical pixels).
  /// [onTap] is optional so buttons can be displayed in a disabled state
  /// without requiring a no-op callback at the call site.
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

    // The centerLeft anchor means the component's origin sits at the left-centre
    // of the button, so we offset the rect upward by half the height to keep
    // the shape visually centred around that point.
    final rect = Rect.fromLTWH(
      0,
      -size.y / 2,
      size.x,
      size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Visual state hierarchy: disabled > pressed > default.
    // Grey is used for disabled rather than reduced opacity so the button
    // remains clearly distinguishable regardless of the background colour.
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

    // TextPainter is used here because Flame's canvas is a raw Flutter Canvas,
    // which does not support Text widgets directly.
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

    // Offset calculation centres the text both horizontally within the button
    // width and vertically around the centerLeft anchor point.
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        -textPainter.height / 2,
      ),
    );
  }

  /// Overridden because Flame's default hit-testing assumes the anchor is at
  /// the top-left. With [Anchor.centerLeft], the rendered rect is offset by
  /// half the height, so the hit area must match that offset or taps near
  /// the button edges will be missed or incorrectly registered.
  @override
  bool containsLocalPoint(Vector2 point) {
    if (hidden) return false;

    return point.x >= 0 &&
           point.x <= size.x &&
           point.y >= -size.y / 2 &&
           point.y <= size.y / 2;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (hidden || !isEnabled) return;
    _isPressed = true;
    // No explicit repaint call needed; Flame re-renders every frame.
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (hidden) return;
    if (isEnabled && onTap != null) {
      onTap!();
    }
    _isPressed = false;
  }

  /// Called when a tap is interrupted (e.g. the pointer moved off-screen).
  /// Ensures the button does not remain visually stuck in the pressed state.
  @override
  void onTapCancel(TapCancelEvent event) {
    _isPressed = false;
  }
}