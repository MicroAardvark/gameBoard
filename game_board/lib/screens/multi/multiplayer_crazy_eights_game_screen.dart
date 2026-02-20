// lib/screens/multiplayer_crazy_eights_game_screen.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_board/widgets/voice_indicator.dart';
import 'dart:async';
import '../../games/multiplayer_crazy_eights_game.dart';
import '../../models/user.dart';
import '../../services/socket_service.dart';
import '../../widgets/chat_overlay.dart';
import '../../theme/app_theme.dart';
import '../../services/voice_chat_service.dart';

/// In-game screen for multiplayer Crazy Eights.
///
/// Wraps [MultiplayerCrazyEightsGame] (the Flame engine) in a Flutter shell
/// that provides:
///   - A transparent top status bar showing connection state, room ID, and
///     the current turn status.
///   - A waiting-room overlay rendered over the Flame canvas before the game
///     begins, including a player-ready list and Ready / Start Game buttons.
///   - A [ChatOverlay] toggled by the chat button.
///   - A [VoiceIndicator] visible when chat is closed.
///
/// The waiting room overlay is dismissed automatically when the game engine
/// transitions out of [GameState.waiting] in response to a server event.
///
/// Crazy Eights has a rich event set — optimistic UI updates for card plays
/// are rolled back via [onCardPlayRejected] if the server rejects a move.
/// Legacy events ([onPlayerTurn], [onJackChoiceNeeded], [onCardsReceived])
/// are still handled alongside newer equivalents to support older server
/// versions during a rollout transition.
class MultiplayerCrazyEightsGameScreen extends StatefulWidget {
  final User   user;
  final String roomId;
  final bool   isHost;

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

  // Socket event subscriptions — all cancelled in dispose().
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _playerLeftSub;
  StreamSubscription? _playerReadySub;
  StreamSubscription? _gameStartingSub;
  StreamSubscription? _gameStartedSub;
  StreamSubscription? _cardPlayedSub;
  StreamSubscription? _cardPlayRejectedSub;   // Optimistic rollback.
  StreamSubscription? _cardDrawnSub;
  StreamSubscription? _cardsDrawnSub;
  StreamSubscription? _turnChangedSub;
  StreamSubscription? _suitChosenSub;
  StreamSubscription? _chooseSuitRequiredSub;
  StreamSubscription? _playerTurnSub;         // Legacy event, still supported.
  StreamSubscription? _crazyEightsCalledSub;
  StreamSubscription? _crazyEightsViolationSub;
  StreamSubscription? _challengeSuccessfulSub;
  StreamSubscription? _jackChoiceNeededSub;   // Legacy event, still supported.
  StreamSubscription? _jackActionChosenSub;
  StreamSubscription? _chooseJackActionRequiredSub;
  StreamSubscription? _cardsReceivedSub;      // Legacy event, still supported.
  StreamSubscription? _gameEndedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _chatMessageSub;

  // Connection and lobby UI state.
  bool   _isConnected             = false;
  String _statusMessage           = 'Connecting...';
  List<Map<String, dynamic>> _players = [];
  bool   _hasShownConnectionDialog = false;

  /// Suppresses the connection-lost overlay for the first 500 ms after entry.
  bool   _initialConnectionCheck  = true;

  // Chat state.
  bool _showChat       = false;
  int  _unreadMessages = 0;

