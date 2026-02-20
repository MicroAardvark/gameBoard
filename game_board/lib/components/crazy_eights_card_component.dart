// lib/components/crazy_eights_card_component.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/crazy_eights_card.dart';
import '../theme/app_theme.dart';

/// Renders a single Crazy Eights card as a tappable Flame [PositionComponent].
///
/// Supports face-up and face-down states, a selected state with visual feedback,
/// and an optional [displaySuit] override for King/Ace cards that have already
/// had their suit chosen by the player.
class CrazyEightsCardComponent extends PositionComponent with TapCallbacks {
  final CrazyEightsCard card;
  bool isHidden;
  bool isSelected;
  final Function(CrazyEightsCardComponent)? onTap;

  /// When set on a King or Ace, overrides the centre symbol to show the
  /// chosen suit rather than the default all-four-suits grid.
  final CardSuit? displaySuit;

  // Cached values used to restore the card after deselection.
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
    this.displaySuit,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void onTapDown(TapDownEvent event) {
    if (onTap != null && !isHidden) {
      onTap!(this);
    }
  }

  /// Toggles selected state and updates visuals accordingly.
  void toggleSelected() {
    isSelected = !isSelected;
    _updateSelectionVisuals();
  }

  /// Sets selected state explicitly, ignoring the call if state is unchanged.
  void setSelected(bool selected) {
    if (isSelected != selected) {
      isSelected = selected;
      _updateSelectionVisuals();
    }
  }

  /// Scales the card up and raises it when selected; restores original
  /// transform values when deselected.
  ///
  /// Direct property mutation is used rather than Flame effects so that the
  /// change is immediate and reversible without managing effect lifecycles.
  void _updateSelectionVisuals() {
    if (isSelected) {
      _originalPosition = position.clone();
      _originalSize = size.clone();
      _originalPriority = priority;

      size = _originalSize! * 1.3;
      position = Vector2(_originalPosition!.x, _originalPosition!.y - 40);
      priority = 1000; // Raise above all other cards
    } else {
      if (_originalPosition != null) position = _originalPosition!.clone();
      if (_originalSize != null) size = _originalSize!.clone();
      if (_originalPriority != null) priority = _originalPriority!;
    }
  }

  @override
  void render(Canvas canvas) {
    // Anchor.center places (0,0) at the card centre, so Rect.fromCenter
    // with Offset.zero produces a rect correctly centred on the component.
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

    if (isSelected) {
      _renderSelectionIndicator(canvas, rrect);
    }
  }

