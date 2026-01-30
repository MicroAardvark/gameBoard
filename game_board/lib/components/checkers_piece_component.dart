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
          position: Vector2(
            col.toDouble() * TILE_SIZE,
            row.toDouble() * TILE_SIZE,
          ),
          size: Vector2.all(TILE_SIZE),
          anchor: Anchor.topLeft,
        );

  @override
  void onMount() {
    super.onMount();
    if (row == 0 || row == 7) {
      // Only log first and last rows to reduce spam
      print('Square ($row,$col) ${isLight ? "LIGHT" : "DARK"} mounted at position: $position');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    Color colour = isLight ? LIGHT_SQUARE : DARK_SQUARE;
    if (isSelected) colour = SELECTED_COLOUR;
    if (isValidMove) colour = VALID_MOVE_COLOUR;

    canvas.drawRect(
      size.toRect(),
      Paint()..color = colour,
    );

    // Border
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // DEBUG: Draw coordinate text in corner of square
    final textStyle = TextStyle(
      color: isLight ? Colors.black54 : Colors.white54,
      fontSize: 8,
      fontWeight: FontWeight.normal,
    );
    
    final textSpan = TextSpan(
      text: '$row,$col',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(2, 2));

    // Valid move indicator
    if (isValidMove) {
      canvas.drawCircle(
        Offset(TILE_SIZE / 2, TILE_SIZE / 2),
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
          // Position at the CENTER of the piece's square
          position: Vector2(
            piece.col.toDouble() * TILE_SIZE + TILE_SIZE / 2,
            piece.row.toDouble() * TILE_SIZE + TILE_SIZE / 2,
          ),
          size: Vector2.all(TILE_SIZE * 0.8),
          anchor: Anchor.center,
        );

  @override
  void onMount() {
    super.onMount();
    print('Piece ${piece.colour} (${piece.row},${piece.col}) mounted at position: $position, absolutePosition: $absolutePosition');
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = TILE_SIZE * 0.35;
    const center = Offset(0, 0);

    // DEBUG: Draw crosshair at center to verify anchor point
    final crosshairPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(-10, 0),
      Offset(10, 0),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(0, -10),
      Offset(0, 10),
      crosshairPaint,
    );

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

    // DEBUG: Draw position text on piece with HIGH VISIBILITY
    final textStyle = TextStyle(
      color: piece.colour == 'red' ? Colors.white : Colors.yellow,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black,
          offset: Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );
    
    final textSpan = TextSpan(
      text: '${piece.row},${piece.col}',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    // King crown
    if (piece.isKing) {
      _renderKingCrown(canvas, radius);
    }
  }

  void _renderKingCrown(Canvas canvas, double radius) {
    final crownSize = radius * 0.5;
    final path = Path()
      ..moveTo(-crownSize, crownSize * 0.2)
      ..lineTo(-crownSize * 0.6, -crownSize * 0.3)
      ..lineTo(0, -crownSize * 0.5)
      ..lineTo(crownSize * 0.6, -crownSize * 0.3)
      ..lineTo(crownSize, crownSize * 0.2)
      ..close();

    // Crown fill
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFD700));
    
    // Crown outline
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8860B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}