  @override
  void initState() {
    super.initState();

    _voiceService  = VoiceChatService(_socketService);
    _isConnected   = _socketService.isConnected;
    _statusMessage = _isConnected ? 'Connected' : 'Connecting...';

    _initializeGame();
    _setupSocketListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _initialConnectionCheck = false);
    });
  }

  void _initializeGame() {
    _game        = MultiplayerCrazyEightsGame(user: widget.user, roomId: widget.roomId, socketService: _socketService);
    _game.isHost = widget.isHost;
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

    // Player joined — update lobby list and notify the engine.
    _playerJoinedSub = _socketService.onPlayerJoined.listen((data) {
      if (mounted) {
        final players = (data['room']['players'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _players       = players;
          _statusMessage = '${data['player']['username']} joined';
        });

        final player = data['player'];
        if (player['userId'] != widget.user.id) {
          _game.addOtherPlayer(player['userId'], player['username'], player['position']);
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
          _showMessage('Room was closed');
          _leaveRoom();
        }
      }
    });

    // Player ready — reflect updated ready flags in the waiting-room overlay.
    _playerReadySub = _socketService.onPlayerReady.listen((data) {
      if (mounted) {
        setState(() {
          _statusMessage = '${data['username']} is ready';
          final playerId = data['userId'];
          if (_game.otherPlayers.containsKey(playerId)) {
            _game.otherPlayers[playerId]!.setReady(true);
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

    // Game started — the engine receives the dealt cards and transitions state.
    _gameStartedSub = _socketService.onGameStarted.listen((data) {
      if (mounted) {
        _game.handleGameStarted(data);
        setState(() => _statusMessage = 'Game started!');
      }
    });

    // Card played by any player — applies the move in the engine.
    _cardPlayedSub = _socketService.onCardPlayed.listen((data) {
      if (mounted) {
        _game.handleCardPlayed(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    // Card play rejected — rolls back the optimistic UI update.
    _cardPlayRejectedSub = _socketService.onCardPlayRejected.listen((data) {
      if (mounted) {
        _game.handleCardPlayRejected(data);
        setState(() => _statusMessage = _game.statusMessage);
        _showError('Invalid move: ${data['reason']}');
      }
    });

    // Other player drew a card (we only see the count, not the card).
    _cardDrawnSub = _socketService.onCardDrawn.listen((data) {
      if (mounted) {
        _game.handleCardDrawn(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    // Our own drawn cards including full card data.
    _cardsDrawnSub = _socketService.onCardsDrawn.listen((data) {
      if (mounted) {
        _game.handleCardsDrawn(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    _turnChangedSub = _socketService.onTurnChanged.listen((data) {
      if (mounted) {
        _game.handleTurnChanged(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    _suitChosenSub = _socketService.onSuitChosen.listen((data) {
      if (mounted) {
        _game.handleSuitChosen(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    _chooseSuitRequiredSub = _socketService.onChooseSuitRequired.listen((data) {
      if (mounted) {
        _game.handleChooseSuitRequired(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    // Legacy turn event — still fired by some server versions.
    _playerTurnSub = _socketService.onPlayerTurn.listen((data) {
      if (mounted) {
        _game.handlePlayerTurn(data);
        setState(() {
          _statusMessage = data['userId'] == widget.user.id
              ? 'Your turn!'
              : '${data['username']}\'s turn';
        });
      }
    });

    // Crazy Eights called — announce to all players.
    _crazyEightsCalledSub = _socketService.onCrazyEightsCalled.listen((data) {
      if (mounted) {
        _game.handleCrazyEightsCalled(data);
        setState(() => _statusMessage = '🎯 ${data['username']} called Crazy Eights!');
        _showMessage('${data['username']} called Crazy Eights!');
      }
    });

    // Violation — player forgot to call Crazy Eights before their turn ended.
    _crazyEightsViolationSub = _socketService.onCrazyEightsViolation.listen((data) {
      if (mounted) {
        _game.handleCrazyEightsViolation(data);
        setState(() => _statusMessage = '⚠️ ${data['username']} forgot to call Crazy Eights!');
      }
    });

    // Successful challenge — target draws 2 penalty cards.
    _challengeSuccessfulSub = _socketService.onChallengeSuccessful.listen((data) {
      if (mounted) {
        setState(() => _statusMessage = '✅ ${data['challengerName']} challenged ${data['targetName']}!');
        _showMessage('Challenge successful! ${data['targetName']} drew 2 cards');
      }
    });

    // Legacy Jack choice event.
    _jackChoiceNeededSub = _socketService.onJackChoiceNeeded.listen((data) {
      if (mounted) {
        _game.handleJackChoiceNeeded(data);
        if (data['userId'] == widget.user.id) {
          setState(() => _statusMessage = 'Choose Jack action: Skip or Reverse?');
        }
      }
    });

    _jackActionChosenSub = _socketService.onJackActionChosen.listen((data) {
      if (mounted) {
        _game.handleJackActionChosen(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    _chooseJackActionRequiredSub = _socketService.onChooseJackActionRequired.listen((data) {
      if (mounted) {
        _game.handleChooseJackActionRequired(data);
        setState(() => _statusMessage = _game.statusMessage);
      }
    });

    // Legacy cards-received event.
    _cardsReceivedSub = _socketService.onCardsReceived.listen((data) {
      if (mounted) _game.handleCardsReceived(data);
    });

    // Game-ended event arrives via onGameAction with type == 'game_ended'.
    _gameEndedSub = _socketService.onGameAction.listen((event) {
      if (event['type'] != 'game_ended' || !mounted) return;
      final data = event['data'];
      _game.handleGameEnded(data);
      setState(() {
        _statusMessage = data['winnerId'] == widget.user.id
            ? '🏆 YOU WIN!'
            : '${data['winnerName']} wins!';
      });
    });

    _chatMessageSub = _socketService.onChatMessage.listen((_) {
      if (mounted && !_showChat) setState(() => _unreadMessages++);
    });

    _errorSub = _socketService.onError.listen((error) {
      if (mounted) _showError(error);
    });
  }

  /// Toggles this player's ready state in the waiting room.
  void _toggleReady() {
    if (_game.isReady) {
      _socketService.playerUnready(roomId: widget.roomId, userId: widget.user.id);
      _game.isReady = false;
    } else {
      _socketService.playerReady(roomId: widget.roomId, userId: widget.user.id);
      _game.isReady = true;
    }
    setState(() {});
  }

  /// Host-only: starts the game once all players are ready.
  void _startGame() {
    if (!widget.isHost)            { _showError('Only the host can start the game'); return; }
    if (_players.length < 2)       { _showError('Need at least 2 players to start'); return; }
    if (!_players.every((p) => p['isReady'] == true)) { _showError('All players must be ready'); return; }
    _socketService.startCrazyEights(roomId: widget.roomId);
  }

  void _leaveRoom() {
    _socketService.leaveRoom(roomId: widget.roomId, userId: widget.user.id);
    Navigator.of(context).pop();
  }

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
      if (_showChat) _unreadMessages = 0;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
      backgroundColor: AppColors.primaryNavyLight,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error, style: const TextStyle(fontFamily: 'Inter')),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    _playerJoinedSub?.cancel();
    _playerLeftSub?.cancel();
    _playerReadySub?.cancel();
    _gameStartingSub?.cancel();
    _gameStartedSub?.cancel();
    _cardPlayedSub?.cancel();
    _cardPlayRejectedSub?.cancel();
    _cardDrawnSub?.cancel();
    _cardsDrawnSub?.cancel();
    _turnChangedSub?.cancel();
    _suitChosenSub?.cancel();
    _chooseSuitRequiredSub?.cancel();
    _playerTurnSub?.cancel();
    _crazyEightsCalledSub?.cancel();
    _crazyEightsViolationSub?.cancel();
    _challengeSuccessfulSub?.cancel();
    _jackChoiceNeededSub?.cancel();
    _jackActionChosenSub?.cancel();
    _chooseJackActionRequiredSub?.cancel();
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
          // Base Flame canvas.
          GameWidget(game: _game),

          // Transparent status bar overlaid at the top of the canvas.
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    // Back button triggers leave-confirmation dialog.
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppColors.primaryNavyDark,
                          title: Text('Leave Game?', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary)),
                          content: Text('Are you sure you want to leave?', style: TextStyle(fontFamily: 'Inter', color: Colors.grey[400])),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter'))),
                            ElevatedButton(
                              onPressed: () { Navigator.pop(context); _leaveRoom(); },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Leave', style: TextStyle(fontFamily: 'Inter')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Truncated room ID — shows last 8 chars to keep the bar concise.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room: ${widget.roomId.split('_').last.substring(0, 8)}',
                            style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(_statusMessage, style: TextStyle(fontFamily: 'Inter', color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                    // Connection pill.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chat button with unread badge.
                    Stack(
                      children: [
                        IconButton(icon: const Icon(Icons.chat, color: Colors.white), onPressed: _toggleChat),
                        if (_unreadMessages > 0)
                          Positioned(
                            right: 8, top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text('$_unreadMessages', style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Waiting-room overlay — covers the canvas until the game begins.
          // Dismissed automatically when _game.gameState leaves waiting.
          if (_game.gameState == GameState.waiting)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Player ready list.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavyDark.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: _players.map((player) {
                            final isReady = player['isReady'] == true;
                            final isMe    = player['userId'] == widget.user.id;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(isReady ? Icons.check_circle : Icons.circle_outlined, color: isReady ? Colors.green : Colors.grey, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${player['username']}${isMe ? ' (You)' : ''}',
                                    style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14, fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Ready toggle and host-only start button.
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleReady,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _game.isReady ? Colors.orange : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(_game.isReady ? 'Not Ready' : 'Ready', style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (widget.isHost) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text('Start Game', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavyDark)),
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

          // Chat overlay.
          if (_showChat)
            ChatOverlay(
              roomId: widget.roomId, userId: widget.user.id, username: widget.user.username,
              socketService: _socketService, voiceService: _voiceService, onClose: _toggleChat,
            ),

          // Voice indicator — tapping opens chat.
          if (!_showChat)
            VoiceIndicator(voiceService: _voiceService, onTap: () => setState(() => _showChat = true)),
        ],
      ),
    );
  }
}

/// Local game state enum for driving the waiting-room overlay visibility.
///
/// TODO: Replace this with the shared enum from enums.dart to avoid
/// duplication — this local definition will shadow the imported one if both
/// are ever imported into the same file.
enum GameState { waiting, playing, finished }