// ====================================
// lib/components/checkers_piece_component.dart
// Checkers piece component that renders actual colours (red/black)
// Used by both single-player and multiplayer checkers games
// ====================================

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import '../games/checkers_game.dart';

/// Renders a single checkers piece as a circular Flame [PositionComponent].
///
/// Handles its own visual state (selected, king) and exposes [animateTo] for
/// smooth movement. Piece type integers are shared between single-player and
/// multiplayer modes — see [CheckersConstants] for the full mapping.
class CheckersPiece extends PositionComponent {
  final int pieceType;
  final Position boardPosition;
  bool isSelected = false;

  CheckersPiece({
    required this.pieceType,
    required this.boardPosition,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2.all(CheckersConstants.pieceSize),
          anchor: Anchor.center,
        );

  /// Restricts hit-testing to the circular piece area rather than the full
  /// bounding rectangle. Without this override, the rectangular hitbox would
  /// intercept taps on the corners of the square beneath the piece, preventing
  /// the board from receiving those tap events.
  @override
  bool containsLocalPoint(Vector2 point) {
    final pieceRadius = size.x / 2;
    return point.distanceTo(size / 2) <= pieceRadius;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final isKing = pieceType == CheckersConstants.redKing ||
        pieceType == CheckersConstants.blackKing;

    final Color pieceColour;
    if (pieceType == CheckersConstants.redPiece ||
        pieceType == CheckersConstants.redKing) {
      pieceColour = CheckersConstants.redPieceColour;
    } else if (pieceType == CheckersConstants.blackPiece ||
        pieceType == CheckersConstants.blackKing) {
      pieceColour = CheckersConstants.blackPieceColour;
    } else {
      pieceColour = Colors.grey; // Fallback — should never be reached in practice
    }

    final centre = Offset(size.x / 2, size.y / 2);
    // Inner radius is inset by 4px to leave room for the selection ring.
    final innerRadius = size.x / 2 - 4;

    // Gold selection ring drawn outside the piece so it doesn't obscure the fill.
    if (isSelected) {
      canvas.drawCircle(
        centre,
        size.x / 2,
        Paint()
          ..color = CheckersConstants.selectedColour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );
    }

    // Main piece fill and outline.
    canvas.drawCircle(centre, innerRadius, Paint()..color = pieceColour);
    canvas.drawCircle(
      centre,
      innerRadius,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Off-centre white highlight to give the piece a simple 3-D appearance.
    canvas.drawCircle(
      Offset(size.x / 2 - 8, size.y / 2 - 8),
      size.x / 4,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    if (isKing) {
      _drawCrown(canvas);
    }
  }

  /// Draws a gold crown centred on the piece to denote king status.
  ///
  /// The crown is constructed as a [Path] rather than an image so it scales
  /// cleanly with [CheckersConstants.crownSize] without requiring assets.
  void _drawCrown(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final w = CheckersConstants.crownSize;
    final h = w * 0.8;

    // Crown outline: base bar with three upward points.
    final path = Path()
      ..moveTo(cx - w / 2, cy + h / 4)  // Bottom-left
      ..lineTo(cx - w / 3, cy - h / 4)  // Left point
      ..lineTo(cx, cy + h / 4)           // Return to base
      ..lineTo(cx, cy - h / 2)           // Centre point
      ..lineTo(cx, cy + h / 4)           // Return to base
      ..lineTo(cx + w / 3, cy - h / 4)  // Right point
      ..lineTo(cx + w / 2, cy + h / 4)  // Bottom-right
      ..close();

    canvas.drawPath(path, Paint()..color = CheckersConstants.kingBorderColour);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Animates the piece to [newPosition] over 300 ms using a Flame [MoveEffect].
  void animateTo(Vector2 newPosition) {
    add(MoveEffect.to(newPosition, EffectController(duration: 0.3)));
  }
}

// ====================================
// CONSTANTS
// ====================================

/// Centralised configuration for the checkers game.
///
/// Piece type integers are intentionally shared between single-player and
/// multiplayer modes (e.g. [playerPiece] == [redPiece] == 1) so that game
/// logic and rendering code can use either naming convention without conversion.
class CheckersConstants {
  // Board dimensions
  static const int boardSize = 8;
  static const double squareSize = 48.0;
  static const double pieceSize = 36.0;
  static const double crownSize = 18.0;

  // Board colours
  static const Color darkSquare = Color(0xFF000000);
  static const Color lightSquare = Color(0xFFF5F5DC);
  static const Color highlightColour = Color(0xFFFFA500);
  static const Color selectedColour = Color(0xFFFFD700);
  static const Color validMoveColour = Color(0xFF4169E1);
  static const Color kingBorderColour = Color(0xFFFFD700);

  // Piece colours — single-player and multiplayer share the same values.
  static const Color playerPieceColour = Color(0xFFDC143C);
  static const Color aiPieceColour = Color(0xFF1C1C1C);
  static const Color redPieceColour = Color(0xFFDC143C);
  static const Color blackPieceColour = Color(0xFF1C1C1C);

  // Timing
  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  static const Duration aiThinkingDelay = Duration(milliseconds: 800);

  // Piece type integers — values are identical across both modes by design.
  static const int emptySquare = 0;
  static const int playerPiece = 1; // == redPiece
  static const int playerKing = 2;  // == redKing
  static const int aiPiece = 3;     // == blackPiece
  static const int aiKing = 4;      // == blackKing

  static const int redPiece = 1;
  static const int redKing = 2;
  static const int blackPiece = 3;
  static const int blackKing = 4;
}