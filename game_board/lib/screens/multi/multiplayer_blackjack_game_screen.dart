// lib/screens/multiplayer_blackjack_game_screen.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_board/services/voice_chat_service.dart';
import 'package:game_board/widgets/voice_indicator.dart';
import 'dart:async';
import '../../games/multiplayer_blackjack_game.dart';
import '../../models/user.dart';
import '../../models/enums.dart';
import '../../services/socket_service.dart';
import '../../widgets/chat_overlay.dart';
import '../../widgets/betting_side_menu.dart';
import '../../theme/app_theme.dart';

/// In-game screen for multiplayer Blackjack.
///
/// Wraps [MultiplayerBlackjackGame] (the Flame engine) in a thin Flutter shell
/// that provides:
///   - A slim AppBar showing connection status, live bankroll, and player count.
///   - A [BettingSideMenu] that slides in from the left during the betting phase.
///   - A [ChatOverlay] toggled by the AppBar chat button.
///   - A [VoiceIndicator] visible whenever chat is closed.
///   - A full-screen "connection lost" overlay while the socket is disconnected.
///   - A leave-confirmation dialog intercepting both the back gesture and button.
///
/// The betting menu is driven by [_handleGameStateChanged], a callback passed
/// into the game engine. This keeps menu visibility in sync with engine state
/// and prevents the menu appearing when it is not the local player's turn or
/// they have already placed a bet.
class MultiplayerBlackjackGameScreen extends StatefulWidget {
  final User   user;
  final String roomId;
  final bool   isHost;

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
  late final VoiceChatService _voiceService;

  // Socket event subscriptions — all cancelled in dispose().
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _playerLeftSub;
  StreamSubscription? _playerReadySub;
  StreamSubscription? _gameStartingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _insuranceOfferedSub;
  StreamSubscription? _chatMessageSub;

  // Connection UI state.
  bool   _isConnected              = false;
  String _statusMessage            = 'Connecting...';
  bool   _hasShownConnectionDialog = false;

  /// True for the first 500 ms so that a momentary disconnect on entry does
  /// not immediately show the "connection lost" overlay.
  bool   _initialConnectionCheck  = true;

  // Player roster displayed in the AppBar player-count badge.
  List<Map<String, dynamic>> _players = [];

  // Chat state.
  bool _showChat       = false;
  int  _unreadMessages = 0;

  // Betting side menu state.
  bool      _showBettingMenu = false;
  GameState _gameState       = GameState.waiting;

