// lib/screens/multiplayer_checkers_game_screen.dart
//
// TODO: Remove this file once multiplayer Checkers is fully retired from the
// project. Also remove the corresponding entry in MultiplayerLobbyScreen and
// the MultiplayerCheckersLobbyScreen import.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../../models/user.dart';
import '../../services/socket_service.dart';
import '../../services/voice_chat_service.dart';
import '../../games/multiplayer_checkers_game.dart';
import '../../widgets/chat_overlay.dart';

/// In-game screen for multiplayer Checkers.
///
/// Wraps [MultiplayerCheckersGame] (Flame engine) in a narrow left-panel
/// shell that provides navigation, turn indicators, and a chat toggle.
/// The game canvas occupies the remaining horizontal space so that tap
/// coordinates map directly to board squares without any horizontal offset.
///
/// Before play begins, a full-screen lobby overlay is shown over the canvas
/// where players can ready up. The overlay is dismissed automatically once
/// the engine receives a [game_started] action from the server.
///
/// Unlike the Blackjack and Crazy Eights screens, this screen joins the room
/// in [initState] rather than letting the lobby screen handle it, because the
/// Checkers lobby navigates here immediately on join without waiting for a
/// server confirmation first.
class MultiplayerCheckersGameScreen extends StatefulWidget {
  final User                        user;
  final String                      roomId;
  /// Initial player list passed from the lobby. Will be empty for joining
  /// players; the screen populates it from incoming [onPlayerJoined] events.
  final List<Map<String, dynamic>>  players;

  const MultiplayerCheckersGameScreen({
    super.key,
    required this.user,
    required this.roomId,
    required this.players,
  });

  @override
  State<MultiplayerCheckersGameScreen> createState() => _MultiplayerCheckersGameScreenState();
}

class _MultiplayerCheckersGameScreenState extends State<MultiplayerCheckersGameScreen> {
  final SocketService _socketService = SocketService();
  late final VoiceChatService _voiceService;
  late final MultiplayerCheckersGame _game;

  // Status and turn state reflected in the left panel.
  String _statusMessage = 'Waiting for players…';
  bool   _isMyTurn      = false;
  bool   _gameStarted   = false;
  bool   _isChatOpen    = false;
  bool   _isReady       = false;
  int    _playerCount   = 0;
  int    _unreadMessages = 0;

  List<Map<String, dynamic>> _players = [];

  // Socket event subscriptions — all cancelled in dispose().
  StreamSubscription? _gameActionSub;
  StreamSubscription? _chatMessageSub;
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _playerLeftSub;
  StreamSubscription? _playerReadySub;
  StreamSubscription? _gameStartingSub;
  StreamSubscription? _connectionSub;

  @override
  void initState() {
    super.initState();

    _voiceService = VoiceChatService(_socketService);
    _playerCount  = widget.players.length;
    _players      = widget.players;

    // Game engine callbacks keep Flutter UI state in sync without requiring
    // setState to be called from inside the Flame component tree.
    _game = MultiplayerCheckersGame(
      user:         widget.user,
      roomId:       widget.roomId,
      socketService: _socketService,
      onStatusUpdate: (message) {
        if (mounted) setState(() => _statusMessage = message);
      },
      onTurnChanged: (isMyTurn) {
        if (mounted) setState(() => _isMyTurn = isMyTurn);
      },
      onGameOver: (message) {
        if (mounted) _showGameOverDialog(message);
      },
    );

    _joinRoom();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _gameActionSub?.cancel();
    _chatMessageSub?.cancel();
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _connectionSub?.cancel();

    // leaveRoom is called here rather than in a dedicated _leaveRoom() method
    // because the back button in the left panel calls Navigator.pop() directly
    // without going through a helper — so dispose() is the reliable call site.
    _socketService.leaveRoom(roomId: widget.roomId, userId: widget.user.id);

    _voiceService.dispose();
    super.dispose();
  }

  /// Joins the room immediately on entry. For the host this is a no-op if the
  /// engine is already in the room; for joining players this confirms their
  /// presence to the server.
  void _joinRoom() {
    _socketService.joinRoom(
      roomId:   widget.roomId,
      userId:   widget.user.id,
      username: widget.user.username,
    );
  }

