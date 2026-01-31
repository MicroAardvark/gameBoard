import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../games/checkers_game.dart';

/// Represents the checkers board
class CheckersBoard extends PositionComponent {
  final List<List<SquareComponent>> squares = [];
  final List<Position> highlightedSquares = [];
  Position? selectedSquare;
  
  CheckersBoard()
      : super(
          size: Vector2.all(CheckersConstants.squareSize * CheckersConstants.boardSize),
          anchor: Anchor.center,
        );
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    _createBoard();
  }
  
  /// Create the board squares
  void _createBoard() {
    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      squares.add([]);
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final isDark = (row + col) % 2 == 1;
        final square = SquareComponent(
          boardPosition: Position(row, col),
          isDark: isDark,
        );
        
        square.position = Vector2(
          col * CheckersConstants.squareSize,
          row * CheckersConstants.squareSize,
        );
        
        squares[row].add(square);
        add(square);
      }
    }
  }
  
  /// Highlight valid move squares
  void highlightSquares(List<Position> positions) {
    // Clear previous highlights
    clearHighlights();
    
    highlightedSquares.addAll(positions);
    
    for (var pos in positions) {
      if (pos.isValid()) {
        squares[pos.row][pos.col].isHighlighted = true;
      }
    }
  }
  
  /// Clear all highlights
  void clearHighlights() {
    for (var pos in highlightedSquares) {
      if (pos.isValid()) {
        squares[pos.row][pos.col].isHighlighted = false;
      }
    }
    highlightedSquares.clear();
  }
  
  /// Select a square
  void selectSquare(Position pos) {
    // Deselect previous square
    if (selectedSquare != null && selectedSquare!.isValid()) {
      squares[selectedSquare!.row][selectedSquare!.col].isSelected = false;
    }
    
    selectedSquare = pos;
    if (pos.isValid()) {
      squares[pos.row][pos.col].isSelected = true;
    }
  }
  
  /// Deselect current square
  void deselectSquare() {
    if (selectedSquare != null && selectedSquare!.isValid()) {
      squares[selectedSquare!.row][selectedSquare!.col].isSelected = false;
    }
    selectedSquare = null;
  }
  
  /// Convert screen coordinates to board position
  Position? screenToBoard(Vector2 screenPosition) {
    // Board is center-anchored, so we need to offset from center
    final boardHalfSize = size.x / 2;
    final localPosition = screenPosition - (position - Vector2.all(boardHalfSize));
    
    final col = (localPosition.x / CheckersConstants.squareSize).floor();
    final row = (localPosition.y / CheckersConstants.squareSize).floor();
    
    final pos = Position(row, col);
    return pos.isValid() ? pos : null;
  }
  
  /// Convert board position to screen coordinates (centre of square)
  Vector2 boardToScreen(Position pos) {
    // Board is center-anchored, so we need to offset from center
    final boardHalfSize = size.x / 2;
    
    return Vector2(
      position.x - boardHalfSize + (pos.col * CheckersConstants.squareSize) + (CheckersConstants.squareSize / 2),
      position.y - boardHalfSize + (pos.row * CheckersConstants.squareSize) + (CheckersConstants.squareSize / 2),
    );
  }
}

/// Represents a single square on the board
class SquareComponent extends PositionComponent {
  final Position boardPosition;
  final bool isDark;
  bool isHighlighted = false;
  bool isSelected = false;
  
  SquareComponent({
    required this.boardPosition,
    required this.isDark,
  }) : super(
          size: Vector2.all(CheckersConstants.squareSize),
          anchor: Anchor.topLeft,
        );
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Base square colour
    Color squareColour = isDark ? CheckersConstants.darkSquare : CheckersConstants.lightSquare;
    
    // Override colour if selected or highlighted
    if (isSelected) {
      squareColour = CheckersConstants.selectedColour.withOpacity(0.6);
    } else if (isHighlighted) {
      squareColour = CheckersConstants.validMoveColour.withOpacity(0.4);
    }
    
    final paint = Paint()..color = squareColour;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      paint,
    );
    
    // Draw border for dark squares
    if (isDark) {
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        borderPaint,
      );
    }
    
    // Draw highlight indicator if this is a valid move square
    if (isHighlighted && !isSelected) {
      final indicatorPaint = Paint()
        ..color = CheckersConstants.validMoveColour
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 6,
        indicatorPaint,
      );
    }
  }
}