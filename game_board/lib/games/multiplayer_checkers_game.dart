// lib/games/multiplayer_checkers_game.dart
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../components/checkers_board_component.dart';
import '../components/checkers_piece_component.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import 'checkers_game.dart' show Position;

// ─── Constants ────────────────────────────────────────────────────────────────

/// Visual and game constants for the multiplayer Checkers board.
///
/// Pieces are identified by their absolute colour (red/black) rather than
/// player/opponent. This keeps the server protocol simple and means both
/// players always see the same canonical piece type regardless of perspective.
class CheckersConstants {
  static const int boardSize = 8;
  static const double squareSize = 48.0;
  static const double pieceSize  = 36.0;
  static const double crownSize  = 18.0;

  static const Color darkSquare       = Color(0xFF000000);
  static const Color lightSquare      = Color(0xFFF5F5DC);
  static const Color selectedColour   = Color(0xFFFFD700);
  static const Color validMoveColour  = Color(0xFF4169E1);
  static const Color redPieceColour   = Color(0xFFDC143C);
  static const Color blackPieceColour = Color(0xFF1C1C1C);
  static const Color kingBorderColour = Color(0xFFFFD700);

  static const Duration moveAnimationDuration = Duration(milliseconds: 300);

  // Integer piece descriptors used in board state arrays.
  static const int emptySquare = 0;
  static const int redPiece    = 1;
  static const int redKing     = 2;
  static const int blackPiece  = 3;
  static const int blackKing   = 4;
}

// ─── Game ─────────────────────────────────────────────────────────────────────

/// Server-authoritative multiplayer Checkers game.
///
/// ## Perspective system
/// The server always stores board positions in a single canonical orientation
/// (red pieces at rows 5-7, black at rows 0-2). Player 1 (red) sees this
/// directly. Player 2 (black) receives a 180° rotated view via [_toDisplay] so
/// their own pieces always appear at the bottom — the natural Checkers
/// convention.
///
/// All tap coordinates are converted to server coordinates via [_toServer]
/// before being sent, and all incoming server positions are converted to display
/// coordinates before being passed to [CheckersBoard].
///
/// Callbacks allow the host Flutter widget to react to events:
/// - [onStatusUpdate] — human-readable status string for every state change.
/// - [onGameOver]     — called with the result string when the game ends.
/// - [onTurnChanged]  — called with `true` when it becomes this player's turn.
class MultiplayerCheckersGame extends FlameGame with TapDetector {
  final User user;
  final String roomId;
  final SocketService socketService;
  final Function(String) onStatusUpdate;
  final Function(String) onGameOver;
  final Function(bool) onTurnChanged;

  CheckersBoard? board;

  /// This player's colour as assigned by the server: `'red'` or `'black'`.
  String myColour = '';

  /// True for the black player (Player 2), whose board is rotated 180°
  /// so that black pieces appear at the bottom of the screen.
  bool shouldRotateBoard = false;

  /// Valid move destinations for the selected piece, stored in server
  /// coordinates. Transformed to display coordinates before highlighting.
  List<Position> validMoves = [];

  /// Currently selected piece in server coordinates, or null.
  Position? selectedPiece;

  bool isMyTurn    = false;
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

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    super.onLoad();

    board = CheckersBoard();
    await add(board!);

