// ====================================
// lib/games/multiplayer_checkers_game.dart
// Multiplayer checkers game - uses same board components as single player
// Players control their assigned colour (red or black)
// ====================================

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../components/checkers_board_component.dart';
import '../components/checkers_piece_component.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import 'checkers_game.dart' show Position; // Only import Position class

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
  static const Color playerPieceColour = Color(0xFFDC143C); // Red
  static const Color opponentPieceColour = Color(0xFF1C1C1C); // Black
  static const Color kingBorderColour = Color(0xFFFFD700);
  
  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  
  static const int emptySquare = 0;
  static const int myPiece = 1;
  static const int myKing = 2;
  static const int opponentPiece = 3;
  static const int opponentKing = 4;
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

    // Create board (8x8 checkers board, center anchored)
    board = CheckersBoard()
      ..position = size / 2;  // Center of screen
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
    
    print('My colour: $myColour');
    
    // Clear existing pieces
    for (var piece in pieces) {
      piece.removeFromParent();
    }
    pieces.clear();
    
    // Create pieces based on board state
    for (int row = 0; row < 8; row++) {
      final rowData = boardState[row] as List;
      for (int col = 0; col < 8; col++) {
        final pieceType = rowData[col];
        
        if (pieceType != 'empty') {
          final int mappedType = _mapServerPieceToLocal(pieceType);
          
          if (mappedType != CheckersConstants.emptySquare) {
            final pos = Position(row, col);
            final screenPos = board.boardToScreen(pos);
            
            final piece = CheckersPiece(
              pieceType: mappedType,
              boardPosition: pos,
              position: screenPos,
            );
            
            pieces.add(piece);
            add(piece);
          }
        }
      }
    }
    
    gameStarted = true;
  }

  /// Map server piece type ('red', 'black', 'redKing', 'blackKing') to local constants
  int _mapServerPieceToLocal(dynamic serverPiece) {
    final pieceStr = serverPiece.toString();
    
    if (myColour == 'red') {
      // I'm red (player 1)
      if (pieceStr == 'red') return CheckersConstants.myPiece;
      if (pieceStr == 'redKing') return CheckersConstants.myKing;
      if (pieceStr == 'black') return CheckersConstants.opponentPiece;
      if (pieceStr == 'blackKing') return CheckersConstants.opponentKing;
    } else {
      // I'm black (player 2)
      if (pieceStr == 'black') return CheckersConstants.myPiece;
      if (pieceStr == 'blackKing') return CheckersConstants.myKing;
      if (pieceStr == 'red') return CheckersConstants.opponentPiece;
      if (pieceStr == 'redKing') return CheckersConstants.opponentKing;
    }
    
    return CheckersConstants.emptySquare;
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    
    if (!gameStarted || !isMyTurn) {
      print('❌ Not your turn or game not started');
      return;
    }
    
    final tapPosition = info.eventPosition.widget;
    final boardPos = board.screenToBoard(tapPosition);
    
    if (boardPos == null) {
      print('❌ Tapped outside board');
      return;
    }
    
    print('📍 Tapped: $boardPos');
    
    // Check if selecting own piece
    final tappedPiece = pieces.where((p) {
      final pos = p.boardPosition;
      return pos.row == boardPos.row && pos.col == boardPos.col;
    }).firstOrNull;
    
    if (tappedPiece != null && _isMyPiece(tappedPiece.pieceType)) {
      print('✅ Selected own piece at $boardPos');
      _selectPiece(boardPos);
      return;
    }
    
    // Check if tapped on valid move square
    if (selectedPiece != null) {
      final validMove = validMoves.any((m) => 
        m.row == boardPos.row && m.col == boardPos.col
      );
      
      if (validMove) {
        print('✅ Valid move to $boardPos');
        _attemptMove(selectedPiece!, boardPos);
      } else {
        print('❌ Invalid move');
        board.clearHighlights();
        board.deselectSquare();
        selectedPiece = null;
        validMoves.clear();
      }
    }
  }

  bool _isMyPiece(int pieceType) {
    return pieceType == CheckersConstants.myPiece || 
           pieceType == CheckersConstants.myKing;
  }

  /// Request valid moves from server for selected piece
  void _selectPiece(Position pos) {
    print('🔍 Requesting valid moves for $pos');
    
    socketService.sendGameAction(
      roomId: roomId,
      action: 'select_piece',
      payload: {
        'userId': user.id,
        'gameType': 'checkers',
        'row': pos.row,
        'col': pos.col,
      },
    );
  }

  /// Attempt to make a move (client-side validation already done)
  void _attemptMove(Position from, Position to) {
    print('🎯 Attempting move from $from to $to');
    
    socketService.sendGameAction(
      roomId: roomId,
      action: 'make_move',
      payload: {
        'userId': user.id,
        'gameType': 'checkers',
        'from': {'row': from.row, 'col': from.col},
        'to': {'row': to.row, 'col': to.col},
      },
    );
  }

  // ====================================
  // SOCKET EVENT HANDLERS
  // ====================================

  /// Handle piece selected (valid moves returned from server)
  void handlePieceSelected(Map<String, dynamic> data) {
    print('🟢 Piece selected response received');
    
    final validMovesData = data['validMoves'] as List;
    final from = data['position'] as Map<String, dynamic>;
    
    selectedPiece = Position(from['row'] as int, from['col'] as int);
    validMoves.clear();
    
    for (var move in validMovesData) {
      validMoves.add(Position(
        move['row'] as int,
        move['col'] as int,
      ));
    }
    
    // Highlight valid moves on board
    board.highlightSquares(validMoves);
    board.selectSquare(selectedPiece!);
    
    onStatusUpdate('Selected piece - choose a move');
  }

  /// Handle move made (animate and update board)
  void handleMoveMade(Map<String, dynamic> data) {
    print('🏃 Move made event received');
    
    final from = data['from'] as Map<String, dynamic>;
    final to = data['to'] as Map<String, dynamic>;
    final captured = data['captured'] as List?;
    final promoted = data['promoted'] as bool?;
    
    final fromPos = Position(from['row'] as int, from['col'] as int);
    final toPos = Position(to['row'] as int, to['col'] as int);
    
    // Find and move the piece
    final movingPiece = pieces.where((p) {
      final pos = p.boardPosition;
      return pos.row == fromPos.row && pos.col == fromPos.col;
    }).firstOrNull;
    
    if (movingPiece != null) {
      // Create new piece at new position
      int newPieceType = movingPiece.pieceType;
      if (promoted == true) {
        newPieceType = newPieceType == CheckersConstants.myPiece 
          ? CheckersConstants.myKing 
          : CheckersConstants.opponentKing;
      }
      
      final newScreenPos = board.boardToScreen(toPos);
      final newPiece = CheckersPiece(
        pieceType: newPieceType,
        boardPosition: toPos,
        position: newScreenPos,
      );
      
      // Remove old piece and add new one
      movingPiece.removeFromParent();
      pieces.remove(movingPiece);
      pieces.add(newPiece);
      add(newPiece);
      
      // Handle captured pieces
      if (captured != null && captured.isNotEmpty) {
        for (var cap in captured) {
          final capPos = Position(cap['row'] as int, cap['col'] as int);
          _removePieceAt(capPos);
        }
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
    
    final currentTurn = data['currentTurn'] as String;
    isMyTurn = currentTurn == myColour;
    
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