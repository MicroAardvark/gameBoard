// ====================================
// lib/screens/multiplayer_checkers_game_screen.dart
// Wrapper screen for multiplayer checkers game with socket handling
// ====================================

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'dart:async';
import '../models/user.dart';
import '../services/socket_service.dart';
import '../services/voice_chat_service.dart';
import '../games/multiplayer_checkers_game.dart';
import '../widgets/chat_overlay.dart';
import '../widgets/voice_indicator.dart';

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
  State<MultiplayerCheckersGameScreen> createState() => _MultiplayerCheckersGameScreenState();
}

class _MultiplayerCheckersGameScreenState extends State<MultiplayerCheckersGameScreen> {
  final SocketService _socketService = SocketService();
  late VoiceChatService _voiceService;
  late MultiplayerCheckersGame _game;

  String _statusMessage = 'Waiting for players...';
  bool _isMyTurn = false;
  int _playerCount = 0;
  bool _allReady = false;
  bool _gameStarted = false;
  bool _isChatOpen = false;
  int _unreadMessages = 0;

  // Stream subscriptions
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _playerLeftSub;
  StreamSubscription? _playerReadySub;
  StreamSubscription? _gameStartingSub;
  StreamSubscription? _gameActionSub;
  StreamSubscription? _chatMessageSub;

  @override
  void initState() {
    super.initState();
    print('🎮 Multiplayer Checkers Game Screen initialized');
    print('   Room ID: ${widget.roomId}');
    print('   User: ${widget.user.username}');
    print('   Player count: ${widget.players.length}');

    _voiceService = VoiceChatService(_socketService);
    
    _playerCount = widget.players.length;
    
    _game = MultiplayerCheckersGame(
      user: widget.user,
      roomId: widget.roomId,
      socketService: _socketService,
      onStatusUpdate: (message) {
        if (mounted) {
          setState(() {
            _statusMessage = message;
          });
        }
      },
      onGameOver: (message) {
        if (mounted) {
          _showGameOverDialog(message);
        }
      },
      onTurnChanged: (isMyTurn) {
        if (mounted) {
          setState(() {
            _isMyTurn = isMyTurn;
          });
        }
      },
    );

    _joinRoom();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _gameActionSub?.cancel();
    _chatMessageSub?.cancel();
    
    _socketService.leaveRoom(
      roomId: widget.roomId,
      userId: widget.user.id,
    );
    
    super.dispose();
  }

  void _setupSocketListeners() {
    // Player joined
    _playerJoinedSub = _socketService.onPlayerJoined.listen((data) {
      if (mounted) {
        print('👤 Player joined event');
        setState(() {
          _playerCount = (data['room']['players'] as List).length;
          _statusMessage = '${data['player']['username']} joined';
        });
      }
    });

    // Player left
    _playerLeftSub = _socketService.onPlayerLeft.listen((data) {
      if (mounted) {
        print('👋 Player left event');
        if (data['room'] != null) {
          setState(() {
            _playerCount = (data['room']['players'] as List).length;
            _statusMessage = '${data['username']} left';
          });
        } else {
          _showMessage('Room was closed');
          Navigator.pop(context);
        }
      }
    });

    // Player ready
    _playerReadySub = _socketService.onPlayerReady.listen((data) {
      if (mounted) {
        print('✅ Player ready: ${data['username']}');
        setState(() {
          _statusMessage = '${data['username']} is ready';
          _allReady = data['allReady'] ?? false;
        });
      }
    });

    // Game starting
    _gameStartingSub = _socketService.onGameStarting.listen((data) {
      if (mounted) {
        print('🎮 Game starting!');
        setState(() {
          _statusMessage = 'Game starting!';
        });
      }
    });

    // Game action events (checkers-specific)
    _gameActionSub = _socketService.onGameAction.listen((data) {
      if (mounted && data['gameType'] == 'checkers') {
        print('🎲 Checkers game action: ${data['action']}');
        
        switch (data['action']) {
          case 'game_started':
            _game.syncBoardFromServer(data);
            setState(() {
              _gameStarted = true;
              _statusMessage = 'Game started!';
            });
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
      }
    });

    // Chat messages
    _chatMessageSub = _socketService.onChatMessage.listen((data) {
      if (mounted && !_isChatOpen) {
        print('💬 New message while chat closed');
        setState(() {
          _unreadMessages++;
        });
      }
    });
  }

  void _joinRoom() {
    print('🚪 Joining room: ${widget.roomId}');
    
    _socketService.joinRoom(
      roomId: widget.roomId,
      userId: widget.user.id,
      username: widget.user.username,
    );
  }

  void _toggleReady() {
    // Toggle ready state
    _socketService.playerReady(
      roomId: widget.roomId,
      userId: widget.user.id,
    );
  }

  void _startGame() {
    print('▶️ Starting game');
    
    _socketService.sendGameAction(
      roomId: widget.roomId,
      action: 'start_game',
      payload: {
        'userId': widget.user.id,
        'gameType': 'checkers',
      },
    );
  }

  void _resign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text(
          'Resign Game?',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        content: const Text(
          'Are you sure you want to resign? This will end the game.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              _socketService.sendGameAction(
                roomId: widget.roomId,
                action: 'resign',
                payload: {
                  'userId': widget.user.id,
                  'gameType': 'checkers',
                },
              );
            },
            child: const Text('Resign', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to lobby
            },
            child: const Text('Back to Lobby'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Game?'),
            content: const Text('Are you sure you want to leave?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );

        if (shouldLeave == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Stack(
          children: [
            // Game canvas
            GameWidget(game: _game),

            // Status bar (top)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: _buildStatusBar(screenWidth),
            ),

            // Controls (bottom)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: _buildControls(screenWidth),
            ),

            // Chat overlay
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
    );
  }

  Widget _buildStatusBar(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332).withOpacity(0.9),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFFFA500).withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current turn indicator
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _isMyTurn ? const Color(0xFF4CAF50) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Player count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3F5F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_playerCount/2 Players',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          
          const SizedBox(width: 12),

          // Voice indicator
          VoiceIndicator(
            voiceService: _voiceService,
            onTap: () {
              setState(() {
                _isChatOpen = !_isChatOpen;
                if (_isChatOpen) {
                  _unreadMessages = 0;
                }
              });
            },
          ),
          
          const SizedBox(width: 12),
          
          // Chat button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isChatOpen = !_isChatOpen;
                    if (_isChatOpen) {
                      _unreadMessages = 0;
                    }
                  });
                },
              ),
              if (_unreadMessages > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadMessages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(double screenWidth) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ready/Start/Resign buttons
          if (!_gameStarted && _playerCount == 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ready button
                ElevatedButton(
                  onPressed: _toggleReady,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text(
                    'Ready',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Start button (host only, when all ready)
                if (_allReady)
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Start Game',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          
          // Resign button (during game)
          if (_gameStarted)
            ElevatedButton(
              onPressed: _resign,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Resign',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}