import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../components/checkers_board_component.dart';
import '../components/checkers_piece_component.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

/// Centralised configuration for the Checkers game.
///
/// Keeping all magic numbers here means layout, timing, and colour changes
/// only need to happen in one place.
class CheckersConstants {
  static const int boardSize    = 8;
  static const double squareSize = 48.0;
  static const double pieceSize  = 36.0;
  static const double crownSize  = 18.0;

  // Board colours follow the Microvark navy theme.
  static const Color darkSquare      = Color(0xFF000000);
  static const Color lightSquare     = Color(0xFFF5F5DC);
  static const Color highlightColour = Color(0xFFFFA500);
  static const Color selectedColour  = Color(0xFFFFD700);
  static const Color validMoveColour = Color(0xFF4169E1);
  static const Color playerPieceColour = Color(0xFFDC143C);
  static const Color aiPieceColour     = Color(0xFF1C1C1C);
  static const Color kingBorderColour  = Color(0xFFFFD700);

  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  static const Duration aiThinkingDelay       = Duration(milliseconds: 800);

  // Piece type integers used throughout board state and rendering.
  static const int emptySquare = 0;
  static const int playerPiece = 1;
  static const int playerKing  = 2;
  static const int aiPiece     = 3;
  static const int aiKing      = 4;
}

// ─── Data structures ──────────────────────────────────────────────────────────

/// A board coordinate validated against the 8×8 grid.
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  bool isValid() =>
      row >= 0 && row < CheckersConstants.boardSize &&
      col >= 0 && col < CheckersConstants.boardSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'Position($row, $col)';
}

/// Describes a single move, including any pieces captured along the way
/// and whether the moving piece is promoted to king on arrival.
class CheckersMove {
  final Position from;
  final Position to;
  final List<Position> capturedPieces;
  final bool isCapture;
  final bool promotesToKing;

  CheckersMove({
    required this.from,
    required this.to,
    this.capturedPieces  = const [],
    this.isCapture       = false,
    this.promotesToKing  = false,
  });

  @override
  String toString() =>
      'Move: $from -> $to'
      '${isCapture ? " (capture)" : ""}'
      '${promotesToKing ? " (promote)" : ""}';
}

// ─── Game state ───────────────────────────────────────────────────────────────

/// Holds the complete, serialisable state of a Checkers game.
///
/// Separated from [CheckersGame] so the AI can clone and mutate state freely
/// during tree search without touching any Flame components.
class CheckersGameState {
  late List<List<int>> board;
  bool isPlayerTurn   = true;
  Position? selectedPiece;
  List<CheckersMove> validMoves   = [];
  List<CheckersMove> moveHistory  = [];
  bool gameOver    = false;
  String? winner;

  /// True when the rules require the current player to capture rather than
  /// making a plain move. Surfaced to the UI for status messages.
  bool mustCapture = false;

  CheckersGameState() {
    _initializeBoard();
  }

