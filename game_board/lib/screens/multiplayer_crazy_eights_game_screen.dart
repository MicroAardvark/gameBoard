// lib/screens/multiplayer_crazy_eights_game_screen.dart
// UPDATED: Added optimistic UI event handlers
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_board/widgets/voice_indicator.dart';
import 'dart:async';
import '../games/multiplayer_crazy_eights_game.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import '../widgets/chat_overlay.dart';
import '../theme/app_theme.dart';
import '../utils/platform_utils.dart';

class MultiplayerCrazyEightsGameScreen extends StatefulWidget {
  final User user;
  final String roomId;
  final bool isHost;

  const MultiplayerCrazyEightsGameScreen({
    super.key,
    required this.user,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<MultiplayerCrazyEightsGameScreen> createState() => _MultiplayerCrazyEightsGameScreenState();
}

class _MultiplayerCrazyEightsGameScreenState extends State<MultiplayerCrazyEightsGameScreen> {
  late final MultiplayerCrazyEightsGame _game;
  final SocketService _socketService = SocketService();
  late final VoiceChatService _voiceService;

  // Socket event subscriptions (UPDATED WITH NEW HANDLERS)
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _playerLeftSub;
  StreamSubscription? _playerReadySub;
  StreamSubscription? _gameStartingSub;
  StreamSubscription? _gameStartedSub;
  StreamSubscription? _cardPlayedSub;
  StreamSubscription? _cardPlayRejectedSub; // NEW
  StreamSubscription? _cardDrawnSub;
  StreamSubscription? _cardsDrawnSub; // NEW
  StreamSubscription? _turnChangedSub; // NEW
  StreamSubscription? _suitChosenSub; // NEW
  StreamSubscription? _chooseSuitRequiredSub; // NEW
  StreamSubscription? _playerTurnSub;
  StreamSubscription? _crazyEightsCalledSub;
  StreamSubscription? _crazyEightsViolationSub;
  StreamSubscription? _challengeSuccessfulSub;
  StreamSubscription? _jackChoiceNeededSub;
  StreamSubscription? _jackActionChosenSub;
  StreamSubscription? _chooseJackActionRequiredSub; // NEW
  StreamSubscription? _cardsReceivedSub;
  StreamSubscription? _gameEndedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _chatMessageSub;

  // UI State
  bool _isConnected = false;
  String _statusMessage = 'Connecting...';
  List<Map<String, dynamic>> _players = [];
  
  // Connection dialog control flags
  bool _hasShownConnectionDialog = false;
  bool _initialConnectionCheck = true;
  
  // Chat state
  bool _showChat = false;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    
    print('🎮 [CRAZY EIGHTS GAME SCREEN] Initializing...');
    print('   Room ID: ${widget.roomId}');
    print('   Is Host: ${widget.isHost}');
    print('   Socket connected: ${_socketService.isConnected}');
    print('   Current room ID: ${_socketService.currentRoomId}');
    
    _voiceService = VoiceChatService(_socketService);
    _isConnected = _socketService.isConnected;
    _statusMessage = _isConnected ? 'Connected' : 'Connecting...';
    
    _initializeGame();
    _setupSocketListeners();
    
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _initialConnectionCheck = false;
        });
      }
    });
  }

  void _initializeGame() {
    _game = MultiplayerCrazyEightsGame(
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
        
        if (!connected && !_initialConnectionCheck && !_hasShownConnectionDialog) {
          _hasShownConnectionDialog = true;
        } else if (connected) {
          _hasShownConnectionDialog = false;
        }
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

        final player = data['player'];
        final playerId = player['userId'];
        if (playerId != widget.user.id) {
          _game.addOtherPlayer(
            playerId,
            player['username'],
            player['position'],
          );
        }

        _game.playerCount = players.length;
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

          _game.removeOtherPlayer(data['userId']);
          _game.playerCount = players.length;
        } else {
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
        
        _showMessage('Game starting!');
      }
    });

    // Game started - cards dealt
    _gameStartedSub = _socketService.onGameStarted.listen((data) {
      if (mounted) {
        print('🎮 Game started event received');
        _game.handleGameStarted(data);
        
        setState(() {
          _statusMessage = 'Game started!';
        });
      }
    });

    // Card played
    _cardPlayedSub = _socketService.onCardPlayed.listen((data) {
      if (mounted) {
        print('🃏 Card played event received');
        _game.handleCardPlayed(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // NEW: Card play rejected (optimistic update rollback)
    _cardPlayRejectedSub = _socketService.onCardPlayRejected.listen((data) {
      if (mounted) {
        print('❌ Card play rejected: ${data['reason']}');
        _game.handleCardPlayRejected(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
        
        _showError('Invalid move: ${data['reason']}');
      }
    });

    // Card drawn (other player)
    _cardDrawnSub = _socketService.onCardDrawn.listen((data) {
      if (mounted) {
        print('📥 Card drawn event received');
        _game.handleCardDrawn(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // NEW: Cards drawn (my cards with data)
    _cardsDrawnSub = _socketService.onCardsDrawn.listen((data) {
      if (mounted) {
        print('📨 My cards drawn');
        _game.handleCardsDrawn(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // NEW: Turn changed
    _turnChangedSub = _socketService.onTurnChanged.listen((data) {
      if (mounted) {
        print('🔄 Turn changed');
        _game.handleTurnChanged(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // NEW: Suit chosen
    _suitChosenSub = _socketService.onSuitChosen.listen((data) {
      if (mounted) {
        print('👑 Suit chosen');
        _game.handleSuitChosen(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // NEW: Choose suit required
    _chooseSuitRequiredSub = _socketService.onChooseSuitRequired.listen((data) {
      if (mounted) {
        print('👑 Choose suit required');
        _game.handleChooseSuitRequired(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // Player turn (legacy - still supported)
    _playerTurnSub = _socketService.onPlayerTurn.listen((data) {
      if (mounted) {
        print('👤 Player turn event received (legacy)');
        _game.handlePlayerTurn(data);
        
        setState(() {
          if (data['userId'] == widget.user.id) {
            _statusMessage = 'Your turn!';
          } else {
            _statusMessage = '${data['username']}\'s turn';
          }
        });
      }
    });

    // Crazy Eights called
    _crazyEightsCalledSub = _socketService.onCrazyEightsCalled.listen((data) {
      if (mounted) {
        print('🎯 Crazy Eights called');
        _game.handleCrazyEightsCalled(data);
        
        setState(() {
          _statusMessage = '🎯 ${data['username']} called Crazy Eights!';
        });
        
        _showMessage('${data['username']} called Crazy Eights!');
      }
    });

    // Crazy Eights violation
    _crazyEightsViolationSub = _socketService.onCrazyEightsViolation.listen((data) {
      if (mounted) {
        print('⚠️ Crazy Eights violation');
        _game.handleCrazyEightsViolation(data);
        
        setState(() {
          _statusMessage = '⚠️ ${data['username']} forgot to call Crazy Eights!';
        });
      }
    });

    // Challenge successful
    _challengeSuccessfulSub = _socketService.onChallengeSuccessful.listen((data) {
      if (mounted) {
        print('✅ Challenge successful');
        
        setState(() {
          _statusMessage = '✅ ${data['challengerName']} challenged ${data['targetName']}!';
        });
        
        _showMessage('Challenge successful! ${data['targetName']} drew 2 cards');
      }
    });

    // Jack choice needed (legacy - still supported)
    _jackChoiceNeededSub = _socketService.onJackChoiceNeeded.listen((data) {
      if (mounted) {
        print('🃏 Jack choice needed (legacy)');
        _game.handleJackChoiceNeeded(data);
        
        if (data['userId'] == widget.user.id) {
          setState(() {
            _statusMessage = 'Choose Jack action: Skip or Reverse?';
          });
        }
      }
    });

    // Jack action chosen
    _jackActionChosenSub = _socketService.onJackActionChosen.listen((data) {
      if (mounted) {
        print('🃏 Jack action chosen: ${data['action']}');
        _game.handleJackActionChosen(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // NEW: Choose Jack action required
    _chooseJackActionRequiredSub = _socketService.onChooseJackActionRequired.listen((data) {
      if (mounted) {
        print('🃏 Choose Jack action required');
        _game.handleChooseJackActionRequired(data);
        
        setState(() {
          _statusMessage = _game.statusMessage;
        });
      }
    });

    // Cards received (my drawn cards - legacy)
    _cardsReceivedSub = _socketService.onCardsReceived.listen((data) {
      if (mounted) {
        print('📨 Cards received (legacy)');
        _game.handleCardsReceived(data);
      }
    });

    // Game ended
    _gameEndedSub = _socketService.onGameAction.listen((event) {
      if (event['type'] == 'game_ended' && mounted) {
        final data = event['data'];
        print('🏆 Game ended');
        _game.handleGameEnded(data);
        
        setState(() {
          if (data['winnerId'] == widget.user.id) {
            _statusMessage = '🏆 YOU WIN!';
          } else {
            _statusMessage = '${data['winnerName']} wins!';
          }
        });
      }
    });

    // Chat messages
    _chatMessageSub = _socketService.onChatMessage.listen((data) {
      if (mounted && !_showChat) {
        setState(() {
          _unreadMessages++;
        });
      }
    });

    // Errors
    _errorSub = _socketService.onError.listen((error) {
      if (mounted) {
        _showError(error);
      }
    });
  }

  void _toggleReady() {
    if (_game.isReady) {
      _socketService.playerUnready(
        roomId: widget.roomId,
        userId: widget.user.id,
      );
      _game.isReady = false;
    } else {
      _socketService.playerReady(
        roomId: widget.roomId,
        userId: widget.user.id,
      );
      _game.isReady = true;
    }
    
    setState(() {});
  }

  void _startGame() {
    if (!widget.isHost) {
      _showError('Only the host can start the game');
      return;
    }

    if (_players.length < 2) {
      _showError('Need at least 2 players to start');
      return;
    }

    if (!_players.every((p) => p['isReady'] == true)) {
      _showError('All players must be ready');
      return;
    }

    print('🎮 Host starting game...');
    _socketService.startCrazyEights(roomId: widget.roomId);
  }

  void _leaveRoom() {
    _socketService.leaveRoom(
      roomId: widget.roomId,
      userId: widget.user.id,
    );
    
    Navigator.of(context).pop();
  }

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
      if (_showChat) {
        _unreadMessages = 0;
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.primaryNavyLight,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error, style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _gameStartedSub?.cancel();
    _cardPlayedSub?.cancel();
    _cardPlayRejectedSub?.cancel(); // NEW
    _cardDrawnSub?.cancel();
    _cardsDrawnSub?.cancel(); // NEW
    _turnChangedSub?.cancel(); // NEW
    _suitChosenSub?.cancel(); // NEW
    _chooseSuitRequiredSub?.cancel(); // NEW
    _playerTurnSub?.cancel();
    _crazyEightsCalledSub?.cancel();
    _crazyEightsViolationSub?.cancel();
    _challengeSuccessfulSub?.cancel();
    _jackChoiceNeededSub?.cancel();
    _jackActionChosenSub?.cancel();
    _chooseJackActionRequiredSub?.cancel(); // NEW
    _cardsReceivedSub?.cancel();
    _gameEndedSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    _chatMessageSub?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Game canvas
          GameWidget(game: _game),
          
          // Top status bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.primaryNavyDark,
                            title: Text('Leave Game?', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary)),
                            content: Text(
                              'Are you sure you want to leave?',
                              style: TextStyle(fontFamily: 'Inter', color: Colors.grey[400]),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _leaveRoom();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text('Leave', style: TextStyle(fontFamily: 'Inter')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Room ID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room: ${widget.roomId.split('_').last.substring(0, 8)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Connection status
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Chat button
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chat, color: Colors.white),
                          onPressed: _toggleChat,
                        ),
                        if (_unreadMessages > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_unreadMessages',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Waiting room controls (before game starts)
          if (_game.gameState == GameState.waiting)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Player list
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavyDark.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: _players.map((player) {
                            final isReady = player['isReady'] == true;
                            final isMe = player['userId'] == widget.user.id;
                            
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isReady ? Icons.check_circle : Icons.circle_outlined,
                                    color: isReady ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${player['username']}${isMe ? ' (You)' : ''}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleReady,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _game.isReady ? Colors.orange : Colors.green,
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                _game.isReady ? 'Not Ready' : 'Ready',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          if (widget.isHost) ...[
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text(
                                  'Start Game',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNavyDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Chat overlay
          if (_showChat)
            ChatOverlay(
              roomId: widget.roomId,
              userId: widget.user.id,
              username: widget.user.username,
              socketService: _socketService,
              voiceService: _voiceService,
              onClose: _toggleChat,
            ),
          
          if(!_showChat)
            VoiceIndicator(
              voiceService: _voiceService,
              onTap: () => setState(() => _showChat = true),
            )
        ],
      ),
    );
  }
}

enum GameState {
  waiting,
  playing,
  finished,
}