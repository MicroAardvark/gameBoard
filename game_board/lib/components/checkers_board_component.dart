// checkers_board.dart - CheckersBoard component and rendering logic
// UK English spelling throughout

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

// Import components, models, and game logic
import 'checkers_piece_component.dart';
import '../games/checkers_game.dart';

/// The checkers board component that manages squares and pieces
class CheckersBoard extends PositionComponent with TapCallbacks,  HasGameRef<CheckersGame> {
  final GameStateManager stateManager;
  final List<List<SquareComponent>> squares = [];
  final List<PieceComponent> pieces = [];
  //late CheckersGame game;

  CheckersBoard(this.stateManager) : super(
    position: Vector2.zero(),
    size: Vector2.all(BOARD_PIXELS),
    anchor: Anchor.center,  // Keep topLeft for simpler positioning
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Centre the board on screen
    position = gameRef.size / 2;

    // Create squares
    for (int row = 0; row < BOARD_SIZE; row++) {
      final rowList = <SquareComponent>[];
      for (int col = 0; col < BOARD_SIZE; col++) {
        final square = SquareComponent(row, col);
        rowList.add(square);
        await add(square);
      }
      squares.add(rowList);
    }

    await _refreshPieces();
  }

  /// Refresh all piece components based on current board state
  Future<void> _refreshPieces() async {
    // Remove old pieces
    for (final piece in pieces) {
      remove(piece);
    }
    pieces.clear();

    // Create new pieces based on board state
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final piece = stateManager.boardState[row][col];
        if (piece != null) {
          final pieceComponent = PieceComponent(piece);
          pieces.add(pieceComponent);
          await add(pieceComponent);
        }
      }
    }
  }

  /// Handle tap on the board
  void handleTap(Vector2 localPos) {
    print('=== TAP DETECTED ===');
    print('Local position: $localPos');
    
    // Convert from board-local coordinates to grid coordinates
    final col = (localPos.x / TILE_SIZE).floor();
    final row = (localPos.y / TILE_SIZE).floor();
    
    print('Calculated grid position: ($row, $col)');

    // Validate bounds
    if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) {
      print('Tap out of bounds');
      return;
    }

    print('Valid tap at grid ($row, $col)');

    // Get the piece at this position (if any)
    final piece = stateManager.boardState[row][col];
    print('Piece at position: ${piece?.toString() ?? "null"}');

    // Handle selection and movement
    if (stateManager.selectedPosition == null) {
      // No piece selected yet - try to select
      if (piece != null && piece.colour == stateManager.currentPlayer) {
        print('Selecting piece at ($row, $col)');
        _selectPiece(row, col);
      } else {
        print('Cannot select: ${piece == null ? "no piece" : "wrong colour"}');
      }
    } else {
      // Piece already selected - try to move
      final selected = stateManager.selectedPosition!;
      print('Piece selected at (${selected.row}, ${selected.col})');
      
      if (row == selected.row && col == selected.col) {
        // Tapped same piece - deselect
        print('Deselecting piece');
        _deselectPiece();
      } else if (stateManager.validMoves.any((move) => move.row == row && move.col == col)) {
        // Valid move - execute it
        print('Executing move to ($row, $col)');
        _executeMove(row, col);
      } else {
        // Invalid move - check if tapping another own piece
        if (piece != null && piece.colour == stateManager.currentPlayer) {
          print('Selecting different piece at ($row, $col)');
          _selectPiece(row, col);
        } else {
          print('Invalid move');
        }
      }
    }
  }

  /// Select a piece and highlight valid moves
  void _selectPiece(int row, int col) {
    stateManager.selectedPosition = GridPosition(row, col);
    
    // Calculate valid moves for this piece
    stateManager.validMoves = stateManager.getValidMovesForPiece(row, col);
    print('Found ${stateManager.validMoves.length} valid moves');
    
    // Update visual highlights
    _updateHighlights();
  }

  /// Deselect the currently selected piece
  void _deselectPiece() {
    stateManager.selectedPosition = null;
    stateManager.validMoves.clear();
    _updateHighlights();
  }

  /// Execute a move from the selected piece to the target position
  void _executeMove(int toRow, int toCol) {
    final from = stateManager.selectedPosition!;
    print('Moving piece from (${from.row}, ${from.col}) to ($toRow, $toCol)');
    
    final result = stateManager.executeMove(from.row, from.col, toRow, toCol);
    
    if (result.success) {
      print('Move successful! Promoted: ${result.promoted}');
      
      // Refresh pieces to reflect new board state
      _refreshPieces();
      
      // Clear selection
      _deselectPiece();
      
      // Check for game over
      if (result.winner != null) {
        print('GAME OVER! Winner: ${result.winner}');
        game.onGameOver?.call(result.winner!);
      } else {
        // If not game over and no continued capture, trigger AI move
        if (stateManager.currentPlayer == 'black') {
          print('AI turn starting...');
          Future.delayed(const Duration(milliseconds: 500), () {
            _performAIMove();
          });
        }
      }
    } else {
      print('Move failed: ${result.error}');
    }
  }

  /// Perform an AI move
  void _performAIMove() {
    print('=== AI THINKING ===');
    final move = stateManager.getAIMove();
    
    if (move != null) {
      print('AI selected move: ${move.toString()}');
      final result = stateManager.executeMove(
        move.fromRow, 
        move.fromCol, 
        move.toRow, 
        move.toCol,
      );
      
      if (result.success) {
        print('AI move executed successfully');
        _refreshPieces();
        
        // Check for game over
        if (result.winner != null) {
          print('GAME OVER! Winner: ${result.winner}');
          game.onGameOver?.call(result.winner!);
        }
      }
    } else {
      print('AI has no valid moves - player wins!');
      game.onGameOver?.call('red');
    }
  }

  /// Update visual highlights for squares
  void _updateHighlights() {
    final selected = stateManager.selectedPosition;
    
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final isSelected = selected != null && selected.row == row && selected.col == col;
        final isValidMove = stateManager.validMoves.any((move) => move.row == row && move.col == col);
        squares[row][col].updateHighlight(isSelected, isValidMove);
      }
    }
  }
}