  void _initializeBoard() {
    board = List.generate(
      CheckersConstants.boardSize,
      (row) => List.filled(CheckersConstants.boardSize, CheckersConstants.emptySquare),
    );

    // AI pieces occupy the top three rows; player pieces the bottom three.
    // Only dark squares (where row + col is odd) are used in Checkers.
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        if ((row + col) % 2 == 1) board[row][col] = CheckersConstants.aiPiece;
      }
    }

    for (int row = 5; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        if ((row + col) % 2 == 1) board[row][col] = CheckersConstants.playerPiece;
      }
    }
  }

  /// Returns all legal moves for the piece at [pos].
  ///
  /// If any captures are available they are returned exclusively — plain moves
  /// are only returned when no capture exists, enforcing the mandatory-capture
  /// rule.
  List<CheckersMove> getValidMovesForPiece(Position pos) {
    final piece = board[pos.row][pos.col];
    if (piece == CheckersConstants.emptySquare) return [];

    final isPlayer = piece == CheckersConstants.playerPiece ||
        piece == CheckersConstants.playerKing;
    final isKing = piece == CheckersConstants.playerKing ||
        piece == CheckersConstants.aiKing;

    List<CheckersMove> moves    = [];
    List<CheckersMove> captures = [];

    // Kings move in all four diagonal directions; regular pieces move forward only.
    final directions = isKing
        ? [[-1, -1], [-1, 1], [1, -1], [1, 1]]
        : (isPlayer ? [[-1, -1], [-1, 1]] : [[1, -1], [1, 1]]);

    for (var dir in directions) {
      final newPos = Position(pos.row + dir[0], pos.col + dir[1]);
      if (!newPos.isValid()) continue;

      final targetPiece = board[newPos.row][newPos.col];

      if (targetPiece == CheckersConstants.emptySquare) {
        moves.add(CheckersMove(
          from: pos,
          to: newPos,
          promotesToKing: _checkPromotion(newPos, isPlayer),
        ));
      } else if (_isOpponentPiece(piece, targetPiece)) {
        // Check whether the square beyond the opponent is empty for a jump.
        final jumpPos = Position(newPos.row + dir[0], newPos.col + dir[1]);
        if (jumpPos.isValid() && board[jumpPos.row][jumpPos.col] == CheckersConstants.emptySquare) {
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

  /// A piece is promoted when it reaches the opponent's back row.
  bool _checkPromotion(Position pos, bool isPlayer) =>
      isPlayer ? pos.row == 0 : pos.row == CheckersConstants.boardSize - 1;

  bool _isOpponentPiece(int piece1, int piece2) {
    final isPlayer1 = piece1 == CheckersConstants.playerPiece ||
        piece1 == CheckersConstants.playerKing;
    final isPlayer2 = piece2 == CheckersConstants.playerPiece ||
        piece2 == CheckersConstants.playerKing;
    return isPlayer1 != isPlayer2;
  }

  /// Aggregates legal moves for all pieces belonging to [forPlayer].
  ///
  /// Sets [mustCapture] and returns only captures when any exist, enforcing
  /// the mandatory-capture rule across the full set of pieces.
  List<CheckersMove> getAllValidMoves(bool forPlayer) {
    List<CheckersMove> allMoves    = [];
    List<CheckersMove> allCaptures = [];

    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final piece = board[row][col];
        final isPlayerPiece = piece == CheckersConstants.playerPiece ||
            piece == CheckersConstants.playerKing;

        final belongsToSide = forPlayer
            ? isPlayerPiece
            : !isPlayerPiece && piece != CheckersConstants.emptySquare;

        if (!belongsToSide) continue;

        for (var move in getValidMovesForPiece(Position(row, col))) {
          if (move.isCapture) {
            allCaptures.add(move);
          } else {
            allMoves.add(move);
          }
        }
      }
    }

    mustCapture = allCaptures.isNotEmpty;
    return mustCapture ? allCaptures : allMoves;
  }

  /// Applies [move] to the board: moves the piece, removes captured pieces,
  /// and promotes to king if [move.promotesToKing] is set.
  bool makeMove(CheckersMove move) {
    final piece = board[move.from.row][move.from.col];

    board[move.to.row][move.to.col]     = piece;
    board[move.from.row][move.from.col] = CheckersConstants.emptySquare;

    for (var captured in move.capturedPieces) {
      board[captured.row][captured.col] = CheckersConstants.emptySquare;
    }

    if (move.promotesToKing) {
      final isPlayer = piece == CheckersConstants.playerPiece ||
          piece == CheckersConstants.playerKing;
      board[move.to.row][move.to.col] =
          isPlayer ? CheckersConstants.playerKing : CheckersConstants.aiKing;
    }

    moveHistory.add(move);
    return true;
  }

  /// Counts all pieces on the board belonging to [forPlayer].
  int countPieces(bool forPlayer) {
    int count = 0;
    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final piece = board[row][col];
        final isPlayerPiece = piece == CheckersConstants.playerPiece ||
            piece == CheckersConstants.playerKing;
        final belongsToSide = forPlayer
            ? isPlayerPiece
            : !isPlayerPiece && piece != CheckersConstants.emptySquare;
        if (belongsToSide) count++;
      }
    }
    return count;
  }

  /// Sets [gameOver] and [winner] if either side has no pieces or no legal moves.
  void checkGameOver() {
    final playerPieces = countPieces(true);
    final aiPieces     = countPieces(false);

    if (playerPieces == 0) {
      gameOver = true;
      winner   = 'AI';
    } else if (aiPieces == 0) {
      gameOver = true;
      winner   = 'Player';
    } else if (getAllValidMoves(isPlayerTurn).isEmpty) {
      // The side whose turn it is has no moves — they lose.
      gameOver = true;
      winner   = isPlayerTurn ? 'AI' : 'Player';
    }
  }

  /// Returns a deep copy of this state safe for AI tree search mutation.
  CheckersGameState copy() {
    final s = CheckersGameState();
    s.board        = List.generate(CheckersConstants.boardSize, (r) => List.from(board[r]));
    s.isPlayerTurn = isPlayerTurn;
    s.selectedPiece = selectedPiece;
    s.validMoves   = List.from(validMoves);
    s.moveHistory  = List.from(moveHistory);
    s.gameOver     = gameOver;
    s.winner       = winner;
    s.mustCapture  = mustCapture;
    return s;
  }
}

