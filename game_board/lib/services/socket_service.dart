// ====================================
// lib/services/socket_service.dart
// Universal multiplayer socket service for all games + CHAT
// UPDATED: Added optimistic UI event handlers
// FIXED: Normalise Crazy Eights rank strings before sending to server ("six" -> "6", etc.)
// ====================================
// ignore_for_file: avoid_print

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // Socket instance
  io.Socket? _socket;

  // IMPORTANT: Replace with your server IP/URL
  final String baseUrl = 'https://microaardvark.co.uk';

  // Stream controllers for different events
  final _roomCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerReadyController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStartingController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameActionController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _insuranceOfferedController = StreamController<Map<String, dynamic>>.broadcast();
  final _newRoundStartingController = StreamController<Map<String, dynamic>>.broadcast();

  // Chat-specific stream controllers
  final _chatHistoryController = StreamController<Map<String, dynamic>>.broadcast();
  final _userTypingController = StreamController<Map<String, dynamic>>.broadcast();

  // Crazy Eights stream controllers (UPDATED FOR OPTIMISTIC UI)
  final _gameStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _cardPlayedController = StreamController<Map<String, dynamic>>.broadcast();
  final _cardPlayRejectedController = StreamController<Map<String, dynamic>>.broadcast(); // NEW
  final _cardDrawnController = StreamController<Map<String, dynamic>>.broadcast();
  final _cardsDrawnController = StreamController<Map<String, dynamic>>.broadcast(); // NEW (my cards)
  final _playerTurnController = StreamController<Map<String, dynamic>>.broadcast();
  final _turnChangedController = StreamController<Map<String, dynamic>>.broadcast(); // NEW
  final _suitChosenController = StreamController<Map<String, dynamic>>.broadcast(); // NEW
  final _chooseSuitRequiredController = StreamController<Map<String, dynamic>>.broadcast(); // NEW
  final _crazyEightsCalledController = StreamController<Map<String, dynamic>>.broadcast();
  final _crazyEightsViolationController = StreamController<Map<String, dynamic>>.broadcast();
  final _challengeSuccessfulController = StreamController<Map<String, dynamic>>.broadcast();
  final _jackChoiceNeededController = StreamController<Map<String, dynamic>>.broadcast();
  final _jackActionChosenController = StreamController<Map<String, dynamic>>.broadcast();
  final _chooseJackActionRequiredController = StreamController<Map<String, dynamic>>.broadcast(); // NEW
  final _cardsReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get onRoomCreated => _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined => _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft => _playerLeftController.stream;
  Stream<Map<String, dynamic>> get onPlayerReady => _playerReadyController.stream;
  Stream<Map<String, dynamic>> get onGameStarting => _gameStartingController.stream;
  Stream<Map<String, dynamic>> get onGameAction => _gameActionController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onInsuranceOffered => _insuranceOfferedController.stream;
  Stream<Map<String, dynamic>> get onNewRoundStarting => _newRoundStartingController.stream;

  // Chat stream getters
  Stream<Map<String, dynamic>> get onChatHistory => _chatHistoryController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  // Crazy Eights stream getters (UPDATED FOR OPTIMISTIC UI)
  Stream<Map<String, dynamic>> get onGameStarted => _gameStartedController.stream;
  Stream<Map<String, dynamic>> get onCardPlayed => _cardPlayedController.stream;
  Stream<Map<String, dynamic>> get onCardPlayRejected => _cardPlayRejectedController.stream; // NEW
  Stream<Map<String, dynamic>> get onCardDrawn => _cardDrawnController.stream;
  Stream<Map<String, dynamic>> get onCardsDrawn => _cardsDrawnController.stream; // NEW
  Stream<Map<String, dynamic>> get onPlayerTurn => _playerTurnController.stream;
  Stream<Map<String, dynamic>> get onTurnChanged => _turnChangedController.stream; // NEW
  Stream<Map<String, dynamic>> get onSuitChosen => _suitChosenController.stream; // NEW
  Stream<Map<String, dynamic>> get onChooseSuitRequired => _chooseSuitRequiredController.stream; // NEW
  Stream<Map<String, dynamic>> get onCrazyEightsCalled => _crazyEightsCalledController.stream;
  Stream<Map<String, dynamic>> get onCrazyEightsViolation => _crazyEightsViolationController.stream;
  Stream<Map<String, dynamic>> get onChallengeSuccessful => _challengeSuccessfulController.stream;
  Stream<Map<String, dynamic>> get onJackChoiceNeeded => _jackChoiceNeededController.stream;
  Stream<Map<String, dynamic>> get onJackActionChosen => _jackActionChosenController.stream;
  Stream<Map<String, dynamic>> get onChooseJackActionRequired => _chooseJackActionRequiredController.stream; // NEW
  Stream<Map<String, dynamic>> get onCardsReceived => _cardsReceivedController.stream;

  // Connection state
  bool get isConnected => _socket?.connected ?? false;
  String? currentRoomId;
  String? currentUserId;
  String? currentUsername;

  // ===========================================
  // CONNECTION MANAGEMENT
  // ===========================================

  void connect(String userId, String username) {
    if (_socket != null && _socket!.connected) {
      print('✅ Already connected to server');
      return;
    }

    currentUserId = userId;
    currentUsername = username;

    print('🔌 Connecting to: $baseUrl');
    print('   User ID: $userId');

    _socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'auth': {
        'userId': userId,
        'username': username,
      },
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket!.onConnect((_) {
      print('✅ Connected to server');
      _connectionController.add(true);

      // Rejoin room if we were in one
      if (currentRoomId != null) {
        print('🔄 Rejoining room: $currentRoomId');
        joinRoom(
          roomId: currentRoomId!,
          userId: userId,
          username: username,
        );
      }
    });

    _socket!.onDisconnect((_) {
      print('❌ Disconnected from server');
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      print('❌ Connection error: $error');
      _connectionController.add(false);
    });

    _socket!.onReconnect((attempt) {
      print('🔄 Reconnected after $attempt attempts');
      _connectionController.add(true);
    });

    _setupSocketListeners();
  }

  void disconnect() {
    print('🔌 Disconnecting from server');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    currentRoomId = null;
    _connectionController.add(false);
  }

  // ===========================================
  // EVENT LISTENERS SETUP
  // ===========================================

  void _setupSocketListeners() {
    if (_socket == null) return;

    // Welcome message
    _socket!.on('welcome', (data) {
      print('👋 ${data['message']}');
    });

    // Room events
    _socket!.on('room_created', (data) {
      print('📝 Room created: ${data['roomId']}');
      currentRoomId = data['roomId'];
      _roomCreatedController.add(data);
    });

    _socket!.on('player_joined', (data) {
      print('👤 Player joined: ${data['player']['username']}');
      _playerJoinedController.add(data);
    });

    _socket!.on('player_left', (data) {
      print('👋 Player left: ${data['username']}');
      _playerLeftController.add(data);
    });

    _socket!.on('player_ready_update', (data) {
      print('✅ Player ready: ${data['username']}');
      _playerReadyController.add(data);
    });

    _socket!.on('game_starting', (data) {
      print('🎮 Game starting!');
      _gameStartingController.add(data);
    });

    _socket!.on('rejoined_room', (data) {
      print('🔄 Rejoined room successfully');
      currentRoomId = data['roomId'];
      _roomCreatedController.add(data);
    });

    _socket!.on('player_reconnected', (data) {
      print('🔄 Player reconnected: ${data['username']}');
      _playerJoinedController.add(data);
    });

    _socket!.on('player_disconnected', (data) {
      print('⚠️ Player disconnected: ${data['username']}');
      _playerLeftController.add(data);
    });

    _socket!.on('player_removed', (data) {
      print('🗑️ Player removed: ${data['username']} - ${data['reason']}');
      _playerLeftController.add(data);
    });

    // Blackjack-specific events
    _socket!.on('bet_placed', (data) {
      _gameActionController.add({'type': 'bet_placed', 'data': data});
    });

    _socket!.on('round_started', (data) {
      _gameActionController.add({'type': 'round_started', 'data': data});
    });

    _socket!.on('card_dealt', (data) {
      _gameActionController.add({'type': 'card_dealt', 'data': data});
    });

    _socket!.on('player_busted', (data) {
      _gameActionController.add({'type': 'player_busted', 'data': data});
    });

    _socket!.on('player_stood', (data) {
      _gameActionController.add({'type': 'player_stood', 'data': data});
    });

    _socket!.on('doubled_down', (data) {
      _gameActionController.add({'type': 'doubled_down', 'data': data});
    });

    _socket!.on('hand_split', (data) {
      _gameActionController.add({'type': 'hand_split', 'data': data});
    });

    _socket!.on('insurance_offered', (data) {
      print('🛡️ Insurance offered');
      _insuranceOfferedController.add(data);
      _gameActionController.add({'type': 'insurance_offered', 'data': data});
    });

    _socket!.on('insurance_taken', (data) {
      _gameActionController.add({'type': 'insurance_taken', 'data': data});
    });

    _socket!.on('player_blackjack', (data) {
      _gameActionController.add({'type': 'player_blackjack', 'data': data});
    });

    _socket!.on('next_player_turn', (data) {
      _gameActionController.add({'type': 'next_player_turn', 'data': data});
    });

    _socket!.on('next_player_bet_turn', (data) {
      print('➡️ Next player bet turn: ${data['username']}');
      _gameActionController.add({'type': 'next_player_bet_turn', 'data': data});
    });

    _socket!.on('all_bets_placed', (data) {
      print('✅ All bets placed!');
      _gameActionController.add({'type': 'all_bets_placed', 'data': data});
    });

    _socket!.on('dealer_reveal', (data) {
      _gameActionController.add({'type': 'dealer_reveal', 'data': data});
    });

    _socket!.on('dealer_card', (data) {
      _gameActionController.add({'type': 'dealer_card', 'data': data});
    });

    _socket!.on('round_ended', (data) {
      _gameActionController.add({'type': 'round_ended', 'data': data});
    });

    // Ready for next round
    _socket!.on('new_round_starting', (data) {
      print('🔄 New round starting');
      _newRoundStartingController.add(data);
    });

    // Chat events
    _socket!.on('chat_message', (data) {
      print('💬 ${data['username']}: ${data['message']}');
      _chatMessageController.add(data);
    });

    // Chat history event
    _socket!.on('chat_history', (data) {
      print('📜 Received ${data['messages'].length} chat messages');
      _chatHistoryController.add(data);
    });

    // Typing indicator event
    _socket!.on('user_typing', (data) {
      print('⌨️ ${data['username']} is ${data['isTyping'] ? "typing" : "stopped typing"}');
      _userTypingController.add(data);
    });

    // ===================================
    // CRAZY EIGHTS EVENTS (UPDATED FOR OPTIMISTIC UI)
    // ===================================

    _socket!.on('game_started', (data) {
      print('🎮 Crazy Eights game started!');
      _gameStartedController.add(data);
    });

    _socket!.on('card_played', (data) {
      print('🃏 Card played by: ${data['userId']}');
      _cardPlayedController.add(data);
    });

    // NEW: Card play rejected (optimistic update rollback)
    _socket!.on('card_play_rejected', (data) {
      print('❌ Card play rejected: ${data['reason']}');
      _cardPlayRejectedController.add(data);
    });

    _socket!.on('card_drawn', (data) {
      print('📥 Other player drew: ${data['userId']} drew ${data['count']} card(s)');
      _cardDrawnController.add(data);
    });

    // NEW: Cards drawn (my cards with card data)
    _socket!.on('cards_drawn', (data) {
      print('📨 I received ${data['cards'].length} card(s)');
      _cardsDrawnController.add(data);
    });

    // NEW: Turn changed event
    _socket!.on('turn_changed', (data) {
      print('🔄 Turn changed to: ${data['currentTurn']}');
      _turnChangedController.add(data);
    });

    // NEW: Suit chosen event
    _socket!.on('suit_chosen', (data) {
      print('👑 Suit chosen: ${data['suit']} by ${data['userId']}');
      _suitChosenController.add(data);
    });

    // NEW: Choose suit required event
    _socket!.on('choose_suit_required', (data) {
      print('👑 Choose suit required');
      _chooseSuitRequiredController.add(data);
    });

    _socket!.on('player_turn', (data) {
      print('👤 Player turn: ${data['username']}');
      _playerTurnController.add(data);
    });

    _socket!.on('crazy_eights_called', (data) {
      print('🎯 Crazy Eights called by: ${data['userId']}');
      _crazyEightsCalledController.add(data);
    });

    _socket!.on('crazy_eights_violation', (data) {
      print('⚠️ Crazy Eights violation: ${data['username']}');
      _crazyEightsViolationController.add(data);
    });

    _socket!.on('challenge_successful', (data) {
      print('✅ Challenge successful');
      _challengeSuccessfulController.add(data);
    });

    _socket!.on('challenge_failed', (data) {
      print('❌ Challenge failed');
      _challengeSuccessfulController.add(data);
    });

    _socket!.on('jack_choice_needed', (data) {
      print('🃏 Jack choice needed');
      _jackChoiceNeededController.add(data);
    });

    _socket!.on('jack_action_chosen', (data) {
      print('🃏 Jack action chosen: ${data['action']}');
      _jackActionChosenController.add(data);
    });

    // NEW: Choose Jack action required event
    _socket!.on('choose_jack_action_required', (data) {
      print('🃏 Choose Jack action required');
      _chooseJackActionRequiredController.add(data);
    });

    _socket!.on('cards_received', (data) {
      print('📨 Cards received: ${data['cards'].length} card(s)');
      _cardsReceivedController.add(data);
    });

    _socket!.on('game_ended', (data) {
      print('🏆 Game ended! Winner: ${data['winnerName']}');
      _gameActionController.add({'type': 'game_ended', 'data': data});
    });

    // Error handling
    _socket!.on('error', (data) {
      print('❌ Server error: ${data['message']}');
      _errorController.add(data['message'] ?? 'Unknown error');
    });

    // Pong response
    _socket!.on('pong', (data) {
      print('🏓 Pong received at ${data['timestamp']}');
    });
  }

  // ===========================================
  // ROOM MANAGEMENT
  // ===========================================

  void createRoom({
    required String userId,
    required String username,
    required String gameType,
    int maxPlayers = 3,
  }) {
    if (!isConnected) {
      print('❌ Not connected to server');
      return;
    }

    print('📝 Creating $gameType room...');

    _socket!.emit('create_room', {
      'userId': userId,
      'username': username,
      'gameType': gameType,
      'maxPlayers': maxPlayers,
    });
  }

  void joinRoom({
    required String roomId,
    required String userId,
    required String username,
  }) {
    if (!isConnected) {
      print('❌ Not connected to server');
      return;
    }

    print('👤 Joining room: $roomId');

    _socket!.emit('join_room', {
      'roomId': roomId,
      'userId': userId,
      'username': username,
    });
  }

  void leaveRoom({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) return;

    print('👋 Leaving room: $roomId');

    _socket!.emit('leave_room', {
      'roomId': roomId,
      'userId': userId,
    });

    currentRoomId = null;
  }

  void playerReady({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) return;

    print('✅ Player ready in room: $roomId');

    _socket!.emit('player_ready', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  void playerUnready({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) return;

    print('⏸️ Player unready in room: $roomId');

    _socket!.emit('player_unready', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  void playerReadyNextRound({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('✅ Player ready for next round');

    _socket!.emit('player_ready_next_round', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  // ===========================================
  // GAME ACTIONS (Universal)
  // ===========================================

  void sendGameAction({
    required String roomId,
    required String action,
    required Map<String, dynamic> payload,
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('🎮 Game action: $action');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': action,
      'payload': payload,
    });
  }

  // ===========================================
  // BLACKJACK CONVENIENCE METHODS
  // ===========================================

  void placeBet({
    required String roomId,
    required String userId,
    required double betAmount,
  }) {
    sendGameAction(
      roomId: roomId,
      action: 'place_bet',
      payload: {'userId': userId, 'betAmount': betAmount},
    );
  }

  void startRound({required String roomId}) {
    sendGameAction(
      roomId: roomId,
      action: 'start_round',
      payload: {},
    );
  }

  void hit({
    required String roomId,
    required String userId,
  }) {
    sendGameAction(
      roomId: roomId,
      action: 'hit',
      payload: {'userId': userId},
    );
  }

  void stand({
    required String roomId,
    required String userId,
  }) {
    sendGameAction(
      roomId: roomId,
      action: 'stand',
      payload: {'userId': userId},
    );
  }

  void doubleDown({
    required String roomId,
    required String userId,
  }) {
    sendGameAction(
      roomId: roomId,
      action: 'double_down',
      payload: {'userId': userId},
    );
  }

  void split({
    required String roomId,
    required String userId,
  }) {
    sendGameAction(
      roomId: roomId,
      action: 'split',
      payload: {'userId': userId},
    );
  }

  void insurance({
    required String roomId,
    required String userId,
    required bool takeInsurance,
  }) {
    sendGameAction(
      roomId: roomId,
      action: 'insurance',
      payload: {'userId': userId, 'takeInsurance': takeInsurance},
    );
  }

  // ===========================================
  // CRAZY EIGHTS GAME ACTIONS (UPDATED FOR OPTIMISTIC UI)
  // ===========================================

  void startCrazyEights({
    required String roomId,
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('🎮 Starting Crazy Eights game');

    _socket!.emit('game_action', {
      'action': 'start_game',
      'roomId': roomId,
      'payload': {
        'roomId': roomId,
      },
    });
  }

  /// UPDATED: Play card with card identity support for optimistic UI
  void playCard({
    required String roomId,
    required String userId,
    required int cardIndex,
    required String cardSuit,
    required String cardRank,
    String? chosenSuit, // For King/Ace suit choice
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    final normalisedRank = _normaliseCrazyEightsRank(cardRank);
    print('🃏 Playing card: $normalisedRank of $cardSuit (index: $cardIndex)');

    final payload = <String, dynamic>{
      'userId': userId,
      'cardIndex': cardIndex,
      'cardSuit': cardSuit,
      'cardRank': normalisedRank,
      'card': {
        'suit': cardSuit,
        'rank': normalisedRank,
      },
    };

    // Add chosen suit if provided (for King/Ace played with suit choice)
    if (chosenSuit != null) {
      payload['chosenSuit'] = chosenSuit;
    }

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'play_card',
      'payload': payload,
    });
  }

  /// NEW: Choose suit (legacy two-step flow; keep for backwards compatibility)
  void chooseSuit({
    required String roomId,
    required String userId,
    required String suit, // 'hearts', 'diamonds', 'clubs', 'spades'
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('👑 Choosing suit: $suit');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'choose_suit',
      'payload': {
        'userId': userId,
        'suit': suit,
      },
    });
  }

  void drawCard({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('📥 Drawing card');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'draw_card',
      'payload': {
        'userId': userId,
      },
    });
  }

  void callCrazyEights({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('🎯 Calling Crazy Eights');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'call_crazy_eights',
      'payload': {
        'userId': userId,
      },
    });
  }

  void challengePlayer({
    required String roomId,
    required String challengerId,
    required String targetId,
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('⚡ Challenging player');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'challenge_player',
      'payload': {
        'challengerId': challengerId,
        'challengedId': targetId, // Server expects 'challengedId'
      },
    });
  }

  void chooseJackAction({
    required String roomId,
    required String userId,
    required String action, // 'skip' or 'reverse'
  }) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('🃏 Choosing Jack action: $action');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'choose_jack_action',
      'payload': {
        'userId': userId,
        'action': action,
      },
    });
  }

  // ===========================================
  // CHAT METHODS (ENHANCED)
  // ===========================================

  /// Send a chat message to the room
  void sendMessage({
    required String roomId,
    required String userId,
    required String message,
  }) {
    if (!isConnected || message.trim().isEmpty) {
      print('❌ Cannot send message: ${!isConnected ? "Not connected" : "Empty message"}');
      return;
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.length > 500) {
      print('⚠️ Message too long, truncating to 500 chars');
    }

    print('📤 Sending message: $trimmedMessage');

    _socket!.emit('send_message', {
      'roomId': roomId,
      'userId': userId,
      'message': trimmedMessage.substring(0, trimmedMessage.length > 500 ? 500 : trimmedMessage.length),
    });
  }

  /// Request chat history for a room
  void getChatHistory({
    required String roomId,
    int limit = 50,
  }) {
    if (!isConnected) {
      print('❌ Not connected to server');
      return;
    }

    print('📜 Requesting chat history for room: $roomId');

    _socket!.emit('get_chat_history', {
      'roomId': roomId,
      'limit': limit,
    });
  }

  /// Send typing indicator (user started typing)
  void sendTypingStart({
    required String roomId,
    required String userId,
    required String username,
  }) {
    if (!isConnected) return;

    _socket!.emit('typing_start', {
      'roomId': roomId,
      'userId': userId,
      'username': username,
    });
  }

  /// Send typing indicator (user stopped typing)
  void sendTypingStop({
    required String roomId,
    required String userId,
    required String username,
  }) {
    if (!isConnected) return;

    _socket!.emit('typing_stop', {
      'roomId': roomId,
      'userId': userId,
      'username': username,
    });
  }

  // ===========================================
  // UTILITIES
  // ===========================================

  void ping() {
    if (!isConnected) return;
    _socket!.emit('ping');
  }

  void debugRoomState(String roomId) {
    if (!isConnected) return;

    _socket!.emit('debug_room_state', {
      'roomId': roomId,
    });

    _socket!.once('debug_info', (data) {
      print('🔍 Debug Info: $data');
    });
  }

  // ===========================================
  // INTERNAL HELPERS
  // ===========================================

  // Defensive normalisation to avoid "six/seven" being sent (server expects "6/7/...").
  String _normaliseCrazyEightsRank(String rank) {
    final r = rank.toLowerCase().trim();
    switch (r) {
      case 'two':
        return '2';
      case 'three':
        return '3';
      case 'four':
        return '4';
      case 'five':
        return '5';
      case 'six':
        return '6';
      case 'seven':
        return '7';
      case 'eight':
        return '8';
      case 'nine':
        return '9';
      // allow canonical values through
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
      case '10':
      case 'jack':
      case 'queen':
      case 'king':
      case 'ace':
        return r;
      default:
        return rank; // don’t guess beyond this
    }
  }

  // ===========================================
  // CLEANUP
  // ===========================================

  void dispose() {
    disconnect();
    _roomCreatedController.close();
    _playerJoinedController.close();
    _playerLeftController.close();
    _playerReadyController.close();
    _gameStartingController.close();
    _gameActionController.close();
    _errorController.close();
    _connectionController.close();
    _chatMessageController.close();
    _insuranceOfferedController.close();
    _newRoundStartingController.close();
    // Chat-specific controllers
    _chatHistoryController.close();
    _userTypingController.close();
    // Crazy Eights controllers (UPDATED)
    _gameStartedController.close();
    _cardPlayedController.close();
    _cardPlayRejectedController.close(); // NEW
    _cardDrawnController.close();
    _cardsDrawnController.close(); // NEW
    _playerTurnController.close();
    _turnChangedController.close(); // NEW
    _suitChosenController.close(); // NEW
    _chooseSuitRequiredController.close(); // NEW
    _crazyEightsCalledController.close();
    _crazyEightsViolationController.close();
    _challengeSuccessfulController.close();
    _jackChoiceNeededController.close();
    _jackActionChosenController.close();
    _chooseJackActionRequiredController.close(); // NEW
    _cardsReceivedController.close();
  }
}
