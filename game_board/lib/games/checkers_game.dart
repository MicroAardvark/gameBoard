import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../components/checkers_board_component.dart';
import '../components/checkers_piece_component.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

class CheckersConstants {
  // Board dimensions
  static const int boardSize = 8;
  static const double squareSize = 48.0;  // Increased from 40.0
  static const double pieceSize = 36.0;   // Increased from 30.0
  static const double crownSize = 18.0;   // Increased from 15.0
  
  // Colours matching Microvark theme
  static const Color darkSquare = Color(0xFF000000); // Black
  static const Color lightSquare = Color(0xFFF5F5DC); // Beige/cream
  static const Color highlightColour = Color(0xFFFFA500);
  static const Color selectedColour = Color(0xFFFFD700);
  static const Color validMoveColour = Color(0xFF4169E1);
  static const Color playerPieceColour = Color(0xFFDC143C);
  static const Color aiPieceColour = Color(0xFF1C1C1C);
  static const Color kingBorderColour = Color(0xFFFFD700);
  
  // Game settings
  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  static const Duration aiThinkingDelay = Duration(milliseconds: 800);
  
  // Piece types
  static const int emptySquare = 0;
  static const int playerPiece = 1;
  static const int playerKing = 2;
  static const int aiPiece = 3;
  static const int aiKing = 4;
}

// ============================================================================
// DATA STRUCTURES
// ============================================================================

class Position {
  final int row;
  final int col;
  
  const Position(this.row, this.col);
  
  bool isValid() {
    return row >= 0 && row < CheckersConstants.boardSize && 
           col >= 0 && col < CheckersConstants.boardSize;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.row == row && other.col == col;
  }
  
  @override
  int get hashCode => row.hashCode ^ col.hashCode;
  
  @override
  String toString() => 'Position($row, $col)';
}

class CheckersMove {
  final Position from;
  final Position to;
  final List<Position> capturedPieces;
  final bool isCapture;
  final bool promotesToKing;
  
  CheckersMove({
    required this.from,
    required this.to,
    this.capturedPieces = const [],
    this.isCapture = false,
    this.promotesToKing = false,
  });
  
  @override
  String toString() => 'Move: $from -> $to${isCapture ? " (capture)" : ""}${promotesToKing ? " (promote)" : ""}';
}

// ============================================================================
// GAME STATE
// ============================================================================

class CheckersGameState {
  late List<List<int>> board;
  bool isPlayerTurn = true;
  Position? selectedPiece;
  List<CheckersMove> validMoves = [];
  List<CheckersMove> moveHistory = [];
  bool gameOver = false;
  String? winner;
  bool mustCapture = false;
  
  CheckersGameState() {
    _initializeBoard();
  }
  
