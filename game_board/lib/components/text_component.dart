import 'package:flame/components.dart';
import 'package:flutter/material.dart';

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
            style: TextStyle(color: Colors.white, fontSize: fontSize),
          ),
        );

  void updateText(String t) {
    text = t;
  }
}