  void _setupSocketListeners() {
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (mounted) setState(() => _statusMessage = connected ? 'Connected' : 'Disconnected');
    });

    // Handles both player_joined and player_reconnected events because both
    // arrive on the same [onPlayerJoined] stream.
    _playerJoinedSub = _socketService.onPlayerJoined.listen((data) {
      if (mounted) {
        final players = (data['room']['players'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _players     = players;
          _playerCount = players.length;
          // Distinguish join from reconnect by whether a 'player' key is present.
          _statusMessage = data.containsKey('player')
              ? '${data['player']['username']} joined'
              : '${data['username']} reconnected';
        });
      }
    });

    _playerLeftSub = _socketService.onPlayerLeft.listen((data) {
      if (mounted) {
        final room = data['room'];
        if (room != null) {
          final players = (room['players'] as List).cast<Map<String, dynamic>>();
          setState(() {
            _players       = players;
            _playerCount   = players.length;
            _statusMessage = '${data['username']} left';
          });
        } else {
          // Null room means the host closed it — pop back to the lobby.
          _showMessage('Room was closed');
          Navigator.of(context).pop();
        }
      }
    });

    _playerReadySub = _socketService.onPlayerReady.listen((data) {
      if (mounted) {
        final room = data['room'];
        setState(() {
          _statusMessage = '${data['username']} is ready';
          if (room != null) {
            _players = (room['players'] as List).cast<Map<String, dynamic>>();
          }
        });
      }
    });

    _gameStartingSub = _socketService.onGameStarting.listen((_) {
      if (mounted) {
        setState(() => _statusMessage = 'Game starting!');
        _showMessage('Game starting!');
      }
    });

    // All in-game actions arrive on a single stream, routed by action type.
    _gameActionSub = _socketService.onGameAction.listen((data) {
      if (data['gameType'] != 'checkers') return;

      switch (data['action']) {
        case 'game_started':
          _game.syncBoardFromServer(data);
          setState(() { _gameStarted = true; _statusMessage = 'Game started!'; });
          break;
        case 'piece_selected':
          _game.handlePieceSelected(data);
          break;
        case 'move_made':
          _game.handleMoveMade(data);
          break;
        case 'turn_changed':
          _game.handleTurnChanged(data);
          break;
        case 'game_over':
          _game.handleGameOver(data);
          break;
      }
    });

    _chatMessageSub = _socketService.onChatMessage.listen((_) {
      if (!_isChatOpen && mounted) setState(() => _unreadMessages++);
    });
  }

  void _toggleReady() {
    setState(() => _isReady = !_isReady);
    if (_isReady) {
      _socketService.playerReady(roomId: widget.roomId, userId: widget.user.id);
    } else {
      _socketService.playerUnready(roomId: widget.roomId, userId: widget.user.id);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF1A2332),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Game-over dialog — [barrierDismissible] is false so the player must
  /// actively acknowledge the result before returning to the lobby.
  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFFFA500), width: 2)),
        title: const Text('Game Over', style: TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog.
              Navigator.of(context).pop(); // Return to lobby.
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFA500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('Back to Lobby', style: TextStyle(color: Color(0xFF1A2332), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Stack(
          children: [
            // Main layout: narrow left control panel + game canvas.
            Row(
              children: [
                // Left panel — kept intentionally narrow (80 px) so the game
                // canvas fills the rest of the screen and tap coordinates align
                // with board squares without a horizontal offset correction.
                Container(
                  width: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A2332),
                    border: Border(right: BorderSide(color: Color(0xFFFFA500), width: 1)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFFFFA500), size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Checkers', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 24),

                      // Turn indicators centred vertically in the remaining space.
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTurnIndicator('You',      _isMyTurn),
                            const SizedBox(height: 24),
                            _buildTurnIndicator('Opponent', !_isMyTurn),
                          ],
                        ),
                      ),

                      // Chat button at the bottom with unread badge.
                      IconButton(
                        icon: Stack(
                          children: [
                            const Icon(Icons.chat, color: Color(0xFFFFA500), size: 24),
                            if (_unreadMessages > 0)
                              Positioned(
                                right: 0, top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: Text('$_unreadMessages', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () {
                          setState(() {
                            _isChatOpen    = !_isChatOpen;
                            _unreadMessages = 0;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Game canvas + chat overlay.
                Expanded(
                  child: Stack(
                    children: [
                      GameWidget(game: _game),
                      if (_isChatOpen)
                        Positioned.fill(
                          child: ChatOverlay(
                            roomId: widget.roomId, userId: widget.user.id, username: widget.user.username,
                            socketService: _socketService, voiceService: _voiceService,
                            onClose: () => setState(() { _isChatOpen = false; _unreadMessages = 0; }),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Lobby overlay — full-screen, shown until both players are ready and the game starts.
            if (!_gameStarted)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Checkers', style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Waiting for players…', style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.7), fontSize: 16)),
                          const SizedBox(height: 32),

                          // Player ready list.
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2332).withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFA500), width: 1),
                            ),
                            child: Column(
                              children: [
                                const Text('Players', style: TextStyle(fontFamily: 'Inter', color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                ..._players.map((player) {
                                  final isReady = player['isReady'] == true;
                                  final isMe    = player['userId'] == widget.user.id;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(isReady ? Icons.check_circle : Icons.circle_outlined, color: isReady ? Colors.green : Colors.grey, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${player['username']}${isMe ? ' (You)' : ''}',
                                            style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 16, fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Ready toggle button.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _toggleReady,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isReady ? Colors.orange : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                _isReady ? 'Not Ready' : 'Ready',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dynamic status hint at the bottom of the overlay.
                          if (_playerCount < 2)
                            Text('Waiting for 1 more player…', style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.6), fontSize: 14))
                          else if (_players.every((p) => p['isReady'] == true))
                            const Text('Starting game…', style: TextStyle(fontFamily: 'Inter', color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold))
                          else
                            Text('Waiting for all players to ready up…', style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Small coloured dot with a text label used in the left panel to show
  /// whose turn it currently is.
  Widget _buildTurnIndicator(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4CAF50) : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }
}