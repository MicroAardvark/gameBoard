// checkers_components.dart - Visual components and data models for Checkers
// UK English spelling throughout

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

// Board configuration constants
const int BOARD_SIZE = 8;
const double TILE_SIZE = 45.0;
const double BOARD_PIXELS = BOARD_SIZE * TILE_SIZE; // 360.0

// Colours
const Color LIGHT_SQUARE = Color(0xFFEEEED2);
const Color DARK_SQUARE = Color(0xFF769656);
const Color SELECTED_COLOUR = Color(0xFFFFFF00);
const Color VALID_MOVE_COLOUR = Color(0x8800FF00);
const Color RED_PIECE = Color(0xFFE63946);
const Color BLACK_PIECE = Color(0xFF2A2A2A);

// ============================================================================
// DATA MODELS
// ============================================================================

/// Represents a position on the checkers board
class GridPosition {
  final int row;
  final int col;
  
  GridPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is GridPosition && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'GridPosition($row, $col)';
}

/// Represents a checkers piece with its state
class CheckersPiece {
  final String colour; // 'red' or 'black'
  bool isKing;
  int row;
  int col;

  CheckersPiece({
    required this.colour,
    required this.row,
    required this.col,
    this.isKing = false,
  });

  @override
  String toString() => 'CheckersPiece($colour, row: $row, col: $col, king: $isKing)';
}

/// Represents a possible move option
class MoveOption {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final bool isCapture;
  final int? capturedRow;
  final int? capturedCol;

  MoveOption({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    required this.isCapture,
    this.capturedRow,
    this.capturedCol,
  });

  @override
  String toString() => 'MoveOption(from: ($fromRow,$fromCol) to: ($toRow,$toCol) capture: $isCapture)';
}

/// Represents the result of a move attempt
class MoveResult {
  final bool success;
  final String? error;
  final bool promoted;
  final String? winner;

  MoveResult({
    required this.success,
    this.error,
    this.promoted = false,
    this.winner,
  });
}

// ============================================================================
// VISUAL COMPONENTS
// ============================================================================

/// Visual component for a square on the checkers board
class SquareComponent extends PositionComponent {
  final int row;
  final int col;
  final bool isLight;
  bool isSelected = false;
  bool isValidMove = false;

  SquareComponent(this.row, this.col)
      : isLight = (row + col) % 2 == 0,
        super(
          // Position at centre of square (relative to board's top-left)
          position: Vector2(
            col.toDouble() * TILE_SIZE + TILE_SIZE / 2,
            row.toDouble() * TILE_SIZE + TILE_SIZE / 2,
          ),
          size: Vector2.all(TILE_SIZE),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    Color colour = isLight ? LIGHT_SQUARE : DARK_SQUARE;
    if (isSelected) colour = SELECTED_COLOUR;
    if (isValidMove) colour = VALID_MOVE_COLOUR;

    // Draw square (centered on origin since anchor is center)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: TILE_SIZE,
        height: TILE_SIZE,
      ),
      Paint()..color = colour,
    );

    // Border
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: TILE_SIZE,
        height: TILE_SIZE,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Valid move indicator
    if (isValidMove) {
      canvas.drawCircle(
        Offset.zero, // Center since anchor is center
        TILE_SIZE / 8,
        Paint()..color = Colors.green.withValues(alpha: 0.6),
      );
    }
  }

  void updateHighlight(bool selected, bool validMove) {
    isSelected = selected;
    isValidMove = validMove;
  }
}

/// Visual component for a checkers piece
class PieceComponent extends PositionComponent {
  final CheckersPiece piece;

  PieceComponent(this.piece)
      : super(
          // Position at centre of square - SAME formula as SquareComponent
          position: Vector2(
            piece.col.toDouble() * TILE_SIZE + TILE_SIZE / 2,
            piece.row.toDouble() * TILE_SIZE + TILE_SIZE / 2,
          ),
          size: Vector2.all(TILE_SIZE * 0.8),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = TILE_SIZE * 0.35;
    const center = Offset(0, 0);

    // Shadow
    canvas.drawCircle(
      center + const Offset(2, 2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Main piece
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = piece.colour == 'red' ? RED_PIECE : BLACK_PIECE,
    );

    // Border ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = piece.colour == 'red' 
            ? const Color(0xFFA52A2A) 
            : Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // King crown indicator
    if (piece.isKing) {
      final crownPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;
      
      // Simple crown shape (triangle)
      final path = Path();
      path.moveTo(-radius * 0.3, 0);
      path.lineTo(0, -radius * 0.4);
      path.lineTo(radius * 0.3, 0);
      path.close();
      
      canvas.drawPath(path, crownPaint);
      
      // Crown border
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.amber[800]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }
}