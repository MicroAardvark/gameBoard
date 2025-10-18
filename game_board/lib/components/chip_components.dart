// lib/components/chip_components.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../games/blackjack_game.dart';

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

/// Palette chip with +/- buttons. `size` guarantees safe spacing to neighbors.
class PaletteChip extends PositionComponent with HasGameReference<BlackjackGame> {
  final double value;
  final Color chipColor;
  final double radius;
  final ButtonsLayout layout;
  final double spacing;
  final double? minGapAfterButtons;

  ChipButton? _plus;
  ChipButton? _minus;
  late TextComponent _label;
  late double _btnR;

  PaletteChip({
    required Vector2 position,
    required this.radius,
    required this.value,
    required this.chipColor,
    this.layout = ButtonsLayout.diagonalTangent,
    this.spacing = 6.0,
    this.minGapAfterButtons,
  }) : super(position: position, anchor: Anchor.center);

  double get recommendedStride => size.x;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _btnR = max(14.0, min(22.0, radius * 0.38));

    final double leftExtent = radius;
    final double rightExtent = switch (layout) {
      ButtonsLayout.diagonalTangent =>
        (radius + _btnR + spacing) * cos(pi / 4) + _btnR,
      ButtonsLayout.stackRight =>
        radius + spacing + 2 * _btnR,
      ButtonsLayout.stackVertical =>
        radius,
    };

    final double verticalExtent = switch (layout) {
      ButtonsLayout.diagonalTangent =>
        (radius + _btnR + spacing) * sin(pi / 4) + _btnR,
      ButtonsLayout.stackRight =>
        max(radius, _btnR + spacing + _btnR),
      ButtonsLayout.stackVertical =>
        radius + spacing + _btnR,
    };

    final double desiredGap = (minGapAfterButtons ?? (2 * _btnR));
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
    add(_label);

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
        final color = chipColor;
        game.stageBet(
          from: plusPos,
          amount: value,
          color: color,
        );
      },
      position: plusPos,
      radius: _btnR,
      bgColor: Colors.transparent,
    );

    _minus = ChipButton(
      symbol: '-',
      onPressed: () => game.removeStagedDenom(value),
      position: minusPos,
      radius: _btnR,
      bgColor: Colors.red,
    );

    add(_plus!);
    add(_minus!);
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);

    canvas.drawCircle(
      c,
      radius,
      Paint()..color = chipColor,
    );

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.35),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '£${value.toInt()}',
        style: TextStyle(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          color: Colors.black,
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
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));

    super.render(canvas);
  }
}

/// BetChip represents a chip that has been placed in the betting area
class BetChip extends PositionComponent {
  final double value;
  final Color chipColor;
  final double radius;

  BetChip({
    required Vector2 position,
    required this.value,
    required this.chipColor,
    required this.radius,
  }) : super(position: position, size: Vector2.all(radius * 2), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);

    // Chip body
    canvas.drawCircle(c, radius, Paint()..color = chipColor);

    // Border
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.35),
    );

    // Value label
    final tp = TextPainter(
      text: TextSpan(
        text: '£${value.toInt()}',
        style: TextStyle(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}