// checkers_game.dart - Single-player Checkers game logic and state management
// UK English spelling throughout

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';

// Import components, models, and board
import '../components/checkers_piece_component.dart';
import '../components/checkers_board_component.dart';

/// Main game class that manages the checkers game
class CheckersGame extends FlameGame {
  CheckersBoard? board;
  late GameStateManager stateManager;
  Function(String)? onGameOver;
  
  CheckersGame() {
    stateManager = GameStateManager();
  }
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    board = CheckersBoard(stateManager);
    board!.game = this;
    await add(board!);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    if (board == null) return; // Guard clause - board not loaded yet

    // Center and scale the board to fit the screen
    final smallerDimension = size.x < size.y ? size.x : size.y;
    final scale = smallerDimension / BOARD_PIXELS * 0.95; // 95% to add padding
    
    board!.scale = Vector2.all(scale);
    board!.position = Vector2(
      (size.x - BOARD_PIXELS * scale) / 2,
      (size.y - BOARD_PIXELS * scale) / 2,
    );
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (board == null) return; // Guard clause
    
    final tapPos = info.eventPosition.global;
    final localPos = board!.absoluteToLocal(tapPos);
    board!.handleTap(localPos);
  }
}

/// Manages the game state and logic
class GameStateManager {
  // Board state: [row][col] -> piece or null
  final List<List<CheckersPiece?>> boardState = List.generate(
    BOARD_SIZE,
    (_) => List.filled(BOARD_SIZE, null),
  );
  
  String currentPlayer = 'red';
  GridPosition? selectedPosition;
  List<GridPosition> validMoves = [];
  String gameState = 'active';
  String? winner;
  
  GameStateManager() {
    _initializeBoard();
  }

  /// Initialize the board with pieces in starting positions
  void _initializeBoard() {
    print('=== INITIALIZING CHECKERS BOARD ===');
    
    // Black pieces (AI) on rows 0-2, dark squares only
    int blackCount = 0;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        if (_isDarkSquare(row, col)) {
          boardState[row][col] = CheckersPiece(
            colour: 'black',
            row: row,
            col: col,
          );
          blackCount++;
          print('Black piece at ($row, $col) - isDark: ${_isDarkSquare(row, col)}');
        }
      }
    }
    print('Total black pieces: $blackCount (should be 12)');
    
    // Red pieces (Player) on rows 5-7, dark squares only
    int redCount = 0;
    for (int row = 5; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        if (_isDarkSquare(row, col)) {
          boardState[row][col] = CheckersPiece(
            colour: 'red',
            row: row,
            col: col,
          );
          redCount++;
          print('Red piece at ($row, $col) - isDark: ${_isDarkSquare(row, col)}');
        }
      }
    }
    print('Total red pieces: $redCount (should be 12)');
    print('=== BOARD INITIALIZATION COMPLETE ===');
  }

  /// Check if a square is a dark square (where pieces can be placed)
  bool _isDarkSquare(int row, int col) {
    return (row + col) % 2 == 1;
  }

  /// Check if a position is valid on the board
  bool isValidPosition(int row, int col) {
    return row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE;
  }

  /// Get all valid moves for a piece at the given position
  List<MoveOption> getValidMoves(int row, int col) {
    final piece = boardState[row][col];
    if (piece == null || piece.colour != currentPlayer) {
      return [];
    }

    List<MoveOption> moves = [];
    List<MoveOption> captures = [];

    // Movement directions based on piece type
    final directions = piece.isKing
        ? [[-1, -1], [-1, 1], [1, -1], [1, 1]] // Kings: all directions
        : piece.colour == 'red'
            ? [[-1, -1], [-1, 1]] // Red: moves up
            : [[1, -1], [1, 1]]; // Black: moves down

    // Check captures first (mandatory in checkers)
    for (final dir in directions) {
      final capture = _checkCapture(row, col, dir[0], dir[1]);
      if (capture != null) captures.add(capture);
    }

    // If captures are available, only return captures (mandatory)
    if (captures.isNotEmpty) return captures;

    // Check regular moves (only if no captures available)
    for (final dir in directions) {
      final newRow = row + dir[0];
      final newCol = col + dir[1];
      
      if (isValidPosition(newRow, newCol) && boardState[newRow][newCol] == null) {
        moves.add(MoveOption(
          fromRow: row,
          fromCol: col,
          toRow: newRow,
          toCol: newCol,
          isCapture: false,
        ));
      }
    }

    return moves;
  }

  /// Check if a capture is possible in a given direction
  MoveOption? _checkCapture(int row, int col, int dRow, int dCol) {
    final jumpRow = row + dRow;
    final jumpCol = col + dCol;
    final landRow = row + dRow * 2;
    final landCol = col + dCol * 2;

    if (!isValidPosition(landRow, landCol)) return null;

    final jumpedPiece = boardState[jumpRow][jumpCol];
    final landSquare = boardState[landRow][landCol];

    if (jumpedPiece != null && 
        jumpedPiece.colour != currentPlayer && 
        landSquare == null) {
      return MoveOption(
        fromRow: row,
        fromCol: col,
        toRow: landRow,
        toCol: landCol,
        isCapture: true,
        capturedRow: jumpRow,
        capturedCol: jumpCol,
      );
    }

    return null;
  }

  /// Execute a move from one position to another
  MoveResult makeMove(GridPosition from, GridPosition to) {
    final piece = boardState[from.row][from.col];
    if (piece == null) {
      return MoveResult(success: false, error: 'No piece at position');
    }

    // Validate move
    final validMovesList = getValidMoves(from.row, from.col);
    final move = validMovesList.cast<MoveOption?>().firstWhere(
      (m) => m!.toRow == to.row && m.toCol == to.col,
      orElse: () => null,
    );

    if (move == null) {
      return MoveResult(success: false, error: 'Invalid move');
    }

    // Execute move
    boardState[to.row][to.col] = piece;
    boardState[from.row][from.col] = null;
    piece.row = to.row;
    piece.col = to.col;

    // Handle capture
    if (move.isCapture) {
      boardState[move.capturedRow!][move.capturedCol!] = null;
    }

    // Check for promotion to king
    bool promoted = false;
    if (!piece.isKing) {
      if ((piece.colour == 'red' && to.row == 0) ||
          (piece.colour == 'black' && to.row == BOARD_SIZE - 1)) {
        piece.isKing = true;
        promoted = true;
      }
    }

    // Switch player
    currentPlayer = currentPlayer == 'red' ? 'black' : 'red';

    // Check for winner
    final winnerColour = _checkWinner();
    if (winnerColour != null) {
      gameState = 'finished';
      winner = winnerColour;
    }

    return MoveResult(
      success: true,
      promoted: promoted,
      winner: winnerColour,
    );
  }

  /// Check if there's a winner
  String? _checkWinner() {
    int redCount = 0;
    int blackCount = 0;
    
    for (final row in boardState) {
      for (final piece in row) {
        if (piece != null) {
          if (piece.colour == 'red') redCount++;
          if (piece.colour == 'black') blackCount++;
        }
      }
    }

    if (redCount == 0) return 'black';
    if (blackCount == 0) return 'red';

    // Check if current player has valid moves
    bool hasValidMoves = false;
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final piece = boardState[row][col];
        if (piece != null && piece.colour == currentPlayer) {
          if (getValidMoves(row, col).isNotEmpty) {
            hasValidMoves = true;
            break;
          }
        }
      }
      if (hasValidMoves) break;
    }

    if (!hasValidMoves) {
      return currentPlayer == 'red' ? 'black' : 'red';
    }

    return null;
  }
}