  @override
  void initState() {
    super.initState();

    _isConnected  = _socketService.isConnected;
    _statusMessage = _isConnected ? 'Connected' : 'Connecting...';
    _voiceService = VoiceChatService(_socketService);

    _initializeGame();
    _setupSocketListeners();

    // Suppress the "connection lost" overlay during the initial handshake window.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _initialConnectionCheck = false);
    });
  }

  void _initializeGame() {
    _game = MultiplayerBlackjackGame(
      user:               widget.user,
      roomId:             widget.roomId,
      socketService:      _socketService,
      onGameStateChanged: _handleGameStateChanged,
    );
    _game.isHost = widget.isHost;
  }

  /// Receives game-state updates from the Flame engine and drives betting menu
  /// visibility. The menu is shown only when:
  ///   - It is the betting phase.
  ///   - It is this player's turn to bet.
  ///   - This player has not yet placed a bet (currentBet == 0).
  void _handleGameStateChanged(GameState newState) {
    if (mounted) {
      setState(() {
        _gameState       = newState;
        _showBettingMenu = newState == GameState.betting &&
                           _game.isMyTurn &&
                           _game.currentBet == 0;
      });
    }
  }

  /// Relays the confirmed bet amount to the game engine and immediately
  /// hides the side menu to prevent double-submission.
  void _handleBetConfirmed(double betAmount) {
    _game.confirmBetFromMenu(betAmount);
    setState(() => _showBettingMenu = false);
  }

  void _setupSocketListeners() {
    // Connection status.
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected  = connected;
          _statusMessage = connected ? 'Connected' : 'Disconnected';
        });
        if (!connected && !_initialConnectionCheck) _hasShownConnectionDialog = true;
        else if (connected)                          _hasShownConnectionDialog = false;
      }
    });

    // Player joined — update roster and notify the game engine.
    _playerJoinedSub = _socketService.onPlayerJoined.listen((data) {
      if (mounted) {
        final players = (data['room']['players'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _players       = players;
          _statusMessage = '${data['player']['username']} joined';
        });

        final player = data['player'];
        if (player['userId'] != widget.user.id) {
          _game.addOtherPlayer(
            player['userId'],
            player['username'],
            (player['bankroll'] as num).toDouble(),
            player['position'],
          );
        }
        _game.playerCount = players.length;
      }
    });

    // Player left — update roster or close the room.
    _playerLeftSub = _socketService.onPlayerLeft.listen((data) {
      if (mounted) {
        final room = data['room'];
        if (room != null) {
          final players = (room['players'] as List).cast<Map<String, dynamic>>();
          setState(() {
            _players       = players;
            _statusMessage = '${data['username']} left';
          });
          _game.removeOtherPlayer(data['userId']);
          _game.playerCount = players.length;
        } else {
          // Null room means the host closed it — return to the lobby.
          _showMessage('Room was closed');
          _leaveRoom();
        }
      }
    });

    // Player ready — update the opponent's ready indicator in the engine.
    _playerReadySub = _socketService.onPlayerReady.listen((data) {
      if (mounted) {
        setState(() => _statusMessage = '${data['username']} is ready');
        final playerId = data['userId'];
        if (_game.otherPlayers.containsKey(playerId)) {
          _game.otherPlayers[playerId]!.setReady(true);
        }
      }
    });

    // Game starting notification — show a brief toast.
    _gameStartingSub = _socketService.onGameStarting.listen((data) {
      if (mounted) {
        setState(() => _statusMessage = 'Game starting!');
        _showMessage('Game starting!', duration: const Duration(seconds: 2));
      }
    });

    // Insurance offered — show a modal decision dialog.
    _insuranceOfferedSub = _socketService.onInsuranceOffered.listen((_) {
      if (mounted) _showInsuranceDialog();
    });

    _errorSub = _socketService.onError.listen((error) {
      if (mounted) _showError(error);
    });

    // Track unread messages for the chat badge while the overlay is closed.
    _chatMessageSub = _socketService.onChatMessage.listen((_) {
      if (!_showChat && mounted) setState(() => _unreadMessages++);
    });
  }

  /// Insurance decision dialog shown when the dealer reveals an Ace.
  ///
  /// [barrierDismissible] is false because skipping the dialog would leave the
  /// server waiting indefinitely for an insurance response.
  void _showInsuranceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Insurance Offered', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dealer is showing an Ace.', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Text('Would you like to take insurance?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💰 Cost: Half your bet',             style: TextStyle(fontSize: 14)),
                  SizedBox(height: 4),
                  Text('💵 Payout: 2:1 if dealer has blackjack', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _socketService.insurance(roomId: widget.roomId, userId: widget.user.id, takeInsurance: false);
              Navigator.of(context).pop();
            },
            child: Text('No Thanks', style: Theme.of(context).textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () {
              _socketService.insurance(roomId: widget.roomId, userId: widget.user.id, takeInsurance: true);
              Navigator.of(context).pop();
              _showMessage('Insurance taken', duration: const Duration(seconds: 2));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: AppColors.primaryNavyDark),
            child: Text('Take Insurance', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: duration, backgroundColor: AppColors.primaryNavyLight));
  }

  void _showError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), duration: const Duration(seconds: 5), backgroundColor: Colors.red.shade700));
  }

  /// Emits a leaveRoom event and pops the route. Calling leaveRoom here
  /// rather than in dispose() gives the server a chance to cleanly remove
  /// the player before the socket listener is cancelled.
  void _leaveRoom() {
    _socketService.leaveRoom(roomId: widget.roomId, userId: widget.user.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    _insuranceOfferedSub?.cancel();
    _chatMessageSub?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size        = MediaQuery.of(context).size;
    final buttonSize  = (size.height * 0.06).clamp(32.0, 48.0);
    final topPadding  = size.height * 0.02;
    final leftPadding = size.width  * 0.02;

    // WillPopScope intercepts the Android back gesture so it goes through the
    // same leave-confirmation dialog as the AppBar back button.
    return WillPopScope(
      onWillPop: () async {
        final shouldLeave = await _showLeaveConfirmation();
        if (shouldLeave) _leaveRoom();
        return false; // Always return false; _leaveRoom() pops manually.
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 30,
          backgroundColor: AppColors.primaryNavyDark,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            onPressed: () async {
              if (await _showLeaveConfirmation()) _leaveRoom();
            },
          ),
          title: Row(
            children: [
              // Connection status dot — glowing when connected.
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? AppColors.success : Colors.red,
                  boxShadow: [
                    if (_isConnected)
                      BoxShadow(color: AppColors.primaryNavyLight.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Live bankroll badge.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavyLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text('£${_game.bankroll.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Player-count badge.
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text('${_players.length}/${_game.maxPlayers}', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // Chat button with unread badge.
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble, color: AppColors.textPrimary),
                  onPressed: () => setState(() { _showChat = true; _unreadMessages = 0; }),
                  tooltip: 'Open Chat',
                ),
                if (_unreadMessages > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textPrimary, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                        style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
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
            // Base game canvas.
            GameWidget(game: _game),

            // Betting side menu — slides in from the left during betting phase.
            // Only shown when it is this player's turn and they have not yet bet.
            if (_showBettingMenu)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: -1.0, end: 0.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(value * (size.width * 0.35), 0),
                    child: child,
                  ),
                  child: BettingSideMenu(
                    currentBankroll: _game.bankroll,
                    minimumBet: 10.0,
                    maximumBet: 500.0,
                    onConfirm: _handleBetConfirmed,
                    // Allow dismissing without betting — the server will apply
                    // the minimum bet automatically if the player times out.
                    onClose: () => setState(() => _showBettingMenu = false),
                  ),
                ),
              ),

            // Full-screen overlay shown while the socket is disconnected.
            // Suppressed during _initialConnectionCheck to avoid a flash on entry.
            if (!_isConnected && !_initialConnectionCheck)
              Positioned.fill(
                child: Container(
                  color: AppColors.primaryNavyDark.withValues(alpha: 0.7),
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.all(32),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.red, size: 64),
                            const SizedBox(height: 16),
                            const Text('Connection Lost', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Trying to reconnect...', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.grey[600])),
                            const SizedBox(height: 24),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _leaveRoom,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: Text('Leave Room', style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Chat overlay — covers the game canvas when open.
            if (_showChat)
              ChatOverlay(
                roomId:        widget.roomId,
                userId:        widget.user.id,
                username:      widget.user.username,
                socketService: _socketService,
                voiceService:  _voiceService,
                onClose: () => setState(() => _showChat = false),
              ),

            // Voice indicator shown when chat is closed; tapping opens chat.
            if (!_showChat)
              VoiceIndicator(
                voiceService: _voiceService,
                onTap: () => setState(() => _showChat = true),
              ),
          ],
        ),
      ),
    );
  }

  /// Confirms the player wants to forfeit their current round bet before leaving.
  Future<bool> _showLeaveConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Game?', style: Theme.of(context).textTheme.bodyMedium),
        content: const Text('Are you sure you want to leave this multiplayer game? You will lose your bet if a round is in progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Leave', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    ) ?? false;
  }
}