  void _initializeBoard() {
    board = List.generate(
      CheckersConstants.boardSize,
      (row) => List.filled(CheckersConstants.boardSize, CheckersConstants.emptySquare),
    );
    
    // Place AI pieces (top 3 rows)
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = CheckersConstants.aiPiece;
        }
      }
    }
    
    // Place player pieces (bottom 3 rows)
    for (int row = 5; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = CheckersConstants.playerPiece;
        }
      }
    }
  }
  
  List<CheckersMove> getValidMovesForPiece(Position pos) {
    final piece = board[pos.row][pos.col];
    if (piece == CheckersConstants.emptySquare) return [];
    
    final isPlayer = piece == CheckersConstants.playerPiece || piece == CheckersConstants.playerKing;
    final isKing = piece == CheckersConstants.playerKing || piece == CheckersConstants.aiKing;
    
    List<CheckersMove> moves = [];
    List<CheckersMove> captures = [];
    
    // Determine movement directions
    List<List<int>> directions;
    if (isKing) {
      directions = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    } else {
      directions = isPlayer ? [[-1, -1], [-1, 1]] : [[1, -1], [1, 1]];
    }
    
    for (var dir in directions) {
      final newRow = pos.row + dir[0];
      final newCol = pos.col + dir[1];
      final newPos = Position(newRow, newCol);
      
      if (!newPos.isValid()) continue;
      
      final targetPiece = board[newRow][newCol];
      
      if (targetPiece == CheckersConstants.emptySquare) {
        moves.add(CheckersMove(
          from: pos,
          to: newPos,
          promotesToKing: _checkPromotion(newPos, isPlayer),
        ));
      } else if (_isOpponentPiece(piece, targetPiece)) {
        final jumpRow = newRow + dir[0];
        final jumpCol = newCol + dir[1];
        final jumpPos = Position(jumpRow, jumpCol);
        
        if (jumpPos.isValid() && board[jumpRow][jumpCol] == CheckersConstants.emptySquare) {
          captures.add(CheckersMove(
            from: pos,
            to: jumpPos,
            capturedPieces: [newPos],
            isCapture: true,
            promotesToKing: _checkPromotion(jumpPos, isPlayer),
          ));
        }
      }
    }
    
    return captures.isNotEmpty ? captures : moves;
  }
  
  List<CheckersMove> getAllValidMoves(bool forPlayer) {
    List<CheckersMove> allMoves = [];
    List<CheckersMove> allCaptures = [];
    
    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final piece = board[row][col];
        final isPlayerPiece = piece == CheckersConstants.playerPiece || piece == CheckersConstants.playerKing;
        
        if (forPlayer && isPlayerPiece || !forPlayer && !isPlayerPiece && piece != CheckersConstants.emptySquare) {
          final moves = getValidMovesForPiece(Position(row, col));
          for (var move in moves) {
            if (move.isCapture) {
              allCaptures.add(move);
            } else {
              allMoves.add(move);
            }
          }
        }
      }
    }
    
    if (allCaptures.isNotEmpty) {
      mustCapture = true;
      return allCaptures;
    }
    
    mustCapture = false;
    return allMoves;
  }
  
  bool makeMove(CheckersMove move) {
    final piece = board[move.from.row][move.from.col];
    
    board[move.to.row][move.to.col] = piece;
    board[move.from.row][move.from.col] = CheckersConstants.emptySquare;
    
    for (var capturedPos in move.capturedPieces) {
      board[capturedPos.row][capturedPos.col] = CheckersConstants.emptySquare;
    }
    
    if (move.promotesToKing) {
      if (piece == CheckersConstants.playerPiece) {
        board[move.to.row][move.to.col] = CheckersConstants.playerKing;
      } else if (piece == CheckersConstants.aiPiece) {
        board[move.to.row][move.to.col] = CheckersConstants.aiKing;
      }
    }
    
    moveHistory.add(move);
    selectedPiece = null;
    validMoves = [];
    
    if (move.isCapture && !move.promotesToKing) {
      final furtherCaptures = getValidMovesForPiece(move.to).where((m) => m.isCapture).toList();
      if (furtherCaptures.isNotEmpty) {
        return false;
      }
    }
    
    isPlayerTurn = !isPlayerTurn;
    _checkGameOver();
    return true;
  }
  
  bool _checkPromotion(Position pos, bool isPlayer) {
    if (isPlayer && pos.row == 0) return true;
    if (!isPlayer && pos.row == CheckersConstants.boardSize - 1) return true;
    return false;
  }
  
  bool _isOpponentPiece(int piece1, int piece2) {
    final isPlayer1 = piece1 == CheckersConstants.playerPiece || piece1 == CheckersConstants.playerKing;
    final isPlayer2 = piece2 == CheckersConstants.playerPiece || piece2 == CheckersConstants.playerKing;
    
    if (piece2 == CheckersConstants.emptySquare) return false;
    return isPlayer1 != isPlayer2;
  }
  
  void _checkGameOver() {
    final playerMoves = getAllValidMoves(true);
    final aiMoves = getAllValidMoves(false);
    
    if (playerMoves.isEmpty) {
      gameOver = true;
      winner = 'AI';
    } else if (aiMoves.isEmpty) {
      gameOver = true;
      winner = 'Player';
    }
  }
  
  CheckersGameState copy() {
    final newState = CheckersGameState();
    newState.board = board.map((row) => List<int>.from(row)).toList();
    newState.isPlayerTurn = isPlayerTurn;
    newState.selectedPiece = selectedPiece;
    newState.validMoves = List.from(validMoves);
    newState.moveHistory = List.from(moveHistory);
    newState.gameOver = gameOver;
    newState.winner = winner;
    newState.mustCapture = mustCapture;
    return newState;
  }
  
  int countPieces(bool forPlayer) {
    int count = 0;
    for (var row in board) {
      for (var piece in row) {
        if (forPlayer) {
          if (piece == CheckersConstants.playerPiece || piece == CheckersConstants.playerKing) count++;
        } else {
          if (piece == CheckersConstants.aiPiece || piece == CheckersConstants.aiKing) count++;
        }
      }
    }
    return count;
  }
}

// ============================================================================
// AI OPPONENT
// ============================================================================

class CheckersAI {
  final Random _random = Random();
  int difficultyDepth;
  
