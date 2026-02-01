// ====================================
// lib/games/multiplayer_checkers_game.dart
// Multiplayer checkers game with proper perspective for each player
// Player 1 (red): Sees red at bottom, plays upward
// Player 2 (black): Sees black at bottom (rotated view), plays upward
// ====================================

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../components/checkers_board_component.dart';
import '../components/checkers_piece_component.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import 'checkers_game.dart' show Position;

// ====================================
// MULTIPLAYER CHECKERS CONSTANTS
// ====================================

class CheckersConstants {
  static const int boardSize = 8;
  static const double squareSize = 48.0;
  static const double pieceSize = 36.0;
  static const double crownSize = 18.0;
  
  static const Color darkSquare = Color(0xFF000000);
  static const Color lightSquare = Color(0xFFF5F5DC);
  static const Color selectedColour = Color(0xFFFFD700);
  static const Color validMoveColour = Color(0xFF4169E1);
  static const Color redPieceColour = Color(0xFFDC143C); // Red pieces
  static const Color blackPieceColour = Color(0xFF1C1C1C); // Black pieces
  static const Color kingBorderColour = Color(0xFFFFD700);
  
  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  
  // Piece types representing actual colours
  static const int emptySquare = 0;
  static const int redPiece = 1;
  static const int redKing = 2;
  static const int blackPiece = 3;
  static const int blackKing = 4;
}

// ====================================
// MULTIPLAYER CHECKERS GAME
// ====================================

class MultiplayerCheckersGame extends FlameGame with TapDetector {
  final User user;
  final String roomId;
  final SocketService socketService;
  final Function(String) onStatusUpdate;
  final Function(String) onGameOver;
  final Function(bool) onTurnChanged;

  late CheckersBoard board;
  String myColour = '';  // 'red' or 'black'
  bool shouldRotateBoard = false;  // true for Player 2 (black)
  List<Position> validMoves = [];
  Position? selectedPiece;
  bool isMyTurn = false;
  bool gameStarted = false;
  
  List<CheckersPiece> pieces = [];

