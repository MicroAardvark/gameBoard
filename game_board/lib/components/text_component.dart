import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A lightweight Flame [TextComponent] for displaying read-only HUD labels
/// such as balance, round number, or turn status.
///
/// Wraps [TextPaint] configuration so call sites don't need to repeat the
/// style setup each time an info label is created.
class InfoTextComponent extends TextComponent {
  InfoTextComponent({
    required String text,
    required Vector2 position,
    required double fontSize,
  }) : super(
          text: text,
          position: position,
          anchor: Anchor.topLeft,
          textRenderer: TextPaint(
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textPrimary,
              fontSize: fontSize,
            ),
          ),
        );

  /// Replaces the displayed text. Flame re-renders every frame so the
  /// change will be visible on the next draw without any manual repaint call.
  void updateText(String newText) {
    text = newText;
  }
}