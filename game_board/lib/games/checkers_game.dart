// checkers_game.dart - Single-player Checkers using Flutter and Flame
// UK English spelling throughout

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

// Board configuration
const double boardSize = 8;
const double tileSize = 60.0;
const Color lightSquareColour = Color(0xFFEEEED2);
const Color darkSquareColour = Color(0xFF769656);
const Color selectedColour = Color(0xFFFFFF00);
const Color validMoveColour = Color(0x8800FF00);

class CheckersGame extends FlameGame with TapDetector {
  late CheckersBoard board;
  late GameStateManager stateManager;
  Function(String)? onGameOver;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    stateManager = GameStateManager();
    board = CheckersBoard(stateManager);
    board.game = this;
    
    add(board);
  }

  @override
  void onTapDown(TapDownInfo info) {
    // Get tap position in game coordinates
    final tapPosition = info.eventPosition.global;
    board.handleTap(tapPosition);
  }
}

class GameStateManager {
  List<List<CheckersPiece?>> boardState = List.generate(
    8, 
    (row) => List.generate(8, (col) => null)
  );
  
  String currentPlayer = 'red';
  Position? selectedPosition;
  List<Position> validMoves = [];
  String gameState = 'active';
  String? winner;
  bool mustContinue = false;
  Position? continueFrom;
  
  GameStateManager() {
    initialiseBoard();
  }

  void initialiseBoard() {
    // Place black pieces (AI) on rows 0-2
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          boardState[row][col] = CheckersPiece(
            colour: 'black',
            isKing: false,
            position: Position(row, col)
          );
        }
      }
    }
    
    // Place red pieces (player) on rows 5-7
    for (int row = 5; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          boardState[row][col] = CheckersPiece(
            colour: 'red',
            isKing: false,
            position: Position(row, col)
          );
        }
      }
    }
  }

  List<MoveOption> getValidMoves(int row, int col) {
    final piece = boardState[row][col];
    if (piece == null || piece.colour != currentPlayer) {
      return [];
    }

    List<MoveOption> moves = [];
    List<MoveOption> captures = [];

    // Direction vectors
    List<List<int>> directions = piece.isKing 
      ? [[-1, -1], [-1, 1], [1, -1], [1, 1]]
      : piece.colour == 'red'
        ? [[-1, -1], [-1, 1]]
        : [[1, -1], [1, 1]];

    // Check for captures first
    for (var dir in directions) {
      final capture = checkCapture(row, col, dir[0], dir[1], piece.isKing);
      if (capture != null) {
        captures.add(capture);
      }
    }

    // If captures available, only return captures (mandatory)
    if (captures.isNotEmpty) {
      return captures;
    }

    // Check regular moves
    for (var dir in directions) {
      final newRow = row + dir[0];
      final newCol = col + dir[1];

      if (isValidPosition(newRow, newCol) && boardState[newRow][newCol] == null) {
        moves.add(MoveOption(
          from: Position(row, col),
          to: Position(newRow, newCol),
          isCapture: false
        ));
      }
    }

    return moves;
  }

  MoveOption? checkCapture(int row, int col, int dRow, int dCol, bool isKing) {
    final jumpRow = row + dRow;
    final jumpCol = col + dCol;
    final landRow = row + (dRow * 2);
    final landCol = col + (dCol * 2);

    if (!isValidPosition(landRow, landCol)) return null;

    final jumpPiece = boardState[jumpRow][jumpCol];
    final landSpace = boardState[landRow][landCol];

    if (jumpPiece != null &&
        jumpPiece.colour != currentPlayer &&
        landSpace == null) {
      return MoveOption(
        from: Position(row, col),
        to: Position(landRow, landCol),
        captured: Position(jumpRow, jumpCol),
        isCapture: true
      );
    }

    return null;
  }

  bool isValidPosition(int row, int col) {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
  }

  MoveResult makeMove(Position from, Position to) {
    final piece = boardState[from.row][from.col];
    if (piece == null) {
      return MoveResult(success: false, error: 'No piece at position');
    }

    // Validate move
    final validMovesList = getValidMoves(from.row, from.col);
    final move = validMovesList.where((m) => 
      m.to.row == to.row && m.to.col == to.col
    ).firstOrNull;

    if (move == null) {
      return MoveResult(success: false, error: 'Invalid move');
    }

    // Execute move
    boardState[to.row][to.col] = piece;
    boardState[from.row][from.col] = null;
    piece.position = to;

    CheckersPiece? capturedPiece;

    // Handle capture
    if (move.isCapture && move.captured != null) {
      capturedPiece = boardState[move.captured!.row][move.captured!.col];
      boardState[move.captured!.row][move.captured!.col] = null;

      // Check for chain captures
      final furtherCaptures = getValidMoves(to.row, to.col)
          .where((m) => m.isCapture).toList();

      if (furtherCaptures.isNotEmpty) {
        return MoveResult(
          success: true,
          capturedPiece: capturedPiece,
          mustContinue: true,
          continueFrom: to,
          possibleMoves: furtherCaptures
        );
      }
    }

    // Check for promotion
    bool promoted = false;
    if (!piece.isKing) {
      if ((piece.colour == 'red' && to.row == 0) ||
          (piece.colour == 'black' && to.row == 7)) {
        piece.isKing = true;
        promoted = true;
      }
    }

    // Switch player
    currentPlayer = currentPlayer == 'red' ? 'black' : 'red';

    // Check winner
    final winnerColour = checkWinner();
    if (winnerColour != null) {
      gameState = 'finished';
      winner = winnerColour;
    }

    return MoveResult(
      success: true,
      capturedPiece: capturedPiece,
      promoted: promoted,
      winner: winnerColour
    );
  }

  String? checkWinner() {
    int redCount = 0;
    int blackCount = 0;
    List<Position> redPieces = [];
    List<Position> blackPieces = [];

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = boardState[row][col];
        if (piece != null) {
          if (piece.colour == 'red') {
            redCount++;
            redPieces.add(Position(row, col));
          } else {
            blackCount++;
            blackPieces.add(Position(row, col));
          }
        }
      }
    }

    if (redCount == 0) return 'black';
    if (blackCount == 0) return 'red';

    // Check if current player has valid moves
    final currentPieces = currentPlayer == 'red' ? redPieces : blackPieces;
    final hasValidMoves = currentPieces.any((pos) => 
      getValidMoves(pos.row, pos.col).isNotEmpty
    );

    if (!hasValidMoves) {
      return currentPlayer == 'red' ? 'black' : 'red';
    }

    return null;
  }
}