  MultiplayerCheckersGame({
    required this.user,
    required this.roomId,
    required this.socketService,
    required this.onStatusUpdate,
    required this.onGameOver,
    required this.onTurnChanged,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Create board (8x8 checkers board, centre anchored)
    board = CheckersBoard()
      ..position = size / 2;  // Centre of screen
    await add(board);

    print('🎮 Multiplayer checkers game loaded');
  }

  /// Sync board state from server
  void syncBoardFromServer(Map<String, dynamic> data) {
    print('📥 Syncing board from server');
    
    final boardState = data['board'] as List;
    final playerColours = data['playerColours'] as Map<String, dynamic>;
    
    // Determine my colour
    myColour = playerColours[user.id] ?? 'red';
    
    // Player 2 (black) gets rotated view
    shouldRotateBoard = (myColour == 'black');
    
    print('My colour: $myColour, Rotate board: $shouldRotateBoard');
    
    // Clear existing pieces
    for (var piece in pieces) {
      piece.removeFromParent();
    }
    pieces.clear();
    
    // Create pieces based on board state
    for (int row = 0; row < 8; row++) {
      final rowData = boardState[row] as List;
      for (int col = 0; col < 8; col++) {
        final pieceData = rowData[col];
        
        if (pieceData != null) {
          final int pieceType = _mapServerPieceToLocal(pieceData);
          
          if (pieceType != CheckersConstants.emptySquare) {
            // Transform position for rotated view
            final displayPos = shouldRotateBoard 
              ? Position(7 - row, 7 - col)  // Rotate 180°
              : Position(row, col);
            
            final screenPos = board.boardToScreen(displayPos);
            
            final piece = CheckersPiece(
              pieceType: pieceType,
              boardPosition: Position(row, col),  // Store actual server position
              position: screenPos,
            );
            
            pieces.add(piece);
            add(piece);
          }
        }
      }
    }
    
    // Check whose turn it is
    final currentPlayer = data['currentPlayer'] as String?;
    if (currentPlayer != null) {
      isMyTurn = (currentPlayer == user.id);
      onTurnChanged(isMyTurn);
      onStatusUpdate(isMyTurn ? 'Your turn!' : 'Opponent\'s turn');
    }
    
    gameStarted = true;
  }

  /// Map server piece type to local constants - now using actual colours
  int _mapServerPieceToLocal(dynamic serverPiece) {
    if (serverPiece == null) return CheckersConstants.emptySquare;
    
    final pieceMap = serverPiece as Map<String, dynamic>;
    final colour = pieceMap['colour'] as String;
    final isKing = pieceMap['isKing'] as bool;
    
    // Map to actual colours (no player/opponent abstraction)
    if (colour == 'red' && !isKing) return CheckersConstants.redPiece;
    if (colour == 'red' && isKing) return CheckersConstants.redKing;
    if (colour == 'black' && !isKing) return CheckersConstants.blackPiece;
    if (colour == 'black' && isKing) return CheckersConstants.blackKing;
    
    return CheckersConstants.emptySquare;
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    
    if (!gameStarted || !isMyTurn) {
      print('❌ Not your turn or game not started');
      return;
    }
    
    final tapPos = info.eventPosition.global;
    final boardPos = board.screenToBoard(tapPos);
    
    if (boardPos == null || !boardPos.isValid()) {
      print('❌ Invalid board position');
      return;
    }
    
    // Transform coordinates if board is rotated
    final serverPos = shouldRotateBoard
      ? Position(7 - boardPos.row, 7 - boardPos.col)  // Rotate back to server coordinates
      : boardPos;
    
    print('🖱️ Tapped: Display($boardPos) -> Server($serverPos)');
    
    // Check if tapping a valid move
    if (selectedPiece != null) {
      final validMove = validMoves.where((move) {
        return move.row == serverPos.row && move.col == serverPos.col;
      }).firstOrNull;
      
      if (validMove != null) {
        // Make the move
        _makeMove(selectedPiece!, serverPos);
        return;
      }
    }
    
    // Check if selecting a piece
    final tappedPiece = pieces.where((p) {
      return p.boardPosition.row == serverPos.row && 
             p.boardPosition.col == serverPos.col;
    }).firstOrNull;
    
    if (tappedPiece != null) {
      // Check if it's my piece
      final bool isMyPiece = (myColour == 'red' && 
          (tappedPiece.pieceType == CheckersConstants.redPiece || 
           tappedPiece.pieceType == CheckersConstants.redKing)) ||
         (myColour == 'black' && 
          (tappedPiece.pieceType == CheckersConstants.blackPiece || 
           tappedPiece.pieceType == CheckersConstants.blackKing));
      
      if (isMyPiece) {
        _selectPiece(serverPos);
      }
    }
  }

  void _selectPiece(Position pos) {
    print('🎯 Selecting piece at $pos');
    
    selectedPiece = pos;
    
    // Request valid moves from server
    socketService.sendGameAction(
      roomId: roomId,
      action: 'select_piece',
      payload: {
        'gameType': 'checkers',
        'userId': user.id,
        'row': pos.row,
        'col': pos.col,
      },
    );
  }

  void _makeMove(Position from, Position to) {
    print('🎯 Making move: $from -> $to');
    
    socketService.sendGameAction(
      roomId: roomId,
      action: 'make_move',
      payload: {
        'gameType': 'checkers',
        'userId': user.id,
        'from': {'row': from.row, 'col': from.col},
        'to': {'row': to.row, 'col': to.col},
      },
    );
    
    // Clear selection
    selectedPiece = null;
    validMoves.clear();
    board.clearHighlights();
    board.deselectSquare();
  }

  /// Handle valid moves from server
  void handlePieceSelected(Map<String, dynamic> data) {
    print('📍 Valid moves received');
    
    final moves = data['validMoves'] as List;
    validMoves = moves.map((move) {
      final to = move['to'] as Map<String, dynamic>;
      return Position(to['row'] as int, to['col'] as int);
    }).toList();
    
    // Highlight valid moves on board (transform for display)
    final displayMoves = validMoves.map((serverPos) {
      return shouldRotateBoard
        ? Position(7 - serverPos.row, 7 - serverPos.col)
        : serverPos;
    }).toList();
    
    board.highlightSquares(displayMoves);
    
    // Highlight selected piece (transform for display)
    if (selectedPiece != null) {
      final displayPos = shouldRotateBoard
        ? Position(7 - selectedPiece!.row, 7 - selectedPiece!.col)
        : selectedPiece!;
      board.selectSquare(displayPos);
    }
  }

  /// Handle move made by any player
  void handleMoveMade(Map<String, dynamic> data) {
    print('♟️ Move made');
    
    final from = data['from'] as Map<String, dynamic>;
    final to = data['to'] as Map<String, dynamic>;
    final capturedPiece = data['capturedPiece'] as Map<String, dynamic>?;
    final promoted = data['promoted'] as bool?;
    
    final fromPos = Position(from['row'] as int, from['col'] as int);
    final toPos = Position(to['row'] as int, to['col'] as int);
    
    // Find and move the piece
    final movingPiece = pieces.where((p) {
      final pos = p.boardPosition;
      return pos.row == fromPos.row && pos.col == fromPos.col;
    }).firstOrNull;
    
    if (movingPiece != null) {
      // Update piece type if promoted
      int newPieceType = movingPiece.pieceType;
      if (promoted == true) {
        newPieceType = newPieceType == CheckersConstants.redPiece 
          ? CheckersConstants.redKing 
          : CheckersConstants.blackKing;
      }
      
      // Calculate new display position
      final displayPos = shouldRotateBoard
        ? Position(7 - toPos.row, 7 - toPos.col)
        : toPos;
      
      final newScreenPos = board.boardToScreen(displayPos);
      
      // Create new piece at new position
      final newPiece = CheckersPiece(
        pieceType: newPieceType,
        boardPosition: toPos,  // Store server position
        position: newScreenPos,
      );
      
      // Remove old piece and add new one
      movingPiece.removeFromParent();
      pieces.remove(movingPiece);
      pieces.add(newPiece);
      add(newPiece);
      
      // Handle captured piece
      if (capturedPiece != null) {
        final capturedRow = (fromPos.row + toPos.row) ~/ 2;
        final capturedCol = (fromPos.col + toPos.col) ~/ 2;
        final capPos = Position(capturedRow, capturedCol);
        _removePieceAt(capPos);
        print('💥 Captured piece at $capPos');
      }
    }
    
    // Clear selection
    board.clearHighlights();
    board.deselectSquare();
    selectedPiece = null;
    validMoves.clear();
  }

  void _removePieceAt(Position pos) {
    print('💥 Removing captured piece at $pos');
    
    final capturedPiece = pieces.where((p) {
      final pPos = p.boardPosition;
      return pPos.row == pos.row && pPos.col == pos.col;
    }).firstOrNull;
    
    if (capturedPiece != null) {
      capturedPiece.removeFromParent();
      pieces.remove(capturedPiece);
    }
  }

  /// Handle turn changed
  void handleTurnChanged(Map<String, dynamic> data) {
    print('🔄 Turn changed');
    
    final currentPlayer = data['currentPlayer'] as String;
    isMyTurn = (currentPlayer == user.id);
    
    onTurnChanged(isMyTurn);
    onStatusUpdate(isMyTurn ? 'Your turn!' : 'Opponent\'s turn');
  }

  /// Handle game over
  void handleGameOver(Map<String, dynamic> data) {
    print('🏁 Game over');
    
    final winner = data['winner'] as String;
    final reason = data['reason'] as String? ?? 'Game ended';
    
    gameStarted = false;
    
    if (winner == myColour) {
      onGameOver('You won! $reason');
    } else {
      onGameOver('You lost! $reason');
    }
  }
}