// ─── AI ───────────────────────────────────────────────────────────────────────

/// Minimax AI with alpha-beta pruning.
///
/// [difficultyDepth] controls look-ahead depth: 2 = easy, 4 = medium, 6 = hard.
/// Higher depths increase thinking time exponentially, so 6 is the practical
/// ceiling before moves become noticeably slow on mobile.
class CheckersAI {
  int difficultyDepth;

  CheckersAI({this.difficultyDepth = 4});

  /// Returns the best move for the AI side, or null if no moves are available.
  CheckersMove? getBestMove(CheckersGameState state) {
    final validMoves = state.getAllValidMoves(false);
    if (validMoves.isEmpty) return null;

    CheckersMove? bestMove;
    double bestScore = double.negativeInfinity;

    for (var move in validMoves) {
      final child = state.copy()..makeMove(move);
      final score = _minimax(child, difficultyDepth - 1, double.negativeInfinity, double.infinity, false);
      if (score > bestScore) {
        bestScore = score;
        bestMove  = move;
      }
    }

    return bestMove;
  }

  /// Recursive minimax with alpha-beta pruning.
  ///
  /// [maximizingPlayer] is true when evaluating AI moves (maximising score)
  /// and false when evaluating player moves (minimising score). Alpha-beta
  /// cuts branches that cannot affect the final decision, reducing the
  /// effective search space significantly at higher depths.
  double _minimax(CheckersGameState state, int depth, double alpha, double beta, bool maximizingPlayer) {
    if (depth == 0 || state.gameOver) return _evaluateBoard(state);

    final moves = state.getAllValidMoves(!maximizingPlayer);
    if (moves.isEmpty) return maximizingPlayer ? -1000.0 : 1000.0;

    if (maximizingPlayer) {
      double maxEval = double.negativeInfinity;
      for (var move in moves) {
        final child = state.copy()..makeMove(move);
        final eval  = _minimax(child, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha   = max(alpha, eval);
        if (beta <= alpha) break; // Beta cut-off.
      }
      return maxEval;
    } else {
      double minEval = double.infinity;
      for (var move in moves) {
        final child = state.copy()..makeMove(move);
        final eval  = _minimax(child, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta    = min(beta, eval);
        if (beta <= alpha) break; // Alpha cut-off.
      }
      return minEval;
    }
  }

  /// Heuristic board evaluation from the AI's perspective (positive = AI advantage).
  ///
  /// Factors weighted by importance:
  /// - Kings are worth more than regular pieces.
  /// - Positional advancement rewards pieces closer to promotion.
  /// - Piece count difference and move count difference provide strategic pressure.
  double _evaluateBoard(CheckersGameState state) {
    if (state.gameOver) {
      if (state.winner == 'AI')     return  1000.0;
      if (state.winner == 'Player') return -1000.0;
    }

    double score = 0.0;

    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        switch (state.board[row][col]) {
          case CheckersConstants.playerPiece:
            score -= 3.0 + (7 - row) * 0.5; // Penalise advancement toward AI back row.
            break;
          case CheckersConstants.playerKing:
            score -= 5.0;
            break;
          case CheckersConstants.aiPiece:
            score += 3.0 + row * 0.5; // Reward advancement toward player back row.
            break;
          case CheckersConstants.aiKing:
            score += 5.0;
            break;
        }
      }
    }

    // Piece count advantage.
    score += (state.countPieces(false) - state.countPieces(true)) * 2.0;

    // Mobility advantage — more legal moves gives more strategic flexibility.
    score += (state.getAllValidMoves(false).length - state.getAllValidMoves(true).length) * 0.1;

    return score;
  }

