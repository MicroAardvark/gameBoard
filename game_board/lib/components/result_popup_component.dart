// lib/components/result_popup_component.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../theme/app_theme.dart';

/// A full-screen modal popup that displays the result of a Blackjack round.
///
/// Animates in with a scale-and-fade effect, displays for 3 seconds, then
/// fades out and removes itself. Can also be dismissed early by tapping anywhere
/// on screen. [onDismiss] is called after the fade-out completes.
class ResultPopupComponent extends PositionComponent with TapCallbacks {
  final String mainText;
  final String amountText;
  final bool isWin;
  final VoidCallback? onDismiss;

  double _opacity = 0.0;
  double _scale = 0.5;
  late Vector2 _screenSize;
  bool isDismissed = false;

  /// Priority 1000 ensures the popup renders above all other game components.
  ResultPopupComponent({
    required this.mainText,
    required this.amountText,
    required this.isWin,
    this.onDismiss,
  }) : super(priority: 1000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Cover the full game canvas so the overlay blocks all interaction beneath.
    final game = findGame();
    _screenSize = game?.size.clone() ?? Vector2(800, 600);
    position = Vector2.zero();
    size = _screenSize;
    anchor = Anchor.topLeft;

    // Auto-dismiss if the player does not tap within 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (!isDismissed) dismiss();
    });
  }

  /// Triggers the fade-out sequence. Idempotent — safe to call multiple times.
  void dismiss() {
    if (isDismissed) return;
    isDismissed = true;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isDismissed) dismiss();
  }

  /// Drives the entry and exit animations each frame.
  ///
  /// Entry: opacity and scale rise together so the box appears to grow into
  /// view. Exit: opacity falls faster than scale shrinks to give a "snap away"
  /// feel rather than a plain fade. The component removes itself once fully
  /// transparent to keep the component tree clean.
  @override
  void update(double dt) {
    super.update(dt);

    if (_opacity < 1.0 && !isDismissed) {
      _opacity = (_opacity + dt * 4.0).clamp(0.0, 1.0);
      _scale = 0.5 + (_opacity * 0.5);
    } else if (isDismissed) {
      _opacity = (_opacity - dt * 5.0).clamp(0.0, 1.0);
      _scale = 1.0 - ((1.0 - _opacity) * 0.2);

      if (_opacity <= 0.0) {
        removeFromParent();
        onDismiss?.call();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity <= 0.0) return;

    // Navy scrim drawn first across the full screen to dim the game behind
    // the popup without completely obscuring it.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _screenSize.x, _screenSize.y),
      Paint()..color = AppColors.primaryNavyDark.withValues(alpha: 0.7 * _opacity),
    );

    // All subsequent drawing is done in a translated+scaled context centred
    // on screen, so coordinates below treat (0,0) as the popup centre.
    canvas.save();
    canvas.translate(_screenSize.x / 2, _screenSize.y / 2);
    canvas.scale(_scale);

    final boxWidth  = _screenSize.x * 0.6;
    final boxHeight = _screenSize.y * 0.3;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: boxWidth, height: boxHeight),
      const Radius.circular(20),
    );

    // Green gradient for wins, red for losses — colours chosen to be
    // immediately readable without relying on the text alone.
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -boxHeight / 2),
          Offset(0,  boxHeight / 2),
          isWin
              ? [
                  Color(0xFF2E7D32).withValues(alpha: 0.95 * _opacity),
                  Color(0xFF1B5E20).withValues(alpha: 0.95 * _opacity),
                ]
              : [
                  Color(0xFFC62828).withValues(alpha: 0.95 * _opacity),
                  Color(0xFF8E0000).withValues(alpha: 0.95 * _opacity),
                ],
        ),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = (isWin ? AppColors.primaryNavyLight : Colors.redAccent)
            .withValues(alpha: 0.8 * _opacity),
    );

    _paintCentred(
      canvas,
      text: isWin ? '🎉' : '💔',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: boxHeight * 0.25,
        color: AppColors.textPrimary.withValues(alpha: _opacity),
      ),
      yOffset: -boxHeight * 0.3,
    );

    _paintCentred(
      canvas,
      text: mainText,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: boxHeight * 0.15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary.withValues(alpha: _opacity),
        shadows: [
          Shadow(
            blurRadius: 4,
            color: AppColors.primaryNavyDark.withValues(alpha: 0.5),
            offset: const Offset(2, 2),
          ),
        ],
      ),
      yOffset: -boxHeight * 0.05,
    );

    // Amount is yellow on a win to draw the eye; white on a loss to stay neutral.
    _paintCentred(
      canvas,
      text: amountText,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: boxHeight * 0.18,
        fontWeight: FontWeight.bold,
        color: (isWin ? Colors.yellowAccent : AppColors.textPrimary)
            .withValues(alpha: _opacity),
        shadows: [
          Shadow(
            blurRadius: 6,
            color: AppColors.primaryNavyDark.withValues(alpha: 0.6),
            offset: const Offset(2, 2),
          ),
        ],
      ),
      yOffset: boxHeight * 0.12,
    );

    _paintCentred(
      canvas,
      text: 'Tap to continue',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: boxHeight * 0.08,
        fontStyle: FontStyle.italic,
        color: AppColors.textPrimary.withValues(alpha: _opacity * 0.8),
      ),
      yOffset: boxHeight * 0.35,
    );

    canvas.restore();
  }

  /// Lays out [text] with [style] and paints it horizontally centred at [yOffset]
  /// relative to the current canvas origin (the popup centre after translation).
  void _paintCentred(
    Canvas canvas, {
    required String text,
    required TextStyle style,
    required double yOffset,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    painter.paint(canvas, Offset(-painter.width / 2, yOffset));
  }

  /// The popup covers the full screen so every local point is a valid tap target
  /// while it is visible, blocking interaction with components beneath.
  @override
  bool containsLocalPoint(Vector2 point) => !isDismissed;
}