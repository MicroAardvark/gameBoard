// lib/components/card_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../theme/app_theme.dart';

/// Renders a single playing card as a Flame [PositionComponent].
///
/// Supports two visual states — face-up and face-down — toggled via [flip].
/// All drawing coordinates are relative to [Anchor.center], meaning (0,0)
/// sits at the card's centre rather than its top-left corner.
class CardComponent extends PositionComponent {
  final PlayingCard card;
  bool isHidden;

  CardComponent({
    required Vector2 position,
    required Vector2 size,
    required this.card,
    this.isHidden = false,
  }) : super(position: position, size: size, anchor: Anchor.center);

  /// Toggles between face-up and face-down states.
  void flip() {
    isHidden = !isHidden;
  }

  @override
  void render(Canvas canvas) {
    // Anchor.center places the component origin at the card's centre, so
    // Offset.zero is correct here. Using Offset(size.x / 2, size.y / 2)
    // would shift the rect off-centre by half the card dimensions.
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    if (isHidden) {
      _renderBack(canvas, rrect);
    } else {
      _renderFace(canvas, rrect);
    }

    super.render(canvas);
  }

  /// Draws the card back: a solid navy fill, a faint border, and a circular
  /// decorative pattern centred on the component origin.
  void _renderBack(Canvas canvas, RRect rrect) {
    final backPaint = Paint()..color = const Color(0xFF0B3A79);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.5);

    canvas.drawRRect(rrect, backPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Subtle concentric circle at the card centre as a back pattern.
    final patternPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, size.x * 0.3, patternPaint);
  }

  /// Draws the card face: white background, rank/suit in the top-left corner,
  /// a large suit symbol in the centre, and a rotated rank/suit in the bottom-right.
  void _renderFace(Canvas canvas, RRect rrect) {
    final facePaint = Paint()..color = AppColors.textPrimary;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.3);

    canvas.drawRRect(rrect, facePaint);
    canvas.drawRRect(rrect, borderPaint);

    final textStyle = TextStyle(
      fontFamily: 'Inter',
      color: card.suitColor,
      fontSize: size.y * 0.25,
      fontWeight: FontWeight.bold,
    );

    // Top-left rank + suit. Offset is relative to the centre origin,
    // so negative values move toward the top-left of the card.
    final topLeftPainter = TextPainter(
      text: TextSpan(text: card.display, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    topLeftPainter.paint(canvas, Offset(-size.x * 0.4, -size.y * 0.4));

    // Large suit symbol, manually centred by subtracting half its own
    // dimensions since TextPainter has no built-in alignment against a point.
    final centerStyle = textStyle.copyWith(fontSize: size.y * 0.35);
    final centerPainter = TextPainter(
      text: TextSpan(text: card.suit, style: centerStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    centerPainter.paint(
      canvas,
      Offset(-centerPainter.width / 2, -centerPainter.height / 2),
    );

    // Bottom-right rank + suit, rotated 180° to read correctly from that corner.
    // canvas.save/restore isolates the rotation transform so it doesn't affect
    // any subsequent draw calls.
    canvas.save();
    canvas.translate(size.x * 0.4, size.y * 0.4);
    canvas.rotate(3.14159); // π radians = 180°
    final bottomRightPainter = TextPainter(
      text: TextSpan(text: card.display, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    bottomRightPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}