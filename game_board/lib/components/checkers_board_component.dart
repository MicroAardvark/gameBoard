import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../games/checkers_game.dart';

/// The visual board, composed of an 8×8 grid of [SquareComponent] children.
///
/// Owns highlight and selection state so that game logic can drive the UI
/// through simple method calls rather than manipulating squares directly.
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

  /// Populates [squares] and adds each [SquareComponent] as a child.
  ///
  /// Dark squares are those where (row + col) is odd, matching the standard
  /// checkerboard colouring convention.
  void _createBoard() {
    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      squares.add([]);
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final isDark = (row + col) % 2 == 1;
        final square = SquareComponent(
          boardPosition: Position(row, col),
          isDark: isDark,
        );

        // Children of a PositionComponent are positioned relative to the
        // parent's top-left corner, which is (0,0) in local space.
        square.position = Vector2(
          col * CheckersConstants.squareSize,
          row * CheckersConstants.squareSize,
        );

        squares[row].add(square);
        add(square);
      }
    }
  }

  /// Clears any existing highlights and applies new ones to [positions].
  void highlightSquares(List<Position> positions) {
    clearHighlights();
    highlightedSquares.addAll(positions);
    for (var pos in positions) {
      if (pos.isValid()) {
        squares[pos.row][pos.col].isHighlighted = true;
      }
    }
  }

  /// Removes highlight state from all previously highlighted squares.
  void clearHighlights() {
    for (var pos in highlightedSquares) {
      if (pos.isValid()) {
        squares[pos.row][pos.col].isHighlighted = false;
      }
    }
    highlightedSquares.clear();
  }

  /// Marks [pos] as selected, deselecting the previous square if one exists.
  void selectSquare(Position pos) {
    if (selectedSquare != null && selectedSquare!.isValid()) {
      squares[selectedSquare!.row][selectedSquare!.col].isSelected = false;
    }
    selectedSquare = pos;
    if (pos.isValid()) {
      squares[pos.row][pos.col].isSelected = true;
    }
  }

  /// Clears the current selection without selecting a new square.
  void deselectSquare() {
    if (selectedSquare != null && selectedSquare!.isValid()) {
      squares[selectedSquare!.row][selectedSquare!.col].isSelected = false;
    }
    selectedSquare = null;
  }

  /// Converts a screen-space tap position to a board [Position], or null if
  /// the tap falls outside the board bounds.
  ///
  /// Because the board uses [Anchor.center], its top-left corner in game
  /// coordinates is `position - (size / 2)`, not simply `position`.
  Position? screenToBoard(Vector2 screenPosition) {
    final halfSize = size / 2;
    final boardTopLeft = position - halfSize;
    final boardBottomRight = position + halfSize;

    if (screenPosition.x < boardTopLeft.x ||
        screenPosition.x > boardBottomRight.x ||
        screenPosition.y < boardTopLeft.y ||
        screenPosition.y > boardBottomRight.y) {
      return null;
    }

    // Translate to board-local coordinates before dividing by square size.
    final localX = screenPosition.x - boardTopLeft.x;
    final localY = screenPosition.y - boardTopLeft.y;

    final col = (localX / CheckersConstants.squareSize).floor();
    final row = (localY / CheckersConstants.squareSize).floor();

    final pos = Position(row, col);
    return pos.isValid() ? pos : null;
  }

  /// Converts a board [Position] to the screen-space centre of that square.
  ///
  /// Used when placing or animating pieces so they snap to the visual centre
  /// of their target square regardless of board positioning on screen.
  Vector2 boardToScreen(Position pos) {
    final boardTopLeft = position - (size / 2);
    return boardTopLeft + Vector2(
      (pos.col * CheckersConstants.squareSize) + (CheckersConstants.squareSize / 2),
      (pos.row * CheckersConstants.squareSize) + (CheckersConstants.squareSize / 2),
    );
  }
}

/// A single square on the board, responsible only for rendering its own state.
///
/// Visual state (selected, highlighted) is set externally by [CheckersBoard]
/// so that game logic remains decoupled from rendering.
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

    // Selection takes visual priority over highlighting.
    Color squareColour = isDark ? CheckersConstants.darkSquare : CheckersConstants.lightSquare;
    if (isSelected) {
      squareColour = CheckersConstants.selectedColour.withOpacity(0.6);
    } else if (isHighlighted) {
      squareColour = CheckersConstants.validMoveColour.withOpacity(0.4);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = squareColour,
    );

    // A faint border on dark squares helps the grid read clearly at small sizes.
    if (isDark) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // A small filled circle provides a secondary valid-move indicator that
    // remains visible even when the square is occupied by a piece.
    if (isHighlighted && !isSelected) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 6,
        Paint()
          ..color = CheckersConstants.validMoveColour
          ..style = PaintingStyle.fill,
      );
    }
  }
}