class CheckersBoard extends PositionComponent with TapCallbacks {
  final GameStateManager stateManager;
  final List<List<SquareComponent>> squares = [];
  final List<PieceComponent> pieces = [];
  late CheckersGame game;

  CheckersBoard(this.stateManager) : super(
    size: Vector2.all(boardSize * tileSize),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Create board squares
    for (int row = 0; row < 8; row++) {
      squares.add([]);
      for (int col = 0; col < 8; col++) {
        final square = SquareComponent(
          row: row,
          col: col,
          isLight: (row + col) % 2 == 0,
        );
        squares[row].add(square);
        add(square);
      }
    }

    // Create pieces
    updatePieces();
  }

  void updatePieces() {
    // Remove existing pieces
    for (final piece in pieces) {
      remove(piece);
    }
    pieces.clear();

    // Add current pieces
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = stateManager.boardState[row][col];
        if (piece != null) {
          final pieceComponent = PieceComponent(
            piece: piece,
            row: row,
            col: col,
          );
          pieces.add(pieceComponent);
          add(pieceComponent);
        }
      }
    }
  }

  void handleTap(Vector2 position) {
    // Convert position to board coordinates
    final col = (position.x / tileSize).floor();
    final row = (position.y / tileSize).floor();

    if (!stateManager.isValidPosition(row, col)) return;

    // If it's AI's turn, ignore taps
    if (stateManager.currentPlayer == 'black') return;

    final tappedPiece = stateManager.boardState[row][col];

    // If a piece is already selected
    if (stateManager.selectedPosition != null) {
      final selectedPos = stateManager.selectedPosition!;
      
      // Check if tapped position is a valid move
      final isValidMove = stateManager.validMoves.any((move) =>
        move.row == row && move.col == col
      );

      if (isValidMove) {
        // Make the move
        final result = stateManager.makeMove(selectedPos, Position(row, col));
        
        if (result.success) {
          updatePieces();
          clearSelection();

          // Handle chain captures
          if (result.mustContinue && result.continueFrom != null) {
            selectPiece(result.continueFrom!.row, result.continueFrom!.col);
            return;
          }

          // Check for game over
          if (result.winner != null) {
            handleGameOver(result.winner!);
            return;
          }

          // Trigger AI move
          if (stateManager.currentPlayer == 'black') {
            Future.delayed(Duration(milliseconds: 500), makeAIMove);
          }
        }
      } else if (tappedPiece != null && tappedPiece.colour == 'red') {
        // Select different piece
        selectPiece(row, col);
      } else {
        clearSelection();
      }
    } else {
      // Select a piece
      if (tappedPiece != null && tappedPiece.colour == 'red') {
        selectPiece(row, col);
      }
    }

    updateHighlights();
  }

  void selectPiece(int row, int col) {
    stateManager.selectedPosition = Position(row, col);
    final moves = stateManager.getValidMoves(row, col);
    stateManager.validMoves = moves.map((m) => m.to).toList();
  }

  void clearSelection() {
    stateManager.selectedPosition = null;
    stateManager.validMoves = [];
  }

  void updateHighlights() {
    // Update square highlights
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final square = squares[row][col];
        final isSelected = stateManager.selectedPosition != null &&
            stateManager.selectedPosition!.row == row &&
            stateManager.selectedPosition!.col == col;
        final isValidMove = stateManager.validMoves.any((pos) =>
          pos.row == row && pos.col == col
        );
        
        square.updateHighlight(isSelected, isValidMove);
      }
    }
  }

  void makeAIMove() {
    // Simple AI: choose random valid move with preference for captures
    final allMoves = <MoveOption>[];
    
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = stateManager.boardState[row][col];
        if (piece != null && piece.colour == 'black') {
          allMoves.addAll(stateManager.getValidMoves(row, col));
        }
      }
    }

    if (allMoves.isEmpty) {
      handleGameOver('red');
      return;
    }

    // Prefer captures
    final captures = allMoves.where((m) => m.isCapture).toList();
    final move = captures.isNotEmpty 
        ? captures[math.Random().nextInt(captures.length)]
        : allMoves[math.Random().nextInt(allMoves.length)];

    final result = stateManager.makeMove(move.from, move.to);
    
    if (result.success) {
      updatePieces();
      
      if (result.winner != null) {
        handleGameOver(result.winner!);
      }
    }
  }

  void handleGameOver(String winner) {
    stateManager.gameState = 'finished';
    stateManager.winner = winner;
    // Notify parent via game instance callback
    if (game.onGameOver != null) {
      game.onGameOver!(winner);
    }
  }
}