  CheckersAI({this.difficultyDepth = 4});
  
  CheckersMove? getBestMove(CheckersGameState state) {
    final validMoves = state.getAllValidMoves(false);
    if (validMoves.isEmpty) return null;
    
    // Easy mode: random with capture preference
    if (difficultyDepth == 2) {
      final captures = validMoves.where((m) => m.isCapture).toList();
      if (captures.isNotEmpty && _random.nextDouble() > 0.3) {
        return captures[_random.nextInt(captures.length)];
      }
      return validMoves[_random.nextInt(validMoves.length)];
    }
    
    // Minimax for medium/hard
    CheckersMove? bestMove;
    double bestScore = double.negativeInfinity;
    
    for (var move in validMoves) {
      final newState = state.copy();
      newState.makeMove(move);
      final score = _minimax(newState, difficultyDepth - 1, double.negativeInfinity, double.infinity, false);
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    
    return bestMove;
  }
  
  double _minimax(CheckersGameState state, int depth, double alpha, double beta, bool maximizingPlayer) {
    if (depth == 0 || state.gameOver) {
      return _evaluateBoard(state);
    }
    
    final validMoves = state.getAllValidMoves(!maximizingPlayer);
    
    if (validMoves.isEmpty) {
      return maximizingPlayer ? -1000.0 : 1000.0;
    }
    
    if (maximizingPlayer) {
      double maxEval = double.negativeInfinity;
      for (var move in validMoves) {
        final newState = state.copy();
        newState.makeMove(move);
        final eval = _minimax(newState, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      double minEval = double.infinity;
      for (var move in validMoves) {
        final newState = state.copy();
        newState.makeMove(move);
        final eval = _minimax(newState, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }
  
  double _evaluateBoard(CheckersGameState state) {
    if (state.gameOver) {
      if (state.winner == 'AI') return 1000.0;
      if (state.winner == 'Player') return -1000.0;
    }
    
    double score = 0.0;
    
    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final piece = state.board[row][col];
        
        switch (piece) {
          case CheckersConstants.playerPiece:
            score -= 3.0;
            score -= (7 - row) * 0.5;
            break;
          case CheckersConstants.playerKing:
            score -= 5.0;
            break;
          case CheckersConstants.aiPiece:
            score += 3.0;
            score += row * 0.5;
            break;
          case CheckersConstants.aiKing:
            score += 5.0;
            break;
        }
      }
    }
    
    final aiPieces = state.countPieces(false);
    final playerPieces = state.countPieces(true);
    score += (aiPieces - playerPieces) * 2.0;
    
    final aiMoves = state.getAllValidMoves(false).length;
    final playerMoves = state.getAllValidMoves(true).length;
    score += (aiMoves - playerMoves) * 0.1;
    
    return score;
  }
  
  void setDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyDepth = 2;
        break;
      case 'medium':
        difficultyDepth = 4;
        break;
      case 'hard':
        difficultyDepth = 6;
        break;
      default:
        difficultyDepth = 4;
    }
  }
}

// ============================================================================
// MAIN FLAME GAME
// ============================================================================

class CheckersGame extends FlameGame with TapDetector {
  late CheckersGameState gameState;
  CheckersBoard? board;
  late CheckersAI ai;
  
  final List<CheckersPiece> pieces = [];
  bool isProcessing = false;
  
  Function(String)? onGameOver;
  Function(bool)? onTurnChanged;
  Function(String)? onStatusUpdate;
  
  CheckersGame({
    this.onGameOver,
    this.onTurnChanged,
    this.onStatusUpdate,
  });
  
  @override
  Color backgroundColor() => const Color(0xFF0A1628);
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    gameState = CheckersGameState();
    ai = CheckersAI(difficultyDepth: 4);
    
    board = CheckersBoard();
    add(board!);
    
    // Wait for next frame to ensure board is positioned
    await Future.delayed(Duration.zero);
    board!.position = Vector2(size.x / 2, size.y / 2);
    _createPieces();
    
    onTurnChanged?.call(gameState.isPlayerTurn);
    _updateStatus();
  }
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    // Reposition board and pieces when game size changes
    if (board != null) {
      board!.position = Vector2(size.x / 2, size.y / 2);
      _createPieces();
    }
  }
  
