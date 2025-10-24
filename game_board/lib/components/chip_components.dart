// lib/components/chip_components.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Layout options for +/- buttons around a chip.
enum ButtonsLayout {
  diagonalTangent, // buttons at ±45°
  stackRight,      // buttons stacked on the right
  stackVertical,   // + on top, chip center, - below
}

/// Round +/- control with accurate circular hit test.
class ChipButton extends PositionComponent with TapCallbacks {
  final String symbol;
  final VoidCallback onPressed;
  final Color bgColor;
  final double radius;

  ChipButton({
    required this.symbol,
    required this.onPressed,
    required Vector2 position,
    required this.radius,
    required this.bgColor,
  }) : super(position: position, size: Vector2.all(radius * 2), anchor: Anchor.center);

  @override
  bool containsLocalPoint(Vector2 point) {
    final c = size / 2;
    return point.distanceTo(c) <= radius;
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(c, radius, Paint()..color = bgColor);

    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(c.dx - textPainter.width / 2, c.dy - textPainter.height / 2));

    super.render(canvas);
  }

  @override
  void onTapUp(TapUpEvent event) {
    onPressed();
    super.onTapUp(event);
  }
}

/// Interface for games that use chips
/// Both BlackjackGame and MultiplayerBlackjackGame should implement this
abstract class ChipGameInterface {
  void stageBet({required Vector2 from, required double amount, required Color color});
  void removeStagedDenom(double value);
}

/// Palette chip with +/- buttons. `size` guarantees safe spacing to neighbors.
/// FIXED: Now uses FlameGame as base type instead of specific BlackjackGame
class PaletteChip extends PositionComponent with HasGameReference<FlameGame> {
  final double value;
  final Color chipColor;
  final double radius;
  final ButtonsLayout layout;
  final double spacing;
  final double? minGapAfterButtons;

  ChipButton? _plus;
  ChipButton? _minus;
  TextComponent? _label;

  static const double _btnR = 13.0;

  PaletteChip({
    required this.value,
    required this.chipColor,
    required Vector2 position,
    this.radius = 28.0,
    this.layout = ButtonsLayout.diagonalTangent,
    this.spacing = 5.0,
    this.minGapAfterButtons,
  }) : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final double verticalExtent = (layout == ButtonsLayout.stackVertical) 
        ? (radius + _btnR + spacing)
        : max(radius, _btnR);

    double leftExtent = radius;
    double rightExtent = radius;

    if (layout == ButtonsLayout.diagonalTangent) {
      const theta = pi / 4;
      final dx = (radius + _btnR + spacing) * cos(theta);
      final dy = (radius + _btnR + spacing) * sin(theta);
      rightExtent = max(rightExtent, dx + _btnR);
      leftExtent = max(leftExtent, dy + _btnR);
    } else if (layout == ButtonsLayout.stackRight) {
      rightExtent = radius + spacing + (2 * _btnR);
    }

    final double desiredGap = minGapAfterButtons ?? (2 * _btnR);
    final double inherentGap = rightExtent - leftExtent;
    final double extraPaddingX = max(0.0, desiredGap - inherentGap);

    final double halfW = max(leftExtent, rightExtent) + extraPaddingX / 2;
    final double halfH = max(radius, verticalExtent);

    size = Vector2(halfW * 2, halfH * 2);

    _label = TextComponent(
      text: '£${value.toInt()}',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 2,
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
    add(_label!);

    _buildButtons();
  }

  void _buildButtons() {
    _plus?.removeFromParent();
    _minus?.removeFromParent();

    final Vector2 chipCenter = size / 2;

    late final Vector2 plusPos;
    late final Vector2 minusPos;

    switch (layout) {
      case ButtonsLayout.diagonalTangent:
        const double theta = pi / 4;
        final double dist = radius + _btnR + spacing;
        plusPos = chipCenter + Vector2(dist * cos(theta), -dist * sin(theta));
        minusPos = chipCenter + Vector2(dist * cos(theta),  dist * sin(theta));
        break;

      case ButtonsLayout.stackRight:
        final double x = chipCenter.x + radius + _btnR + spacing;
        final double dy = _btnR + spacing;
        plusPos  = Vector2(x, chipCenter.y - dy);
        minusPos = Vector2(x, chipCenter.y + dy);
        break;

      case ButtonsLayout.stackVertical:
        final double dy = _btnR + spacing;
        plusPos  = Vector2(chipCenter.x, chipCenter.y - dy);
        minusPos = Vector2(chipCenter.x, chipCenter.y + dy);
        break;
    }

    _plus = ChipButton(
      symbol: '+',
      onPressed: () {
        // Cast to the interface - this works for both game types
        final chipGame = game as ChipGameInterface;
        chipGame.stageBet(
          from: plusPos,
          amount: value,
          color: chipColor,
        );
      },
      position: plusPos,
      radius: _btnR,
      bgColor: Colors.transparent,
    );

    _minus = ChipButton(
      symbol: '-',
      onPressed: () {
        final chipGame = game as ChipGameInterface;
        chipGame.removeStagedDenom(value);
      },
      position: minusPos,
      radius: _btnR,
      bgColor: Colors.red,
    );

    add(_plus!);
    add(_minus!);
  }

  @override
  void render(Canvas canvas) {
    final center = size / 2;

    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center.toOffset(), radius, outerPaint);

    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          chipColor.withValues(alpha: 0.85),
          chipColor,
          chipColor.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center.toOffset(), radius: radius),
      );
    canvas.drawCircle(center.toOffset(), radius, innerPaint);

    super.render(canvas);
  }
}

/// BetChip representing a placed bet
/// FIXED: Now uses FlameGame as base type
class BetChip extends PositionComponent with HasGameReference<FlameGame> {
  final double value;
  final Color color;

  BetChip({
    required this.value,
    required this.color,
    required Vector2 position,
  }) : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Get radius from game if it's a ChipGameInterface
    double radius = 28.0; // default
    if (game is ChipGameInterface) {
      // You can add a method to get chip radius if needed
      radius = 28.0;
    }
    
    size = Vector2.all(radius * 2);
  }

  @override
  void render(Canvas canvas) {
    final radius = size.x / 2;
    final center = size / 2;

    // Outer ring
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center.toOffset(), radius, outerPaint);

    // Inner fill with gradient
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.85),
          color,
          color.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center.toOffset(), radius: radius),
      );
    canvas.drawCircle(center.toOffset(), radius, innerPaint);

    // Value text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '£${value.toInt()}',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 2,
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.x - textPainter.width / 2,
        center.y - textPainter.height / 2,
      ),
    );

    super.render(canvas);
  }
}