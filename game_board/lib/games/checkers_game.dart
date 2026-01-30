// checkers_game.dart - Single-player Checkers game logic and state management
// UK English spelling throughout

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';

// Import components, models, and board
import '../components/checkers_board_component.dart';
import '../components/checkers_piece_component.dart';

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

    // Centre and scale the board to fit the screen
    final smallerDimension = size.x < size.y ? size.x : size.y;
    final scale = smallerDimension / BOARD_PIXELS * 0.95; // 95% to add padding
    
    board!.scale = Vector2.all(scale);
    // Position board's top-left corner to centre the board on screen
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
    // Black pieces (top 3 rows, dark squares only)
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        // Place on dark squares (where row + col is odd)
        if ((row + col) % 2 == 1) {
          boardState[row][col] = CheckersPiece(
            colour: 'black',
            row: row,
            col: col,
          );
        }
      }
    }

    // Red pieces (bottom 3 rows, dark squares only)
    for (int row = 5; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        // Place on dark squares (where row + col is odd)
        if ((row + col) % 2 == 1) {
          boardState[row][col] = CheckersPiece(
            colour: 'red',
            row: row,
            col: col,
          );
        }
      }
    }
  }

  /// Get all valid moves for a piece at the given position
  List<GridPosition> getValidMovesForPiece(int row, int col) {
    final piece = boardState[row][col];
    if (piece == null || piece.colour != currentPlayer) {
      return [];
    }

    // First check for mandatory captures
    final captures = _getCaptureMovesForPiece(row, col);
    if (captures.isNotEmpty) {
      return captures.map((move) => GridPosition(move.toRow, move.toCol)).toList();
    }

    // If no captures, return regular moves
    final moves = _getRegularMovesForPiece(row, col);
    return moves.map((move) => GridPosition(move.toRow, move.toCol)).toList();
  }

  /// Get capture moves for a piece
  List<MoveOption> _getCaptureMovesForPiece(int row, int col) {
    final piece = boardState[row][col];
    if (piece == null) return [];

    final captures = <MoveOption>[];
    final directions = piece.isKing
        ? [[-1, -1], [-1, 1], [1, -1], [1, 1]] // Kings move all directions
        : piece.colour == 'red'
            ? [[-1, -1], [-1, 1]] // Red moves up
            : [[1, -1], [1, 1]];  // Black moves down

    for (final dir in directions) {
      final captureRow = row + dir[0];
      final captureCol = col + dir[1];
      final landRow = row + dir[0] * 2;
      final landCol = col + dir[1] * 2;

      // Check bounds
      if (landRow < 0 || landRow >= BOARD_SIZE || landCol < 0 || landCol >= BOARD_SIZE) {
        continue;
      }

      // Check if there's an opponent piece to capture
      final capturedPiece = boardState[captureRow][captureCol];
      if (capturedPiece != null && capturedPiece.colour != piece.colour) {
        // Check if landing square is empty
        if (boardState[landRow][landCol] == null) {
          captures.add(MoveOption(
            fromRow: row,
            fromCol: col,
            toRow: landRow,
            toCol: landCol,
            isCapture: true,
            capturedRow: captureRow,
            capturedCol: captureCol,
          ));
        }
      }
    }

    return captures;
  }

  /// Get regular (non-capture) moves for a piece
  List<MoveOption> _getRegularMovesForPiece(int row, int col) {
    final piece = boardState[row][col];
    if (piece == null) return [];

    final moves = <MoveOption>[];
    final directions = piece.isKing
        ? [[-1, -1], [-1, 1], [1, -1], [1, 1]] // Kings move all directions
        : piece.colour == 'red'
            ? [[-1, -1], [-1, 1]] // Red moves up
            : [[1, -1], [1, 1]];  // Black moves down

    for (final dir in directions) {
      final newRow = row + dir[0];
      final newCol = col + dir[1];

      // Check bounds
      if (newRow < 0 || newRow >= BOARD_SIZE || newCol < 0 || newCol >= BOARD_SIZE) {
        continue;
      }

      // Check if square is empty
      if (boardState[newRow][newCol] == null) {
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

  /// Execute a move and update the game state
  MoveResult executeMove(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = boardState[fromRow][fromCol];
    if (piece == null) {
      return MoveResult(success: false, error: 'No piece at source position');
    }

    // Check if move is valid
    final validMoves = getValidMovesForPiece(fromRow, fromCol);
    if (!validMoves.any((move) => move.row == toRow && move.col == toCol)) {
      return MoveResult(success: false, error: 'Invalid move');
    }

    // Check if it's a capture
    final isCapture = (fromRow - toRow).abs() == 2;
    
    if (isCapture) {
      // Remove captured piece
      final capturedRow = (fromRow + toRow) ~/ 2;
      final capturedCol = (fromCol + toCol) ~/ 2;
      boardState[capturedRow][capturedCol] = null;
      print('Captured piece at ($capturedRow, $capturedCol)');
    }

    // Move the piece
    boardState[toRow][toCol] = piece;
    boardState[fromRow][fromCol] = null;
    piece.row = toRow;
    piece.col = toCol;

    // Check for promotion
    bool promoted = false;
    if (!piece.isKing) {
      if ((piece.colour == 'red' && toRow == 0) || 
          (piece.colour == 'black' && toRow == BOARD_SIZE - 1)) {
        piece.isKing = true;
        promoted = true;
        print('Piece promoted to king!');
      }
    }

    // Check for continued captures
    if (isCapture && !promoted) {
      final moreCapturesAvailable = _getCaptureMovesForPiece(toRow, toCol).isNotEmpty;
      if (moreCapturesAvailable) {
        // Don't switch players - same player continues
        print('Continued capture available');
        return MoveResult(success: true, promoted: promoted);
      }
    }

    // Switch players
    currentPlayer = currentPlayer == 'red' ? 'black' : 'red';
    print('Turn switched to: $currentPlayer');

    // Check for win condition
    final opponentColour = currentPlayer;
    if (!_hasValidMoves(opponentColour)) {
      winner = currentPlayer == 'red' ? 'black' : 'red';
      gameState = 'gameover';
      return MoveResult(success: true, promoted: promoted, winner: winner);
    }

    return MoveResult(success: true, promoted: promoted);
  }

  /// Check if a player has any valid moves
  bool _hasValidMoves(String colour) {
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final piece = boardState[row][col];
        if (piece != null && piece.colour == colour) {
          if (getValidMovesForPiece(row, col).isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Get AI move (simple random for now)
  MoveOption? getAIMove() {
    final allMoves = <MoveOption>[];
    
    // Collect all valid moves for black pieces
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final piece = boardState[row][col];
        if (piece != null && piece.colour == 'black') {
          // First check for captures
          final captures = _getCaptureMovesForPiece(row, col);
          if (captures.isNotEmpty) {
            allMoves.addAll(captures);
          } else {
            // If no captures, add regular moves
            final moves = _getRegularMovesForPiece(row, col);
            allMoves.addAll(moves);
          }
        }
      }
    }

    if (allMoves.isEmpty) return null;

    // Prioritise captures
    final captures = allMoves.where((move) => move.isCapture).toList();
    if (captures.isNotEmpty) {
      captures.shuffle();
      return captures.first;
    }

    // Otherwise pick a random move
    allMoves.shuffle();
    return allMoves.first;
  }
}