  void _createPieces() {
    if (board == null) return;
    
    for (var piece in pieces) {
      piece.removeFromParent();
    }
    pieces.clear();
    
    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final pieceType = gameState.board[row][col];
        
        if (pieceType != CheckersConstants.emptySquare) {
          final boardPos = Position(row, col);
          final screenPos = board!.boardToScreen(boardPos);
          
          final piece = CheckersPiece(
            pieceType: pieceType,
            boardPosition: boardPos,
            position: screenPos,
          );
          
          pieces.add(piece);
          add(piece);
        }
      }
    }
  }
  
  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    
    if (board == null || isProcessing || gameState.gameOver || !gameState.isPlayerTurn) {
      return;
    }
    
    final boardPos = board!.screenToBoard(info.eventPosition.global);
    if (boardPos == null) return;
    
    _handleTap(boardPos);
  }
  
  void _handleTap(Position tappedPos) {
    final tappedPiece = gameState.board[tappedPos.row][tappedPos.col];
    final isPlayerPiece = tappedPiece == CheckersConstants.playerPiece || 
                         tappedPiece == CheckersConstants.playerKing;
    
    if (isPlayerPiece) {
      _selectPiece(tappedPos);
    } else if (gameState.selectedPiece != null) {
      _attemptMove(tappedPos);
    }
  }
  
  void _selectPiece(Position pos) {
    if (board == null) return;
    
    gameState.selectedPiece = pos;
    gameState.validMoves = gameState.getValidMovesForPiece(pos);
    
    board!.selectSquare(pos);
    
    for (var piece in pieces) {
      piece.isSelected = piece.boardPosition == pos;
    }
    
    final validTargets = gameState.validMoves.map((m) => m.to).toList();
    board!.highlightSquares(validTargets);
    
    _updateStatus();
  }
  
  void _attemptMove(Position targetPos) {
    if (gameState.selectedPiece == null) return;
    
    final move = gameState.validMoves.firstWhere(
      (m) => m.to == targetPos,
      orElse: () => CheckersMove(from: Position(-1, -1), to: Position(-1, -1)),
    );
    
    if (move.from.row == -1) {
      _deselectPiece();
      return;
    }
    
    _executeMove(move);
  }
  
  Future<void> _executeMove(CheckersMove move) async {
    if (board == null) return;
    
    isProcessing = true;
    
    final movingPiece = pieces.firstWhere((p) => p.boardPosition == move.from);
    final targetScreenPos = board!.boardToScreen(move.to);
    movingPiece.animateTo(targetScreenPos);
    
    await Future.delayed(CheckersConstants.moveAnimationDuration);
    
    final switchedTurn = gameState.makeMove(move);
    _createPieces();
    
    board!.deselectSquare();
    board!.clearHighlights();
    
    if (gameState.gameOver) {
      onGameOver?.call(gameState.winner ?? 'Draw');
      _updateStatus();
      isProcessing = false;
      return;
    }
    
    if (switchedTurn) {
      onTurnChanged?.call(gameState.isPlayerTurn);
    }
    
    _updateStatus();
    isProcessing = false;
    
    if (!gameState.isPlayerTurn) {
      _makeAIMove();
    }
  }
  
  Future<void> _makeAIMove() async {
    isProcessing = true;
    
    await Future.delayed(CheckersConstants.aiThinkingDelay);
    
    final aiMove = ai.getBestMove(gameState);
    
    if (aiMove != null) {
      await _executeMove(aiMove);
    }
    
    isProcessing = false;
  }
  
  void _deselectPiece() {
    if (board == null) return;
    
    gameState.selectedPiece = null;
    gameState.validMoves = [];
    
    board!.deselectSquare();
    board!.clearHighlights();
    
    for (var piece in pieces) {
      piece.isSelected = false;
    }
    
    _updateStatus();
  }
  
  void _updateStatus() {
    if (gameState.gameOver) {
      onStatusUpdate?.call('Game Over! ${gameState.winner} wins!');
      return;
    }
    
    if (gameState.isPlayerTurn) {
      if (gameState.mustCapture) {
        onStatusUpdate?.call('Your turn - You must capture!');
      } else if (gameState.selectedPiece != null) {
        onStatusUpdate?.call('Selected - Choose where to move');
      } else {
        onStatusUpdate?.call('Your turn - Select a piece');
      }
    } else {
      onStatusUpdate?.call('AI is thinking...');
    }
  }
  
  void resetGame() {
    if (board == null) return;
    
    gameState = CheckersGameState();
    isProcessing = false;
    
    board!.deselectSquare();
    board!.clearHighlights();
    
    _createPieces();
    
    onTurnChanged?.call(gameState.isPlayerTurn);
    _updateStatus();
  }
  
  void setDifficulty(String difficulty) {
    ai.setDifficulty(difficulty);
  }
}