class SquareComponent extends PositionComponent {
  final int row;
  final int col;
  final bool isLight;
  bool isSelected = false;
  bool isValidMove = false;

  SquareComponent({
    required this.row,
    required this.col,
    required this.isLight,
  }) : super(
    position: Vector2(col * tileSize, row * tileSize),
    size: Vector2.all(tileSize),
  );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    Color colour = isLight ? lightSquareColour : darkSquareColour;
    
    if (isSelected) {
      colour = selectedColour;
    } else if (isValidMove) {
      colour = validMoveColour;
    }

    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.fill;

    canvas.drawRect(size.toRect(), paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(size.toRect(), borderPaint);

    // Draw valid move indicator
    if (isValidMove) {
      final circlePaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        tileSize / 6,
        circlePaint,
      );
    }
  }

  void updateHighlight(bool selected, bool validMove) {
    isSelected = selected;
    isValidMove = validMove;
  }
}

class PieceComponent extends PositionComponent {
  final CheckersPiece piece;
  final int row;
  final int col;

  PieceComponent({
    required this.piece,
    required this.row,
    required this.col,
  }) : super(
    position: Vector2(
      col * tileSize + tileSize / 2,
      row * tileSize + tileSize / 2,
    ),
    size: Vector2.all(tileSize * 0.8),
    anchor: Anchor.center,
  );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = tileSize * 0.35;
    final centre = Offset(0, 0);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(centre + const Offset(2, 2), radius, shadowPaint);

    // Piece colour
    final piecePaint = Paint()
      ..color = piece.colour == 'red' ? Colors.red : Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(centre, radius, piecePaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(centre, radius, borderPaint);

    // King crown
    if (piece.isKing) {
      final crownPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;

      final crownPath = Path();
      final crownSize = radius * 0.6;
      
      crownPath.moveTo(-crownSize / 2, crownSize / 4);
      crownPath.lineTo(-crownSize / 4, -crownSize / 4);
      crownPath.lineTo(0, crownSize / 4);
      crownPath.lineTo(crownSize / 4, -crownSize / 4);
      crownPath.lineTo(crownSize / 2, crownSize / 4);
      crownPath.close();

      canvas.drawPath(crownPath, crownPaint);

      // Crown border
      final crownBorderPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawPath(crownPath, crownBorderPaint);
    }
  }
}

// Data classes
class CheckersPiece {
  String colour;
  bool isKing;
  Position position;

  CheckersPiece({
    required this.colour,
    required this.isKing,
    required this.position,
  });
}

class Position {
  final int row;
  final int col;

  Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class MoveOption {
  final Position from;
  final Position to;
  final Position? captured;
  final bool isCapture;

  MoveOption({
    required this.from,
    required this.to,
    this.captured,
    required this.isCapture,
  });
}

class MoveResult {
  final bool success;
  final String? error;
  final CheckersPiece? capturedPiece;
  final bool mustContinue;
  final Position? continueFrom;
  final List<MoveOption>? possibleMoves;
  final bool promoted;
  final String? winner;

  MoveResult({
    required this.success,
    this.error,
    this.capturedPiece,
    this.mustContinue = false,
    this.continueFrom,
    this.possibleMoves,
    this.promoted = false,
    this.winner,
  });
}