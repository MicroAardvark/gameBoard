// lib/components/crazy_eights_card_component.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/crazy_eights_card.dart';
import '../theme/app_theme.dart';

class CrazyEightsCardComponent extends PositionComponent with TapCallbacks {
  final CrazyEightsCard card;
  bool isHidden;
  bool isSelected;
  final Function(CrazyEightsCardComponent)? onTap;
  
  // Store original position and size for animation
  Vector2? _originalPosition;
  Vector2? _originalSize;
  int? _originalPriority;

  CrazyEightsCardComponent({
    required Vector2 position,
    required Vector2 size,
    required this.card,
    this.isHidden = false,
    this.isSelected = false,
    this.onTap,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void onTapDown(TapDownEvent event) {
    if (onTap != null && !isHidden) {
      onTap!(this);
    }
  }

  void toggleSelected() {
    isSelected = !isSelected;
    _updateSelectionVisuals();
  }

  void setSelected(bool selected) {
    if (isSelected != selected) {
      isSelected = selected;
      _updateSelectionVisuals();
    }
  }

  void _updateSelectionVisuals() {
    if (isSelected) {
      // Store original values
      _originalPosition = position.clone();
      _originalSize = size.clone();
      _originalPriority = priority;
      
      // Scale up and move forward
      size = _originalSize! * 1.3;
      position = Vector2(_originalPosition!.x, _originalPosition!.y - 40);
      priority = 1000; // Move to front
    } else {
      // Restore original values
      if (_originalPosition != null) {
        position = _originalPosition!.clone();
      }
      if (_originalSize != null) {
        size = _originalSize!.clone();
      }
      if (_originalPriority != null) {
        priority = _originalPriority!;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw relative to (0,0) which is the center due to Anchor.center
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    if (isHidden) {
      _renderCardBack(canvas, rrect);
    } else {
      _renderCardFace(canvas, rrect);
    }

    // Draw selection indicator if selected
    if (isSelected) {
      _renderSelectionIndicator(canvas, rrect);
    }
  }

  void _renderCardBack(Canvas canvas, RRect rrect) {
    // Playing card back - blue pattern
    final backPaint = Paint()..color = const Color(0xFF0B3A79);
    canvas.drawRRect(rrect, backPaint);

    // Add decorative pattern
    final patternPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw diamond pattern
    final centerX = 0.0; // Relative to center
    final centerY = 0.0;
    final spacing = size.x * 0.15;
    
    for (var i = -2; i <= 2; i++) {
      for (var j = -3; j <= 3; j++) {
        final x = centerX + (i * spacing);
        final y = centerY + (j * spacing);
        canvas.drawCircle(
          Offset(x, y),
          size.x * 0.05,
          patternPaint,
        );
      }
    }

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.textPrimary.withValues(alpha: 0.3);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _renderCardFace(Canvas canvas, RRect rrect) {
    // White card background
    final backgroundPaint = Paint()..color = AppColors.textPrimary;
    canvas.drawRRect(rrect, backgroundPaint);

    // Draw card content
    _drawCorners(canvas);
    _drawCenterSymbol(canvas);

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.3);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawCorners(Canvas canvas) {
    final textStyle = TextStyle(fontFamily: 'Inter', 
      color: card.displayColor,
      fontSize: size.y * 0.10,  // REDUCED from 0.12 and made proportional
      fontWeight: FontWeight.bold,
    );

    final text = '${card.rankText}\n${card.suitSymbol}';
    
    // Top-left corner
    final topLeftPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    topLeftPainter.paint(
      canvas,
      Offset(
        -(size.x / 2) + (size.x * 0.1),  // ADJUSTED padding
        -(size.y / 2) + (size.y * 0.06),
      ),
    );

    // Bottom-right corner (rotated 180°)
    canvas.save();
    canvas.translate(0, 0);
    canvas.rotate(3.14159); // 180 degrees in radians
    
    final bottomRightPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    bottomRightPainter.paint(
      canvas,
      Offset(
        -(size.x / 2) + (size.x * 0.1),
        -(size.y / 2) + (size.y * 0.06),
      ),
    );
    
    canvas.restore();
  }

  void _drawCenterSymbol(Canvas canvas) {
    // Draw large suit symbol(s) in center
    final symbolStyle = TextStyle(fontFamily: 'Inter', 
      color: card.displayColor,
      fontSize: size.y * 0.25,  // REDUCED from 0.35
      fontWeight: FontWeight.bold,
    );

    String centerText;
    
    if (card.isAction) {
      // Show special text for face cards
      if (card.isJack) {
        centerText = 'J\n${card.suitSymbol}';
      } else if (card.isQueen) {
        centerText = 'Q\n+2';  // SIMPLIFIED - removed suit to prevent overflow
      } else if (card.isKing) {
        centerText = 'K\n${card.suitSymbol}';
      } else if (card.isAce) {
        centerText = 'A\n+4';  // SIMPLIFIED - removed suit to prevent overflow
      } else {
        centerText = '${card.rankText}\n${card.suitSymbol}';
      }
    } else {
      // Number cards - show rank and suit
      centerText = '${card.rankText}\n${card.suitSymbol}';
    }

    final centerPainter = TextPainter(
      text: TextSpan(text: centerText, style: symbolStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    centerPainter.paint(
      canvas,
      Offset(
        -centerPainter.width / 2,
        -centerPainter.height / 2,
      ),
    );

    // Add special indicator for action cards - SMALLER
    if (card.isJack) {
      _drawActionHint(canvas, 'Skip/Rev');
    } else if (card.isKing || card.isAce) {
      _drawActionHint(canvas, 'Change');
    }
  }

  void _drawActionHint(Canvas canvas, String hint) {
    final hintStyle = TextStyle(fontFamily: 'Inter', 
      color: AppColors.primaryNavyDark.withValues(alpha: 0.4),
      fontSize: size.y * 0.055,  // ADJUSTED from 0.06
      fontStyle: FontStyle.italic,
    );

    final hintPainter = TextPainter(
      text: TextSpan(text: hint, style: hintStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    hintPainter.paint(
      canvas,
      Offset(
        -hintPainter.width / 2,
        (size.y / 2) - (size.y * 0.18),  // ADJUSTED position
      ),
    );
  }

  void _renderSelectionIndicator(Canvas canvas, RRect rrect) {
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.amber;
    
    canvas.drawRRect(rrect, highlightPaint);
    
    // Add glow effect
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.amber.withValues(alpha: 0.3);
    
    canvas.drawRRect(rrect, glowPaint);
  }
}