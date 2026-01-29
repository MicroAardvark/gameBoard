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
  
  // NEW: Optional display suit override for Kings/Aces
  final CardSuit? displaySuit;
  
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
    this.displaySuit, // NEW parameter
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
      fontSize: size.y * 0.10,
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
        -(size.x / 2) + (size.x * 0.1),
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
    // NEW: If this is a King/Ace with a chosen suit, show the transformed version
    if (card.canChangeSuit && displaySuit != null) {
      _drawTransformedSuitCard(canvas);
      return;
    }

    // Draw large suit symbol(s) in center
    final symbolStyle = TextStyle(fontFamily: 'Inter', 
      color: card.displayColor,
      fontSize: size.y * 0.25,
      fontWeight: FontWeight.bold,
    );

    String centerText;
    
    if (card.isAction) {
      // Show special text for face cards
      if (card.isJack) {
        centerText = 'J\n${card.suitSymbol}';
      } else if (card.isQueen) {
        centerText = 'Q\n+2';
      } else if (card.isKing) {
        // Special handling for King - show all four suits
        _drawKingWithAllSuits(canvas);
        return;
      } else if (card.isAce) {
        // NEW: Special handling for Ace - show all four suits
        _drawAceWithAllSuits(canvas);
        return;
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

    // Add special indicator for action cards
    if (card.isJack) {
      _drawActionHint(canvas, 'Skip/Rev');
    } else if (card.isKing || card.isAce) {
      _drawActionHint(canvas, 'Change');
    }
  }

  // NEW METHOD: Draw transformed King/Ace with chosen suit
  void _drawTransformedSuitCard(Canvas canvas) {
    final chosenSuit = displaySuit!;
    
    // Get the color for the chosen suit
    final Color suitColor;
    switch (chosenSuit) {
      case CardSuit.hearts:
        suitColor = const Color(0xFFE53935);
        break;
      case CardSuit.diamonds:
        suitColor = AppColors.accentElectricBlue;
        break;
      case CardSuit.clubs:
        suitColor = AppColors.primaryNavyDark;
        break;
      case CardSuit.spades:
        suitColor = AppColors.secondaryAmber;
        break;
    }
    
    // Get the symbol for the chosen suit
    final String suitSymbol;
    switch (chosenSuit) {
      case CardSuit.hearts:
        suitSymbol = '♥';
        break;
      case CardSuit.diamonds:
        suitSymbol = '♦';
        break;
      case CardSuit.clubs:
        suitSymbol = '♣';
        break;
      case CardSuit.spades:
        suitSymbol = '♠';
        break;
    }
    
    // Draw the rank letter at the top
    final rankStyle = TextStyle(
      fontFamily: 'Inter',
      color: suitColor,
      fontSize: size.y * 0.22,
      fontWeight: FontWeight.bold,
    );
    
    final rankPainter = TextPainter(
      text: TextSpan(text: card.rankText, style: rankStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    rankPainter.paint(
      canvas,
      Offset(
        -rankPainter.width / 2,
        -(size.y * 0.35),
      ),
    );
    
    // Draw the large chosen suit symbol in the center
    final suitStyle = TextStyle(
      fontFamily: 'Inter',
      color: suitColor,
      fontSize: size.y * 0.35,
      fontWeight: FontWeight.bold,
    );
    
    final suitPainter = TextPainter(
      text: TextSpan(text: suitSymbol, style: suitStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    suitPainter.paint(
      canvas,
      Offset(
        -suitPainter.width / 2,
        -suitPainter.height / 2 + size.y * 0.05,
      ),
    );
    
    // Add "Changed" hint at bottom
    final hintStyle = TextStyle(
      fontFamily: 'Inter',
      color: AppColors.primaryNavyDark.withValues(alpha: 0.4),
      fontSize: size.y * 0.055,
      fontStyle: FontStyle.italic,
    );

    final hintPainter = TextPainter(
      text: TextSpan(text: 'Changed', style: hintStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    hintPainter.paint(
      canvas,
      Offset(
        -hintPainter.width / 2,
        (size.y / 2) - (size.y * 0.18),
      ),
    );
  }

  // Draw King with all four suit symbols in 2x2 grid
  void _drawKingWithAllSuits(Canvas canvas) {
    // Draw "K" at the top
    final kingStyle = TextStyle(
      fontFamily: 'Inter',
      color: card.displayColor,
      fontSize: size.y * 0.2,
      fontWeight: FontWeight.bold,
    );
    
    final kingPainter = TextPainter(
      text: TextSpan(text: 'K', style: kingStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    kingPainter.paint(
      canvas,
      Offset(
        -kingPainter.width / 2,
        -(size.y * 0.32),
      ),
    );
    
    // Draw all four suit symbols in a 2x2 grid
    final suitSize = size.y * 0.15;
    final spacing = size.x * 0.15;
    
    final suits = [
      {'symbol': '♥', 'color': const Color(0xFFE53935)},
      {'symbol': '♦', 'color': AppColors.accentElectricBlue},
      {'symbol': '♣', 'color': AppColors.primaryNavyDark},
      {'symbol': '♠', 'color': AppColors.secondaryAmber},
    ];
    
    // Positions for 2x2 grid (centered)
    final positions = [
      Offset(-spacing / 2, -spacing / 2 + size.y * 0.05), // Top-left (Hearts)
      Offset(spacing / 2, -spacing / 2 + size.y * 0.05),  // Top-right (Diamonds)
      Offset(-spacing / 2, spacing / 2 + size.y * 0.05),  // Bottom-left (Clubs)
      Offset(spacing / 2, spacing / 2 + size.y * 0.05),   // Bottom-right (Spades)
    ];
    
    for (var i = 0; i < 4; i++) {
      final suitStyle = TextStyle(
        fontFamily: 'Inter',
        color: suits[i]['color'] as Color,
        fontSize: suitSize,
        fontWeight: FontWeight.bold,
      );
      
      final suitPainter = TextPainter(
        text: TextSpan(text: suits[i]['symbol'] as String, style: suitStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      
      suitPainter.paint(
        canvas,
        Offset(
          positions[i].dx - suitPainter.width / 2,
          positions[i].dy - suitPainter.height / 2,
        ),
      );
    }
    
    // Add "Change" hint at bottom
    _drawActionHint(canvas, 'Change');
  }

  // NEW: Draw Ace with all four suit symbols in 2x2 grid
  void _drawAceWithAllSuits(Canvas canvas) {
    // Draw "A" at the top
    final aceStyle = TextStyle(
      fontFamily: 'Inter',
      color: card.displayColor,
      fontSize: size.y * 0.2,
      fontWeight: FontWeight.bold,
    );
    
    final acePainter = TextPainter(
      text: TextSpan(text: 'A', style: aceStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    acePainter.paint(
      canvas,
      Offset(
        -acePainter.width / 2,
        -(size.y * 0.32),
      ),
    );
    
    // Draw all four suit symbols in a 2x2 grid
    final suitSize = size.y * 0.15;
    final spacing = size.x * 0.15;
    
    final suits = [
      {'symbol': '♥', 'color': const Color(0xFFE53935)},
      {'symbol': '♦', 'color': AppColors.accentElectricBlue},
      {'symbol': '♣', 'color': AppColors.primaryNavyDark},
      {'symbol': '♠', 'color': AppColors.secondaryAmber},
    ];
    
    // Positions for 2x2 grid (centered)
    final positions = [
      Offset(-spacing / 2, -spacing / 2 + size.y * 0.05), // Top-left (Hearts)
      Offset(spacing / 2, -spacing / 2 + size.y * 0.05),  // Top-right (Diamonds)
      Offset(-spacing / 2, spacing / 2 + size.y * 0.05),  // Bottom-left (Clubs)
      Offset(spacing / 2, spacing / 2 + size.y * 0.05),   // Bottom-right (Spades)
    ];
    
    for (var i = 0; i < 4; i++) {
      final suitStyle = TextStyle(
        fontFamily: 'Inter',
        color: suits[i]['color'] as Color,
        fontSize: suitSize,
        fontWeight: FontWeight.bold,
      );
      
      final suitPainter = TextPainter(
        text: TextSpan(text: suits[i]['symbol'] as String, style: suitStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      
      suitPainter.paint(
        canvas,
        Offset(
          positions[i].dx - suitPainter.width / 2,
          positions[i].dy - suitPainter.height / 2,
        ),
      );
    }
    
    // Add "Change+4" hint at bottom to indicate it also draws cards
    _drawActionHint(canvas, 'Change+4');
  }

  void _drawActionHint(Canvas canvas, String hint) {
    final hintStyle = TextStyle(fontFamily: 'Inter', 
      color: AppColors.primaryNavyDark.withValues(alpha: 0.4),
      fontSize: size.y * 0.055,
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
        (size.y / 2) - (size.y * 0.18),
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