  /// Adjusts [difficultyDepth] from a human-readable difficulty label.
  void setDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':   difficultyDepth = 2; break;
      case 'medium': difficultyDepth = 4; break;
      case 'hard':   difficultyDepth = 6; break;
      default:       difficultyDepth = 4;
    }
  }
}

// ─── Main Flame game ──────────────────────────────────────────────────────────

/// The top-level Flame game that ties together [CheckersGameState], [CheckersAI],
/// and the visual board/piece components.
///
/// Callbacks allow the host Flutter widget to react to game events without
/// needing direct access to Flame internals:
/// - [onGameOver]     — called with the winner string when the game ends.
/// - [onTurnChanged]  — called with `true` when the player's turn begins.
/// - [onStatusUpdate] — called with a human-readable status message each turn.
class CheckersGame extends FlameGame with TapDetector {
  late CheckersGameState gameState;
  CheckersBoard? board;
  late CheckersAI ai;

  final List<CheckersPiece> pieces = [];

  /// Guards against processing a second tap or AI move while one is in flight.
  bool isProcessing = false;

  final Function(String)? onGameOver;
  final Function(bool)?   onTurnChanged;
  final Function(String)? onStatusUpdate;

  CheckersGame({this.onGameOver, this.onTurnChanged, this.onStatusUpdate});

  @override
  Color backgroundColor() => const Color(0xFF0A1628);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    gameState = CheckersGameState();
    ai        = CheckersAI(difficultyDepth: 4);

    board = CheckersBoard();
    add(board!);

    // Brief delay ensures [size] is populated before we centre the board.
    await Future.delayed(const Duration(milliseconds: 100));
    board!.position = Vector2(size.x / 2, size.y / 2);