    // A brief delay ensures [size] is populated before centring the board.
    await Future.delayed(const Duration(milliseconds: 100));
    board!.position = Vector2(size.x / 2, size.y / 2);
  }

  // ─── Server sync ───────────────────────────────────────────────────────────

  /// Rebuilds the visual board from a full snapshot sent by the server.
  ///
  /// Called on initial game load and after reconnection. Sets [myColour] and
  /// [shouldRotateBoard], clears any existing pieces, then re-creates them all
  /// in the correct display positions.
  void syncBoardFromServer(Map<String, dynamic> data) {
    final boardState    = data['board'] as List;
    final playerColours = data['playerColours'] as Map<String, dynamic>;

    myColour          = playerColours[user.id] ?? 'red';
    shouldRotateBoard = (myColour == 'black');

    for (var piece in pieces) piece.removeFromParent();
    pieces.clear();

    for (int row = 0; row < 8; row++) {
      final rowData = boardState[row] as List;
      for (int col = 0; col < 8; col++) {
        final pieceData = rowData[col];
        if (pieceData == null) continue;

        final pieceType = _mapServerPieceToLocal(pieceData);
        if (pieceType == CheckersConstants.emptySquare) continue;

        final displayPos = _toDisplay(Position(row, col));
        final screenPos  = board!.boardToScreen(displayPos);

        // boardPosition stores server coordinates so socket events can match.
        final piece = CheckersPiece(
          pieceType:     pieceType,
          boardPosition: Position(row, col),
          position:      screenPos,
        );
        pieces.add(piece);
        add(piece);
      }
    }

    final currentPlayer = data['currentPlayer'] as String?;
    if (currentPlayer != null) {
      isMyTurn = (currentPlayer == user.id);
      onTurnChanged(isMyTurn);
      onStatusUpdate(isMyTurn ? 'Your turn!' : 'Opponent\'s turn');
    }

    gameStarted = true;
  }

  /// Converts the server's `{colour, isKing}` map to a local integer constant.
  int _mapServerPieceToLocal(dynamic serverPiece) {
    if (serverPiece == null) return CheckersConstants.emptySquare;

    final map    = serverPiece as Map<String, dynamic>;
    final colour = map['colour'] as String;
    final isKing = map['isKing'] as bool;

    if (colour == 'red'   && !isKing) return CheckersConstants.redPiece;
    if (colour == 'red'   &&  isKing) return CheckersConstants.redKing;
    if (colour == 'black' && !isKing) return CheckersConstants.blackPiece;
    if (colour == 'black' &&  isKing) return CheckersConstants.blackKing;

    return CheckersConstants.emptySquare;
  }

  // ─── Coordinate helpers ────────────────────────────────────────────────────

  /// Converts a server [Position] to the display position this player sees.
  ///
  /// Black (Player 2) sees a 180° rotation: (row, col) → (7-row, 7-col).
  Position _toDisplay(Position serverPos) => shouldRotateBoard
      ? Position(7 - serverPos.row, 7 - serverPos.col)
      : serverPos;

  /// Converts a display [Position] back to server coordinates.
  Position _toServer(Position displayPos) => shouldRotateBoard
      ? Position(7 - displayPos.row, 7 - displayPos.col)
      : displayPos;

  // ─── Input handling ────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);

    if (!gameStarted || !isMyTurn) return;

    final displayPos = board!.screenToBoard(info.eventPosition.widget);
    if (displayPos == null || !displayPos.isValid()) return;

    // Always work in server coordinates internally.
    final serverPos = _toServer(displayPos);

    // If a piece is already selected, check whether the tap is a valid destination.
    if (selectedPiece != null) {
      final isValidDest = validMoves.any(
        (m) => m.row == serverPos.row && m.col == serverPos.col,
      );
      if (isValidDest) {
        _makeMove(selectedPiece!, serverPos);
        return;
      }
    }

    // Otherwise check if the tapped square holds one of this player's pieces.
    final tappedPiece = pieces.where((p) =>
        p.boardPosition.row == serverPos.row &&
        p.boardPosition.col == serverPos.col,
    ).firstOrNull;

    if (tappedPiece != null && _isMyPiece(tappedPiece)) {
      _selectPiece(serverPos);
    }
  }

  /// Returns true if [piece] belongs to this player based on [myColour].
  bool _isMyPiece(CheckersPiece piece) {
    return (myColour == 'red' &&
            (piece.pieceType == CheckersConstants.redPiece ||
             piece.pieceType == CheckersConstants.redKing)) ||
           (myColour == 'black' &&
            (piece.pieceType == CheckersConstants.blackPiece ||
             piece.pieceType == CheckersConstants.blackKing));
  }

  /// Sends a piece-selection event to the server, which responds with
  /// the list of valid destination squares via [handlePieceSelected].
  void _selectPiece(Position pos) {
    selectedPiece = pos;
    socketService.sendGameAction(
      roomId: roomId,
      action: 'select_piece',
      payload: {
        'gameType': 'checkers',
        'userId':   user.id,
        'row':      pos.row,
        'col':      pos.col,
      },
    );
  }

  /// Sends the move to the server and clears local selection state.
  ///
  /// The visual update is deferred until [handleMoveMade] is received so the
  /// display always reflects the server's authoritative outcome.
  void _makeMove(Position from, Position to) {
    socketService.sendGameAction(
      roomId: roomId,
      action: 'make_move',
      payload: {
        'gameType': 'checkers',
        'userId':   user.id,
        'from': {'row': from.row, 'col': from.col},
        'to':   {'row': to.row,   'col': to.col},
      },
    );

    selectedPiece = null;
    validMoves.clear();
    board!.clearHighlights();
    board!.deselectSquare();
  }

  // ─── Socket event handlers ─────────────────────────────────────────────────

  /// Receives valid move destinations from the server and highlights them.
  ///
  /// Server positions are transformed to display positions before being passed
  /// to [CheckersBoard.highlightSquares].
  void handlePieceSelected(Map<String, dynamic> data) {
    final moves = data['validMoves'] as List;
    validMoves = moves.map((move) {
      final to = move['to'] as Map<String, dynamic>;
      return Position(to['row'] as int, to['col'] as int);
    }).toList();

    board!.highlightSquares(validMoves.map(_toDisplay).toList());

    if (selectedPiece != null) {
      board!.selectSquare(_toDisplay(selectedPiece!));
    }
  }

  /// Applies a completed move broadcast by the server to the visual board.
  ///
  /// Handles promotion by upgrading the piece type, and removes any captured
  /// piece by finding the midpoint of the jump in server coordinates.
  void handleMoveMade(Map<String, dynamic> data) {
    final from = data['from'] as Map<String, dynamic>;
    final to   = data['to']   as Map<String, dynamic>;

    final fromPos      = Position(from['row'] as int, from['col'] as int);
    final toPos        = Position(to['row'] as int,   to['col'] as int);
    final promoted     = data['promoted'] as bool? ?? false;
    final capturedData = data['capturedPiece'] as Map<String, dynamic>?;

    final movingPiece = pieces.where((p) =>
        p.boardPosition.row == fromPos.row &&
        p.boardPosition.col == fromPos.col,
    ).firstOrNull;

    if (movingPiece != null) {
      // Upgrade piece type on promotion (regular → king).
      int newType = movingPiece.pieceType;
      if (promoted) {
        newType = newType == CheckersConstants.redPiece
            ? CheckersConstants.redKing
            : CheckersConstants.blackKing;
      }

      final newScreenPos = board!.boardToScreen(_toDisplay(toPos));

      // Replace rather than mutate, since type may have changed.
      movingPiece.removeFromParent();
      pieces.remove(movingPiece);

      final newPiece = CheckersPiece(
        pieceType:     newType,
        boardPosition: toPos,
        position:      newScreenPos,
      );
      pieces.add(newPiece);
      add(newPiece);

      // Captured piece sits at the midpoint of the jump in server coordinates.
      if (capturedData != null) {
        final capturedRow = (fromPos.row + toPos.row) ~/ 2;
        final capturedCol = (fromPos.col + toPos.col) ~/ 2;
        _removePieceAt(Position(capturedRow, capturedCol));
      }
    }

    board!.clearHighlights();
    board!.deselectSquare();
    selectedPiece = null;
    validMoves.clear();
  }

  void _removePieceAt(Position pos) {
    final captured = pieces.where((p) =>
        p.boardPosition.row == pos.row &&
        p.boardPosition.col == pos.col,
    ).firstOrNull;

    if (captured != null) {
      captured.removeFromParent();
      pieces.remove(captured);
    }
  }

  /// Updates whose turn it is and notifies the host widget.
  void handleTurnChanged(Map<String, dynamic> data) {
    final currentPlayer = data['currentPlayer'] as String;
    isMyTurn = (currentPlayer == user.id);
    onTurnChanged(isMyTurn);
    onStatusUpdate(isMyTurn ? 'Your turn!' : 'Opponent\'s turn');
  }

  /// Marks the game as finished and delivers the result to the host widget.
  void handleGameOver(Map<String, dynamic> data) {
    final winner = data['winner'] as String;
    final reason = data['reason'] as String? ?? 'Game ended';

    gameStarted = false;

    onGameOver(winner == myColour ? 'You won! $reason' : 'You lost! $reason');
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    if (board != null) {
      board!.position = Vector2(newSize.x / 2, newSize.y / 2);

      // Reposition all pieces to their new screen coordinates after resize.
      for (var piece in pieces) {
        piece.position = board!.boardToScreen(_toDisplay(piece.boardPosition));
      }
    }
  }
}