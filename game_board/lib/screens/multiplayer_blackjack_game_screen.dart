// ====================================
// lib/screens/multiplayer_blackjack_game_screen.dart
// Multiplayer blackjack game screen with socket connection
// ====================================
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../games/multiplayer_blackjack_game.dart';
import '../models/user.dart';
import '../services/socket_service.dart';

class MultiplayerBlackjackGameScreen extends StatefulWidget {
  final User user;
  final String roomId;
  final bool isHost;

  const MultiplayerBlackjackGameScreen({
    Key? key,
    required this.user,
    required this.roomId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<MultiplayerBlackjackGameScreen> createState() => _MultiplayerBlackjackGameScreenState();
}

class _MultiplayerBlackjackGameScreenState extends State<MultiplayerBlackjackGameScreen> {
  late final MultiplayerBlackjackGame _game;
  final SocketService _socketService = SocketService();

  // Socket event subscriptions
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _playerLeftSub;
  StreamSubscription? _playerReadySub;
  StreamSubscription? _gameStartingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;

  // UI State
  bool _isConnected = false;
  String _statusMessage = 'Connecting...';
  List<Map<String, dynamic>> _players = [];

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _setupSocketListeners();
  }

  void _initializeGame() {
    _game = MultiplayerBlackjackGame(
      user: widget.user,
      roomId: widget.roomId,
      socketService: _socketService,
    );
    _game.isHost = widget.isHost;
  }

  void _setupSocketListeners() {
    // Connection status
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          _statusMessage = connected ? 'Connected' : 'Disconnected';
        });
      }
    });

    // Player joined
    _playerJoinedSub = _socketService.onPlayerJoined.listen((data) {
      if (mounted) {
        final room = data['room'];
        final players = room['players'] as List;
        
        setState(() {
          _players = players.cast<Map<String, dynamic>>();
          _statusMessage = '${data['player']['username']} joined';
        });

        // Add player to game
        final player = data['player'];
        final playerId = player['userId'];
        if (playerId != widget.user.id) {
          _game.addOtherPlayer(
            playerId,
            player['username'],
            player['bankroll'].toDouble(),
            player['position'],
          );
        }

        _game.playerCount = players.length;
        _game.hud.updateRoomInfo(widget.roomId, players.length, _game.maxPlayers);
      }
    });

    // Player left
    _playerLeftSub = _socketService.onPlayerLeft.listen((data) {
      if (mounted) {
        final room = data['room'];
        if (room != null) {
          final players = room['players'] as List;
          
          setState(() {
            _players = players.cast<Map<String, dynamic>>();
            _statusMessage = '${data['username']} left';
          });

          // Remove player from game
          _game.removeOtherPlayer(data['userId']);
          _game.playerCount = players.length;
          _game.hud.updateRoomInfo(widget.roomId, players.length, _game.maxPlayers);
        } else {
          // Room was deleted, go back
          _showMessage('Room was closed');
          _leaveRoom();
        }
      }
    });

    // Player ready
    _playerReadySub = _socketService.onPlayerReady.listen((data) {
      if (mounted) {
        setState(() {
          _statusMessage = '${data['username']} is ready';
        });

        // Update player ready status in game
        final playerId = data['userId'];
        if (_game.otherPlayers.containsKey(playerId)) {
          _game.otherPlayers[playerId]!.setReady(true);
        }
      }
    });

    // Game starting
    _gameStartingSub = _socketService.onGameStarting.listen((data) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Game starting!';
        });
        
        _showMessage('Game starting!', duration: Duration(seconds: 2));
      }
    });

    // Errors
    _errorSub = _socketService.onError.listen((error) {
      if (mounted) {
        _showError(error);
      }
    });
  }

  void _showMessage(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _showError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _leaveRoom() {
    _socketService.leaveRoom(
      roomId: widget.roomId,
      userId: widget.user.id,
    );
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonSize = (size.height * 0.06).clamp(32.0, 48.0);
    final topPadding = size.height * 0.02;
    final leftPadding = size.width * 0.02;

    return WillPopScope(
      onWillPop: () async {
        final shouldLeave = await _showLeaveConfirmation();
        if (shouldLeave) {
          _leaveRoom();
        }
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Game widget
            GameWidget(game: _game),

            // Top bar with back button and status
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: leftPadding,
                    vertical: topPadding,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: buttonSize * 0.7,
                        ),
                        onPressed: () async {
                          final shouldLeave = await _showLeaveConfirmation();
                          if (shouldLeave) {
                            _leaveRoom();
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          padding: EdgeInsets.all(buttonSize * 0.25),
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Connection indicator
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected ? Colors.green : Colors.red,
                          boxShadow: [
                            if (_isConnected)
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                      ),
                      
                      SizedBox(width: 8),
                      
                      // Status text
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: buttonSize * 0.35,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Player count badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              color: Colors.amber,
                              size: buttonSize * 0.4,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${_players.length}/${_game.maxPlayers}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: buttonSize * 0.35,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Connection lost overlay
            if (!_isConnected)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Card(
                      margin: EdgeInsets.all(32),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off,
                              color: Colors.red,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Connection Lost',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Trying to reconnect...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 24),
                            CircularProgressIndicator(),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                _leaveRoom();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: Text('Leave Room'),
                            ),
                          ],
                        ),
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

  Future<bool> _showLeaveConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Game?'),
        content: Text(
          'Are you sure you want to leave this multiplayer game? You will lose your bet if a round is in progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Leave'),
          ),
        ],
      ),
    ) ?? false;
  }
}