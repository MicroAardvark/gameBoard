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
class CheckersBoard extends PositionComponent with TapCallbacks {
  final GameStateManager stateManager;
  final List<List<SquareComponent>> squares = [];
  final List<PieceComponent> pieces = [];
  late CheckersGame game;

  CheckersBoard(this.stateManager) : super(
    position: Vector2.zero(),
    size: Vector2.all(BOARD_PIXELS),
    anchor: Anchor.topLeft,  // Keep topLeft for simpler positioning
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    print('=== LOADING CHECKERS BOARD ===');
    
    // Create all squares
    for (int row = 0; row < BOARD_SIZE; row++) {
      final rowList = <SquareComponent>[];
      for (int col = 0; col < BOARD_SIZE; col++) {
        final square = SquareComponent(row, col);
        rowList.add(square);
        await add(square);
      }
      squares.add(rowList);
    }
    print('Created ${BOARD_SIZE * BOARD_SIZE} squares');

    // Create all pieces
    await _refreshPieces();
    
    print('=== BOARD LOADING COMPLETE ===');
  }

  /// Refresh all piece components based on current board state
  Future<void> _refreshPieces() async {
    print('=== REFRESHING PIECES ===');
    
    // Remove old pieces
    print('Removing ${pieces.length} old piece components');
    for (final piece in pieces) {
      remove(piece);
    }
    pieces.clear();

    // Create new pieces based on board state
    int pieceCount = 0;
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final piece = stateManager.boardState[row][col];
        if (piece != null) {
          pieceCount++;
          final xPos = piece.col.toDouble() * TILE_SIZE + TILE_SIZE / 2;
          final yPos = piece.row.toDouble() * TILE_SIZE + TILE_SIZE / 2;
          print('Creating ${piece.colour} piece component at board($row,$col) -> screen($xPos,$yPos)');
          
          final pieceComponent = PieceComponent(piece);
          pieces.add(pieceComponent);
          await add(pieceComponent);
        }
      }
    }
    print('Created $pieceCount piece components');
    print('=== PIECE REFRESH COMPLETE ===');
  }

  /// Handle tap events on the board
  void handleTap(Vector2 localPosition) {
    final col = (localPosition.x / TILE_SIZE).floor().clamp(0, BOARD_SIZE - 1);
    final row = (localPosition.y / TILE_SIZE).floor().clamp(0, BOARD_SIZE - 1);

    print('Tap at board position: ($row, $col)');

    if (stateManager.currentPlayer == 'black') {
      print('Ignoring tap - AI turn');
      return; // AI's turn
    }

    final tappedPiece = stateManager.boardState[row][col];
    final selected = stateManager.selectedPosition;

    if (selected != null) {
      // Try to move
      final isValidMove = stateManager.validMoves.any(
        (pos) => pos.row == row && pos.col == col,
      );

      if (isValidMove) {
        print('Valid move: (${selected.row},${selected.col}) -> ($row,$col)');
        final result = stateManager.makeMove(selected, GridPosition(row, col));
        if (result.success) {
          _refreshPieces();
          _clearSelection();

          if (result.winner != null) {
            _handleGameOver(result.winner!);
          } else if (stateManager.currentPlayer == 'black') {
            // Trigger AI move
            Future.delayed(const Duration(milliseconds: 500), _makeAIMove);
          }
        }
      } else if (tappedPiece != null && tappedPiece.colour == 'red') {
        print('Selecting different piece');
        _selectPiece(row, col);
      } else {
        print('Clearing selection');
        _clearSelection();
      }
    } else if (tappedPiece != null && tappedPiece.colour == 'red') {
      print('Selecting piece');
      _selectPiece(row, col);
    }

    _updateHighlights();
  }

  /// Select a piece at the given position
  void _selectPiece(int row, int col) {
    stateManager.selectedPosition = GridPosition(row, col);
    final moves = stateManager.getValidMoves(row, col);
    stateManager.validMoves = moves.map((m) => GridPosition(m.toRow, m.toCol)).toList();
    print('Selected piece at ($row,$col), valid moves: ${stateManager.validMoves.length}');
  }

  /// Clear the current selection
  void _clearSelection() {
    stateManager.selectedPosition = null;
    stateManager.validMoves = [];
  }

  /// Update the visual highlights on the board
  void _updateHighlights() {
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final selected = stateManager.selectedPosition;
        final isSelected = selected != null && selected.row == row && selected.col == col;
        final isValidMove = stateManager.validMoves.any((p) => p.row == row && p.col == col);
        squares[row][col].updateHighlight(isSelected, isValidMove);
      }
    }
  }

  /// Make an AI move (simple random strategy with capture preference)
  void _makeAIMove() {
    print('=== AI MAKING MOVE ===');
    final allMoves = <MoveOption>[];
    
    for (int row = 0; row < BOARD_SIZE; row++) {
      for (int col = 0; col < BOARD_SIZE; col++) {
        final piece = stateManager.boardState[row][col];
        if (piece != null && piece.colour == 'black') {
          allMoves.addAll(stateManager.getValidMoves(row, col));
        }
      }
    }

    if (allMoves.isEmpty) {
      print('AI has no moves - player wins');
      _handleGameOver('red');
      return;
    }

    // Prefer captures
    final captures = allMoves.where((m) => m.isCapture).toList();
    final move = captures.isNotEmpty
        ? captures[math.Random().nextInt(captures.length)]
        : allMoves[math.Random().nextInt(allMoves.length)];

    print('AI moving: (${move.fromRow},${move.fromCol}) -> (${move.toRow},${move.toCol})');

    final result = stateManager.makeMove(
      GridPosition(move.fromRow, move.fromCol),
      GridPosition(move.toRow, move.toCol),
    );

    if (result.success) {
      _refreshPieces();
      if (result.winner != null) {
        _handleGameOver(result.winner!);
      }
    }
  }

  /// Handle game over
  void _handleGameOver(String winner) {
    print('=== GAME OVER: $winner wins ===');
    if (game.onGameOver != null) {
      game.onGameOver!(winner);
    }
  }
}