  /// Draws the card back: a solid navy fill with a dot-grid pattern and border.
  void _renderCardBack(Canvas canvas, RRect rrect) {
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0B3A79));

    // Dot grid pattern drawn relative to the centre origin.
    final patternPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const spacing_factor = 0.15;
    final spacing = size.x * spacing_factor;

    for (var i = -2; i <= 2; i++) {
      for (var j = -3; j <= 3; j++) {
        canvas.drawCircle(
          Offset(i * spacing, j * spacing),
          size.x * 0.05,
          patternPaint,
        );
      }
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.textPrimary.withValues(alpha: 0.3),
    );
  }

  /// Draws the card face: white background, corner labels, centre symbol, and border.
  void _renderCardFace(Canvas canvas, RRect rrect) {
    canvas.drawRRect(rrect, Paint()..color = AppColors.textPrimary);
    _drawCorners(canvas);
    _drawCenterSymbol(canvas);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primaryNavyDark.withValues(alpha: 0.3),
    );
  }

  /// Draws the rank and suit in the top-left corner, then again rotated 180°
  /// in the bottom-right corner — standard playing card layout.
  void _drawCorners(Canvas canvas) {
    final textStyle = TextStyle(
      fontFamily: 'Inter',
      color: card.displayColor,
      fontSize: size.y * 0.10,
      fontWeight: FontWeight.bold,
    );

    final text = '${card.rankText}\n${card.suitSymbol}';

    final topLeftPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    topLeftPainter.paint(
      canvas,
      Offset(-(size.x / 2) + (size.x * 0.1), -(size.y / 2) + (size.y * 0.06)),
    );

    // Rotating by π around the component origin mirrors the top-left label
    // into the bottom-right corner without needing separate position arithmetic.
    canvas.save();
    canvas.rotate(3.14159);
    final bottomRightPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    bottomRightPainter.paint(
      canvas,
      Offset(-(size.x / 2) + (size.x * 0.1), -(size.y / 2) + (size.y * 0.06)),
    );
    canvas.restore();
  }

  /// Routes centre rendering to the appropriate helper based on card type.
  ///
  /// Kings and Aces display all four suits to signal their suit-changing
  /// ability. If [displaySuit] is set, a transformed view is shown instead.
  void _drawCenterSymbol(Canvas canvas) {
    if (card.canChangeSuit && displaySuit != null) {
      _drawTransformedSuitCard(canvas);
      return;
    }

    if (card.isKing) { _drawKingWithAllSuits(canvas); return; }
    if (card.isAce)  { _drawAceWithAllSuits(canvas);  return; }

    final symbolStyle = TextStyle(
      fontFamily: 'Inter',
      color: card.displayColor,
      fontSize: size.y * 0.25,
      fontWeight: FontWeight.bold,
    );

    // Jack and Queen have distinct centre text; all other cards show rank + suit.
    final String centerText;
    if (card.isJack) {
      centerText = 'J\n${card.suitSymbol}';
    } else if (card.isQueen) {
      centerText = 'Q\n+2';
    } else {
      centerText = '${card.rankText}\n${card.suitSymbol}';
    }

    final centerPainter = TextPainter(
      text: TextSpan(text: centerText, style: symbolStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    centerPainter.paint(
      canvas,
      Offset(-centerPainter.width / 2, -centerPainter.height / 2),
    );

    if (card.isJack) _drawActionHint(canvas, 'Skip/Rev');
  }

  /// Draws a King or Ace that has had its suit chosen, showing the selected
  /// suit symbol prominently with a "Changed" label beneath.
  void _drawTransformedSuitCard(Canvas canvas) {
    final chosenSuit = displaySuit!;

    // Suit colour and symbol are derived from the chosen suit rather than
    // the card's original suit so the visual matches the active game state.
    final Color suitColor;
    final String suitSymbol;
    switch (chosenSuit) {
      case CardSuit.hearts:
        suitColor = const Color(0xFFE53935); suitSymbol = '♥';
        break;
      case CardSuit.diamonds:
        suitColor = AppColors.accentElectricBlue; suitSymbol = '♦';
        break;
      case CardSuit.clubs:
        suitColor = AppColors.primaryNavyDark; suitSymbol = '♣';
        break;
      case CardSuit.spades:
        suitColor = AppColors.secondaryAmber; suitSymbol = '♠';
        break;
    }

    // Rank letter above the large suit symbol.
    final rankPainter = TextPainter(
      text: TextSpan(
        text: card.rankText,
        style: TextStyle(
          fontFamily: 'Inter',
          color: suitColor,
          fontSize: size.y * 0.22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rankPainter.paint(canvas, Offset(-rankPainter.width / 2, -(size.y * 0.35)));

    final suitPainter = TextPainter(
      text: TextSpan(
        text: suitSymbol,
        style: TextStyle(
          fontFamily: 'Inter',
          color: suitColor,
          fontSize: size.y * 0.35,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    suitPainter.paint(
      canvas,
      Offset(-suitPainter.width / 2, -suitPainter.height / 2 + size.y * 0.05),
    );

    _drawActionHint(canvas, 'Changed');
  }

  /// Shared helper that draws a 2×2 grid of all four suit symbols below a
  /// rank letter, used by both [_drawKingWithAllSuits] and [_drawAceWithAllSuits].
  void _drawAllSuitsGrid(Canvas canvas, String rankLetter) {
    final rankPainter = TextPainter(
      text: TextSpan(
        text: rankLetter,
        style: TextStyle(
          fontFamily: 'Inter',
          color: card.displayColor,
          fontSize: size.y * 0.2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rankPainter.paint(canvas, Offset(-rankPainter.width / 2, -(size.y * 0.32)));

    final suitSize = size.y * 0.15;
    final spacing  = size.x * 0.15;

    // Suits and their distinct colours follow standard card convention,
    // with diamonds and spades using app accent colours for visual variety.
    final suits = [
      {'symbol': '♥', 'color': const Color(0xFFE53935)},
      {'symbol': '♦', 'color': AppColors.accentElectricBlue},
      {'symbol': '♣', 'color': AppColors.primaryNavyDark},
      {'symbol': '♠', 'color': AppColors.secondaryAmber},
    ];

    final positions = [
      Offset(-spacing / 2, -spacing / 2 + size.y * 0.05),
      Offset( spacing / 2, -spacing / 2 + size.y * 0.05),
      Offset(-spacing / 2,  spacing / 2 + size.y * 0.05),
      Offset( spacing / 2,  spacing / 2 + size.y * 0.05),
    ];

    for (var i = 0; i < 4; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: suits[i]['symbol'] as String,
          style: TextStyle(
            fontFamily: 'Inter',
            color: suits[i]['color'] as Color,
            fontSize: suitSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        Offset(positions[i].dx - painter.width / 2, positions[i].dy - painter.height / 2),
      );
    }
  }

  /// Renders a King card with all four suits and a "Change" action hint.
  void _drawKingWithAllSuits(Canvas canvas) {
    _drawAllSuitsGrid(canvas, 'K');
    _drawActionHint(canvas, 'Change');
  }

  /// Renders an Ace card with all four suits and a "Change+4" action hint,
  /// indicating the Ace also forces the next player to draw four cards.
  void _drawAceWithAllSuits(Canvas canvas) {
    _drawAllSuitsGrid(canvas, 'A');
    _drawActionHint(canvas, 'Change+4');
  }

  /// Draws a small italic label near the card's bottom edge to indicate
  /// a special game action associated with the card.
  void _drawActionHint(Canvas canvas, String hint) {
    final painter = TextPainter(
      text: TextSpan(
        text: hint,
        style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.primaryNavyDark.withValues(alpha: 0.4),
          fontSize: size.y * 0.055,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(-painter.width / 2, (size.y / 2) - (size.y * 0.18)),
    );
  }

  /// Draws a gold rounded border and outer glow to indicate the card is selected.
  void _renderSelectionIndicator(Canvas canvas, RRect rrect) {
    // Outer glow drawn first so the solid border renders on top of it.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = Colors.amber.withValues(alpha: 0.3),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.amber,
    );
  }
}