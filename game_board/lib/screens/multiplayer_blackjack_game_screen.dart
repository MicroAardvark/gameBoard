// ====================================
// lib/screens/multiplayer_blackjack_game_screen.dart
// Multiplayer blackjack game screen - WITH BETTING SIDE MENU
// ====================================
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../games/multiplayer_blackjack_game.dart';
import '../models/user.dart';
import '../models/enums.dart'; // NEW: For GameState
import '../services/socket_service.dart';
import '../widgets/chat_overlay.dart';
import '../widgets/betting_side_menu.dart'; // NEW: Betting menu import
import '../theme/app_theme.dart';

class MultiplayerBlackjackGameScreen extends StatefulWidget {
  final User user;
  final String roomId;
  final bool isHost;

  const MultiplayerBlackjackGameScreen({
    super.key,
    required this.user,
    required this.roomId,
    required this.isHost,
  });

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
  StreamSubscription? _insuranceOfferedSub;
  StreamSubscription? _chatMessageSub;

  // UI State
  bool _isConnected = false;
  String _statusMessage = 'Connecting...';
  List<Map<String, dynamic>> _players = [];
  bool _hasShownConnectionDialog = false;
  bool _initialConnectionCheck = true;
  
  // Chat state
  bool _showChat = false;
  int _unreadMessages = 0;
  
  // NEW: Betting menu state
  bool _showBettingMenu = false;
  GameState _gameState = GameState.waiting;

  @override
  void initState() {
    super.initState();
    
    print('🎮 [GAME SCREEN] Initializing...');
    print('   Room ID: ${widget.roomId}');
    print('   Is Host: ${widget.isHost}');
    print('   Socket connected: ${_socketService.isConnected}');
    print('   Current room ID: ${_socketService.currentRoomId}');
    
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
    _game = MultiplayerBlackjackGame(
      user: widget.user,
      roomId: widget.roomId,
      socketService: _socketService,
      onGameStateChanged: _handleGameStateChanged, // NEW: Add callback
    );
    _game.isHost = widget.isHost;
  }

  // NEW: Handle game state changes to show/hide betting menu
  void _handleGameStateChanged(GameState newState) {
    debugPrint('🎮 [SCREEN] Game state changed to: $newState');
    debugPrint('   Is my turn: ${_game.isMyTurn}');
    debugPrint('   Current bet: ${_game.currentBet}');
    
    if (mounted) {
      setState(() {
        _gameState = newState;
        // Show betting menu during betting phase if it's player's turn AND they haven't bet yet
        _showBettingMenu = (newState == GameState.betting && _game.isMyTurn && _game.currentBet == 0);
      });
      
      debugPrint('   Show betting menu: $_showBettingMenu');
    }
  }

  // NEW: Handle bet confirmation from side menu
  void _handleBetConfirmed(double betAmount) {
    debugPrint('💰 [SCREEN] Bet confirmed from side menu: £$betAmount');
    _game.confirmBetFromMenu(betAmount);
    
    // Hide menu immediately
    setState(() {
      _showBettingMenu = false;
    });
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

          _game.removeOtherPlayer(data['userId']);
          _game.playerCount = players.length;
          _game.hud.updateRoomInfo(widget.roomId, players.length, _game.maxPlayers);
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
        
        _showMessage('Game starting!', duration: Duration(seconds: 2));
      }
    });

    // Insurance offered
    _insuranceOfferedSub = _socketService.onInsuranceOffered.listen((data) {
      if (mounted) {
        _showInsuranceDialog();
      }
    });

    // Errors
    _errorSub = _socketService.onError.listen((error) {
      if (mounted) {
        _showError(error);
      }
    });
    
    // Chat messages (for unread badge)
    _chatMessageSub = _socketService.onChatMessage.listen((data) {
      if (!_showChat && mounted) {
        setState(() {
          _unreadMessages++;
        });
      }
    });
  }

  void _showInsuranceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield, color: Colors.amber),
            SizedBox(width: 8),
            Text('Insurance Offered', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dealer is showing an Ace.',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text('Would you like to take insurance?', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💰 Cost: Half your bet',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '💵 Payout: 2:1 if dealer has blackjack',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _socketService.insurance(
                roomId: widget.roomId,
                userId: widget.user.id,
                takeInsurance: false,
              );
              Navigator.of(context).pop();
            },
            child: Text('No Thanks', style: Theme.of(context).textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () {
              _socketService.insurance(
                roomId: widget.roomId,
                userId: widget.user.id,
                takeInsurance: true,
              );
              Navigator.of(context).pop();
              _showMessage('Insurance taken', duration: Duration(seconds: 2));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: AppColors.primaryNavyDark,
            ),
            child: Text('Take Insurance', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: AppColors.primaryNavyLight,
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
    print('🚪 [GAME SCREEN] Leaving room: ${widget.roomId}');
    print('   Stack trace:');
    print(StackTrace.current);
    
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
    print('🧹 [GAME SCREEN] Disposing - Room: ${widget.roomId}');
    
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    _insuranceOfferedSub?.cancel();
    _chatMessageSub?.cancel();
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
        appBar: AppBar(
          toolbarHeight: 30,
          backgroundColor: AppColors.primaryNavyDark,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () async {
              final shouldLeave = await _showLeaveConfirmation();
              if (shouldLeave) {
                _leaveRoom();
              }
            },
          ),
          title: Row(
            children: [
              // Connection indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? AppColors.success : Colors.red,
                  boxShadow: [
                    if (_isConnected)
                      BoxShadow(
                        color: AppColors.primaryNavyLight.withValues(alpha: 0.5),
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
                    fontFamily: 'Inter',
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavyLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.amber,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '£${_game.bankroll.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Player count badge
            Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people,
                    color: Colors.amber,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${_players.length}/${_game.maxPlayers}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Chat button with unread badge
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showChat = true;
                      _unreadMessages = 0;
                    });
                  },
                  tooltip: 'Open Chat',
                ),
                // Unread badge
                if (_unreadMessages > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 1.5,
                        ),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textPrimary,
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
        body: Stack(
          children: [
            // Game widget
            GameWidget(game: _game),

            // NEW: Betting side menu (slides in from left)
            if (_showBettingMenu)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: -1.0, end: 0.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(value * (size.width * 0.35), 0),
                      child: child,
                    );
                  },
                  child: BettingSideMenu(
                    currentBankroll: _game.bankroll,
                    minimumBet: 10.0,
                    maximumBet: 500.0,
                    onConfirm: _handleBetConfirmed,
                    onClose: () {
                      // Optional: Allow closing without betting
                      setState(() {
                        _showBettingMenu = false;
                      });
                    },
                  ),
                ),
              ),

            // Connection lost overlay
            if (!_isConnected && !_initialConnectionCheck)
              Positioned.fill(
                child: Container(
                  color: AppColors.primaryNavyDark.withValues(alpha: 0.7),
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
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Trying to reconnect...',
                              style: TextStyle(
                                fontFamily: 'Inter',
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
                              child: Text('Leave Room', style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Chat overlay (shown when chat button is pressed)
            if (_showChat)
              ChatOverlay(
                roomId: widget.roomId,
                userId: widget.user.id,
                username: widget.user.username,
                socketService: _socketService,
                onClose: () {
                  setState(() {
                    _showChat = false;
                  });
                },
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
        title: Text('Leave Game?', style: Theme.of(context).textTheme.bodyMedium),
        content: Text(
          'Are you sure you want to leave this multiplayer game? You will lose your bet if a round is in progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Leave', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    ) ?? false;
  }
}