    _createPieces();
    onTurnChanged?.call(gameState.isPlayerTurn);
    _updateStatus();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    // Recentre the board and rebuild piece positions whenever the canvas resizes
    // (e.g. device rotation).
    if (board != null) {
      board!.position = Vector2(size.x / 2, size.y / 2);
      _createPieces();
    }
  }

  /// Removes all existing piece components and recreates them from [gameState.board].
  ///
  /// Called after every move and on resize to keep visuals in sync with state.
  void _createPieces() {
    if (board == null) return;

    for (var piece in pieces) piece.removeFromParent();
    pieces.clear();

    for (int row = 0; row < CheckersConstants.boardSize; row++) {
      for (int col = 0; col < CheckersConstants.boardSize; col++) {
        final pieceType = gameState.board[row][col];
        if (pieceType == CheckersConstants.emptySquare) continue;

        final boardPos = Position(row, col);
        final piece = CheckersPiece(
          pieceType: pieceType,
          boardPosition: boardPos,
          position: board!.boardToScreen(boardPos),
        );
        pieces.add(piece);
        add(piece);
      }
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);

    // Ignore taps during AI turns, animations, or after game over.
    if (board == null || isProcessing || gameState.gameOver || !gameState.isPlayerTurn) {
      return;
    }

    final boardPos = board!.screenToBoard(info.eventPosition.widget);
    if (boardPos != null) _handleTap(boardPos);
  }

  /// Routes a tap to either piece selection or move attempt depending on
  /// whether the tapped square contains a player piece.
  void _handleTap(Position tappedPos) {
    final tappedPiece    = gameState.board[tappedPos.row][tappedPos.col];
    final isPlayerPiece  = tappedPiece == CheckersConstants.playerPiece ||
                           tappedPiece == CheckersConstants.playerKing;

    if (isPlayerPiece) {
      _selectPiece(tappedPos);
    } else if (gameState.selectedPiece != null) {
      _attemptMove(tappedPos);
    }
  }

  /// Selects [pos] as the active piece and highlights its legal destinations.
  void _selectPiece(Position pos) {
    if (board == null) return;

    gameState.selectedPiece = pos;
    gameState.validMoves    = gameState.getValidMovesForPiece(pos);

    board!.selectSquare(pos);
    board!.highlightSquares(gameState.validMoves.map((m) => m.to).toList());

    for (var piece in pieces) {
      piece.isSelected = piece.boardPosition == pos;
    }

    _updateStatus();
  }

  /// Attempts to move the selected piece to [pos].
  ///
  /// If [pos] is not a valid destination, the selection is cleared so the
  /// player can start again without the UI locking up.
  void _attemptMove(Position pos) {
    if (gameState.selectedPiece == null) return;

    final validMove = gameState.validMoves.firstWhere(
      (m) => m.to == pos,
      orElse: () => CheckersMove(from: Position(-1, -1), to: Position(-1, -1)),
    );

    if (validMove.from.row == -1) {
      // Tapped a non-destination square — clear selection.
      board!.deselectSquare();
      board!.clearHighlights();
      gameState.selectedPiece = null;
      _updateStatus();
      return;
    }

    _makeMove(validMove);
  }

  /// Animates [move], updates game state, then triggers the AI turn if needed.
  Future<void> _makeMove(CheckersMove move) async {
    if (board == null) return;

    isProcessing = true;

    // Remove captured pieces from the visual layer before animating the move.
    for (var capturedPos in move.capturedPieces) {
      final captured = pieces.firstWhere((p) => p.boardPosition == capturedPos);
      captured.removeFromParent();
      pieces.remove(captured);
    }

    final movingPiece = pieces.firstWhere((p) => p.boardPosition == move.from);
    movingPiece.animateTo(board!.boardToScreen(move.to));

    await Future.delayed(CheckersConstants.moveAnimationDuration);

    gameState.makeMove(move);
    gameState.checkGameOver();

    board!.deselectSquare();
    board!.clearHighlights();
    gameState.selectedPiece = null;

    // Rebuild all pieces to reflect promotion and any multi-capture changes.
    _createPieces();

    if (gameState.gameOver) {
      _updateStatus();
      onGameOver?.call(gameState.winner!);
      isProcessing = false;
      return;
    }

    gameState.isPlayerTurn = !gameState.isPlayerTurn;
    onTurnChanged?.call(gameState.isPlayerTurn);

    if (!gameState.isPlayerTurn) {
      _updateStatus();
      await _makeAIMove();
    } else {
      _updateStatus();
    }

    isProcessing = false;
  }

  /// Asks the AI for its best move, applies it, and handles the edge case
  /// where the AI has no legal moves (immediate player win).
  Future<void> _makeAIMove() async {
    isProcessing = true;

    await Future.delayed(CheckersConstants.aiThinkingDelay);

    final aiMove = ai.getBestMove(gameState);
    if (aiMove == null) {
      gameState.gameOver = true;
      gameState.winner   = 'Player';
      _updateStatus();
      onGameOver?.call('Player');
      isProcessing = false;
      return;
    }

    await _makeMove(aiMove);
  }

  /// Computes and emits the appropriate status string for the current game state.
  void _updateStatus() {
    final String message;

    if (gameState.gameOver) {
      message = 'Game Over! ${gameState.winner} wins!';
    } else if (!gameState.isPlayerTurn) {
      message = 'AI is thinking...';
    } else if (gameState.selectedPiece != null) {
      message = gameState.mustCapture ? 'You must capture!' : 'Select where to move';
    } else {
      message = gameState.mustCapture
          ? 'Your turn — you must capture!'
          : 'Your turn — select a piece';
    }

    onStatusUpdate?.call(message);
  }

  /// Resets all state and rebuilds the board for a fresh game.
  void resetGame() {
    gameState    = CheckersGameState();
    isProcessing = false;
    board?.deselectSquare();
    board?.clearHighlights();
    _createPieces();
    _updateStatus();
  }

  void setDifficulty(String difficulty) => ai.setDifficulty(difficulty);
}