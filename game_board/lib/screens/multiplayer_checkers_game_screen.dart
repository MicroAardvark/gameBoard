// ====================================
// lib/screens/multiplayer_checkers_game_screen.dart
// Multiplayer Checkers screen – visually identical to single player
// ====================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../models/user.dart';
import '../services/socket_service.dart';
import '../services/voice_chat_service.dart';
import '../games/multiplayer_checkers_game.dart';
import '../widgets/chat_overlay.dart';

class MultiplayerCheckersGameScreen extends StatefulWidget {
  final User user;
  final String roomId;
  final List<Map<String, dynamic>> players;

  const MultiplayerCheckersGameScreen({
    super.key,
    required this.user,
    required this.roomId,
    required this.players,
  });

  @override
  State<MultiplayerCheckersGameScreen> createState() =>
      _MultiplayerCheckersGameScreenState();
}

class _MultiplayerCheckersGameScreenState
    extends State<MultiplayerCheckersGameScreen> {
  final SocketService _socketService = SocketService();
  late final VoiceChatService _voiceService;
  late final MultiplayerCheckersGame _game;

  String _statusMessage = 'Waiting for players…';
  bool _isMyTurn = false;
  bool _gameStarted = false;
  bool _isChatOpen = false;
  int _playerCount = 0;
  int _unreadMessages = 0;

  StreamSubscription? _gameActionSub;
  StreamSubscription? _chatMessageSub;

  @override
  void initState() {
    super.initState();

    _voiceService = VoiceChatService(_socketService);
    _playerCount = widget.players.length;

    _game = MultiplayerCheckersGame(
      user: widget.user,
      roomId: widget.roomId,
      socketService: _socketService,
      onStatusUpdate: (message) {
        if (mounted) {
          setState(() => _statusMessage = message);
        }
      },
      onTurnChanged: (isMyTurn) {
        if (mounted) {
          setState(() => _isMyTurn = isMyTurn);
        }
      },
      onGameOver: (message) {
        if (mounted) {
          _showGameOverDialog(message);
        }
      },
    );

    _joinRoom();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _gameActionSub?.cancel();
    _chatMessageSub?.cancel();

    _socketService.leaveRoom(
      roomId: widget.roomId,
      userId: widget.user.id,
    );

    super.dispose();
  }

  void _joinRoom() {
    _socketService.joinRoom(
      roomId: widget.roomId,
      userId: widget.user.id,
      username: widget.user.username,
    );
  }

  void _setupSocketListeners() {
    _gameActionSub = _socketService.onGameAction.listen((data) {
      if (data['gameType'] != 'checkers') return;

      switch (data['action']) {
        case 'game_started':
          _game.syncBoardFromServer(data);
          setState(() {
            _gameStarted = true;
            _statusMessage = 'Game started';
          });
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
      if (!_isChatOpen && mounted) {
        setState(() => _unreadMessages++);
      }
    });
  }

  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text(
          'Game Over',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Lobby'),
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
        child: Row(
          children: [
            // LEFT PANEL — MATCHES SINGLE PLAYER
            Container(
              width: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF1A2332),
                border: Border(
                  right: BorderSide(
                    color: Color(0xFFFFA500),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFFFA500),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Checkers',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTurnIndicator('You', _isMyTurn),
                        const SizedBox(height: 24),
                        _buildTurnIndicator(
                          'Opponent',
                          !_isMyTurn && _gameStarted,
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chat,
                      color: Color(0xFFFFA500),
                    ),
                    onPressed: () {
                      setState(() {
                        _isChatOpen = !_isChatOpen;
                        _unreadMessages = 0;
                      });
                    },
                  ),
                  if (_unreadMessages > 0)
                    Text(
                      '$_unreadMessages',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // GAME AREA — IDENTICAL SIZE & CONSTRAINTS
            Expanded(
              child: Stack(
                children: [
                  GameWidget(game: _game),
                  if (_isChatOpen)
                    Positioned.fill(
                      child: ChatOverlay(
                        roomId: widget.roomId,
                        userId: widget.user.id,
                        username: widget.user.username,
                        socketService: _socketService,
                        voiceService: _voiceService,
                        onClose: () {
                          setState(() {
                            _isChatOpen = false;
                            _unreadMessages = 0;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnIndicator(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4CAF50) : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
