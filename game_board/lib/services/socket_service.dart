// ====================================
// lib/services/socket_service.dart
// Universal multiplayer socket service for all games + chat
// UPDATED: Added optimistic UI event handlers
// FIXED: Normalise Crazy Eights rank strings before sending to server ("six" -> "6", etc.)
// ====================================
// ignore_for_file: avoid_print

// SocketService — the central real-time communication hub for the Microvark platform.
//
// Responsibilities:
//   - Managing the Socket.IO WebSocket connection to the game server.
//   - Routing all incoming server events to typed broadcast Streams for
//     consumption by game screens, chat widgets, and voice services.
//   - Providing typed emit methods for all client-to-server actions
//     (room management, game moves, chat, voice/WebRTC signalling).
//   - Handling automatic reconnection and room rejoin on connection drop.
//
// Design Patterns:
//   - Singleton: only one socket connection exists for the app's lifetime.
//   - Stream per event type: each socket event has a dedicated broadcast
//     StreamController, decoupling event producers from consumers.
//   - Optimistic UI support: Crazy Eights includes 'rejected' and 'rollback'
//     events so the UI can revert immediately on server rejection.
//
// Server URL: https://microaardvark.co.uk (WebSocket transport required —
//   plain polling does not work through Cloudflare's proxy layer).

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';

class SocketService {
  // ---- Singleton Setup ----

  /// Shared singleton instance. Use `SocketService()` to access it.
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // ---- Socket Instance ----

  /// The underlying Socket.IO client. Null when not connected.
  io.Socket? _socket;

  /// The game server's base URL. All Socket.IO traffic routes here.
  final String baseUrl = 'https://microaardvark.co.uk';

  // ===========================================================
  // STREAM CONTROLLERS
  // Each server event has its own broadcast StreamController.
  // Broadcast streams allow multiple UI widgets to listen
  // simultaneously without requiring a single subscriber.
  // ===========================================================

  // ---- Voice Chat Event Controllers ----
  final _voiceParticipantsUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceJoinedController             = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceParticipantLeftController    = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceMuteUpdatedController        = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceUserKickedController         = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceErrorController              = StreamController<Map<String, dynamic>>.broadcast();

  // ---- WebRTC Signalling Controllers ----
  final _webrtcOfferReceivedController         = StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcAnswerReceivedController        = StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcIceCandidateReceivedController  = StreamController<Map<String, dynamic>>.broadcast();

  // ---- Room & Lobby Event Controllers ----
  final _roomCreatedController    = StreamController<Map<String, dynamic>>.broadcast();
  final _playerJoinedController   = StreamController<Map<String, dynamic>>.broadcast();
  final _playerLeftController     = StreamController<Map<String, dynamic>>.broadcast();
  final _playerReadyController    = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStartingController   = StreamController<Map<String, dynamic>>.broadcast();

  // ---- Generic Game Event Controllers ----
  final _gameActionController     = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController          = StreamController<String>.broadcast();
  final _connectionController     = StreamController<bool>.broadcast();

  // ---- Blackjack-Specific Controllers ----
  final _chatMessageController    = StreamController<Map<String, dynamic>>.broadcast();
  final _insuranceOfferedController = StreamController<Map<String, dynamic>>.broadcast();
  final _newRoundStartingController = StreamController<Map<String, dynamic>>.broadcast();

  // ---- Chat Controllers ----
  final _chatHistoryController    = StreamController<Map<String, dynamic>>.broadcast();
  final _userTypingController     = StreamController<Map<String, dynamic>>.broadcast();

  // ---- Crazy Eights Controllers (includes optimistic UI support) ----

  /// Fired when the Crazy Eights game officially begins.
  final _gameStartedController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired when any player plays a card (server-confirmed).
  final _cardPlayedController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired when the server rejects a card play (optimistic rollback trigger).
  final _cardPlayRejectedController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired when another player draws a card (count only — no card data).
  final _cardDrawnController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired when this player draws cards — includes actual card data.
  final _cardsDrawnController = StreamController<Map<String, dynamic>>.broadcast();

  final _playerTurnController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired when the active turn changes to a different player.
  final _turnChangedController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired when a player chooses a suit (after playing a King/Ace).
  final _suitChosenController = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired to prompt this client to display a suit selection UI.
  final _chooseSuitRequiredController = StreamController<Map<String, dynamic>>.broadcast();

  final _crazyEightsCalledController   = StreamController<Map<String, dynamic>>.broadcast();
  final _crazyEightsViolationController = StreamController<Map<String, dynamic>>.broadcast();
  final _challengeSuccessfulController = StreamController<Map<String, dynamic>>.broadcast();
  final _jackChoiceNeededController    = StreamController<Map<String, dynamic>>.broadcast();
  final _jackActionChosenController    = StreamController<Map<String, dynamic>>.broadcast();

  /// Fired to prompt this client to display the Jack action selection UI.
  final _chooseJackActionRequiredController = StreamController<Map<String, dynamic>>.broadcast();

  final _cardsReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  // ===========================================================
  // PUBLIC STREAM GETTERS
  // Consumers listen to these streams; they never access the
  // controllers directly.
  // ===========================================================

  // ---- Room & Lobby ----
  Stream<Map<String, dynamic>> get onRoomCreated    => _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined   => _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft     => _playerLeftController.stream;
  Stream<Map<String, dynamic>> get onPlayerReady    => _playerReadyController.stream;
  Stream<Map<String, dynamic>> get onGameStarting   => _gameStartingController.stream;

  // ---- Generic Game ----
  Stream<Map<String, dynamic>> get onGameAction     => _gameActionController.stream;
  Stream<String>               get onError          => _errorController.stream;
  Stream<bool>                 get onConnectionChange => _connectionController.stream;

  // ---- Blackjack / Chat ----
  Stream<Map<String, dynamic>> get onChatMessage       => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onInsuranceOffered  => _insuranceOfferedController.stream;
  Stream<Map<String, dynamic>> get onNewRoundStarting  => _newRoundStartingController.stream;

  // ---- Voice Chat ----
  Stream<Map<String, dynamic>> get onVoiceParticipantsUpdated => _voiceParticipantsUpdatedController.stream;
  Stream<Map<String, dynamic>> get onVoiceJoined              => _voiceJoinedController.stream;
  Stream<Map<String, dynamic>> get onVoiceParticipantLeft     => _voiceParticipantLeftController.stream;
  Stream<Map<String, dynamic>> get onVoiceMuteUpdated         => _voiceMuteUpdatedController.stream;
  Stream<Map<String, dynamic>> get onVoiceUserKicked          => _voiceUserKickedController.stream;
  Stream<Map<String, dynamic>> get onVoiceError               => _voiceErrorController.stream;

  // ---- WebRTC Signalling ----
  Stream<Map<String, dynamic>> get onWebRTCOfferReceived          => _webrtcOfferReceivedController.stream;
  Stream<Map<String, dynamic>> get onWebRTCAnswerReceived         => _webrtcAnswerReceivedController.stream;
  Stream<Map<String, dynamic>> get onWebRTCIceCandidateReceived   => _webrtcIceCandidateReceivedController.stream;

  // ---- Chat ----
  Stream<Map<String, dynamic>> get onChatHistory  => _chatHistoryController.stream;
  Stream<Map<String, dynamic>> get onUserTyping   => _userTypingController.stream;

  // ---- Crazy Eights ----
  Stream<Map<String, dynamic>> get onGameStarted              => _gameStartedController.stream;
  Stream<Map<String, dynamic>> get onCardPlayed               => _cardPlayedController.stream;
  Stream<Map<String, dynamic>> get onCardPlayRejected         => _cardPlayRejectedController.stream;
  Stream<Map<String, dynamic>> get onCardDrawn                => _cardDrawnController.stream;
  Stream<Map<String, dynamic>> get onCardsDrawn               => _cardsDrawnController.stream;
  Stream<Map<String, dynamic>> get onPlayerTurn               => _playerTurnController.stream;
  Stream<Map<String, dynamic>> get onTurnChanged              => _turnChangedController.stream;
  Stream<Map<String, dynamic>> get onSuitChosen               => _suitChosenController.stream;
  Stream<Map<String, dynamic>> get onChooseSuitRequired       => _chooseSuitRequiredController.stream;
  Stream<Map<String, dynamic>> get onCrazyEightsCalled        => _crazyEightsCalledController.stream;
  Stream<Map<String, dynamic>> get onCrazyEightsViolation     => _crazyEightsViolationController.stream;
  Stream<Map<String, dynamic>> get onChallengeSuccessful      => _challengeSuccessfulController.stream;
  Stream<Map<String, dynamic>> get onJackChoiceNeeded         => _jackChoiceNeededController.stream;
  Stream<Map<String, dynamic>> get onJackActionChosen         => _jackActionChosenController.stream;
  Stream<Map<String, dynamic>> get onChooseJackActionRequired => _chooseJackActionRequiredController.stream;
  Stream<Map<String, dynamic>> get onCardsReceived            => _cardsReceivedController.stream;

  // ---- Connection State ----

  /// Whether the socket is currently connected to the server.
  bool get isConnected => _socket?.connected ?? false;

  /// The ID of the room this client is currently in (null if not in a room).
  String? currentRoomId;

  /// The authenticated user's ID for the current session.
  String? currentUserId;

  /// The authenticated user's display name for the current session.
  String? currentUsername;

  // ===========================================
  // CONNECTION MANAGEMENT
  // ===========================================

  /// Connects to the game server and begins listening for events.
  ///
  /// Uses WebSocket transport exclusively — this is required when the server
  /// sits behind Cloudflare, as long-polling is not reliably proxied.
  /// Auto-reconnection is enabled with up to 10 attempts and a 1-second delay.
  ///
  /// If already connected, this method is a no-op.
  ///
  /// If the client was previously in a room when disconnected, it automatically
  /// attempts to rejoin that room on reconnect.
  ///
  /// Parameters:
  ///   - [userId]: The authenticated user's ID, stored for use across reconnects.
  ///   - [username]: The user's display name.
  void connect(String userId, String username) {
    if (_socket != null && _socket!.connected) {
      print('✅ Already connected to server');
      return;
    }

    currentUserId = userId;
    currentUsername = username;

    print('🔌 Connecting to: $baseUrl');
    print('   User ID: $userId');

    _socket = io.io(baseUrl, io.OptionBuilder()
      .setTransports(['websocket']) // REQUIRED: Cloudflare + mobile don't support long-polling.
      .enableAutoConnect()
      .enableReconnection()
      .setReconnectionAttempts(10)
      .setReconnectionDelay(1000) // ms between reconnect attempts.
      .build()
    );

    _socket!.onConnect((_) {
      print('✅ Connected to server');
      _connectionController.add(true);

      // If this client was previously in a room, rejoin it automatically.
      if (currentRoomId != null) {
        print('🔄 Rejoining room: $currentRoomId');
        joinRoom(
          roomId: currentRoomId!,
          userId: userId,
          username: username,
        );
      }
    });

    _socket!.onConnectError((err) {
      print('❌ onConnectError: $err');
    });

    _socket!.onError((err) {
      print('❌ onError: $err');
    });

    _socket!.onDisconnect((reason) {
      print('🔌 disconnected: $reason');
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

  /// Disconnects from the server and clears the current room ID.
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

  /// Registers all Socket.IO event listeners and routes them to stream controllers.
  ///
  /// Called once after the socket is created. Each `_socket!.on(event, handler)`
  /// call registers a listener for a named server event and adds the received
  /// data to the corresponding broadcast stream.
  void _setupSocketListeners() {
    if (_socket == null) return;

    // ---- Connection / Lobby Events ----

    // Server welcome message on first connect.
    _socket!.on('welcome', (data) {
      print('👋 ${data['message']}');
    });

    // A new room has been created (or this user has rejoined one).
    _socket!.on('room_created', (data) {
      print('📝 Room created: ${data['roomId']}');
      currentRoomId = data['roomId'];
      _roomCreatedController.add(data);
    });

    // Another player joined the same room.
    _socket!.on('player_joined', (data) {
      print('👤 Player joined: ${data['player']['username']}');
      _playerJoinedController.add(data);
    });

    // A player left the room.
    _socket!.on('player_left', (data) {
      print('👋 Player left: ${data['username']}');
      _playerLeftController.add(data);
    });

    // A player's ready state changed.
    _socket!.on('player_ready_update', (data) {
      print('✅ Player ready: ${data['username']}');
      _playerReadyController.add(data);
    });

    // All players are ready — the game is about to start.
    _socket!.on('game_starting', (data) {
      print('🎮 Game starting!');
      _gameStartingController.add(data);
    });

    // Successful rejoin after a disconnection.
    _socket!.on('rejoined_room', (data) {
      print('🔄 Rejoined room successfully');
      currentRoomId = data['roomId'];
      _roomCreatedController.add(data); // Reuse the room stream to restore UI state.
    });

    // A previously disconnected player has reconnected to the room.
    _socket!.on('player_reconnected', (data) {
      print('🔄 Player reconnected: ${data['username']}');
      _playerJoinedController.add(data);
    });

    // A player's connection dropped (temporary disconnect).
    _socket!.on('player_disconnected', (data) {
      print('⚠️ Player disconnected: ${data['username']}');
      _playerLeftController.add(data);
    });

    // A player was removed from the room (e.g., timed out).
    _socket!.on('player_removed', (data) {
      print('🗑️ Player removed: ${data['username']} - ${data['reason']}');
      _playerLeftController.add(data);
    });

    // ---- Blackjack Game Events ----
    // All Blackjack events are routed through the generic [_gameActionController]
    // with a 'type' field so consumers can switch on the event type.

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

    // Insurance is also forwarded to a dedicated stream for the insurance UI.
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

    // Whose turn it is to place a bet during the betting phase.
    _socket!.on('next_player_bet_turn', (data) {
      print('➡️ Next player bet turn: ${data['username']}');
      _gameActionController.add({'type': 'next_player_bet_turn', 'data': data});
    });

    // All players have placed their bets — dealing can begin.
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

    // All players are ready to proceed to the next Blackjack round.
    _socket!.on('new_round_starting', (data) {
      print('🔄 New round starting');
      _newRoundStartingController.add(data);
    });

    // ---- Chat Events ----

    // A new chat message was received in the room.
    _socket!.on('chat_message', (data) {
      print('💬 ${data['username']}: ${data['message']}');
      _chatMessageController.add(data);
    });

    // Historical chat messages for the room (sent on join).
    _socket!.on('chat_history', (data) {
      print('📜 Received ${data['messages'].length} chat messages');
      _chatHistoryController.add(data);
    });

    // A user started or stopped typing in the chat.
    _socket!.on('user_typing', (data) {
      print('⌨️ ${data['username']} is ${data['isTyping'] ? "typing" : "stopped typing"}');
      _userTypingController.add(data);
    });

    // ===================================
    // CRAZY EIGHTS EVENTS
    // ===================================
    //
    // Crazy Eights uses an optimistic UI pattern: the client applies moves
    // immediately for responsiveness, then waits for server confirmation.
    // If the server rejects a move (e.g., invalid card), [onCardPlayRejected]
    // fires and the client reverts the optimistic update.

    _socket!.on('game_started', (data) {
      print('🎮 Crazy Eights game started!');
      _gameStartedController.add(data);
    });

    // Server-confirmed card play — update all clients' game state.
    _socket!.on('card_played', (data) {
      print('🃏 Card played by: ${data['userId']}');
      _cardPlayedController.add(data);
    });

    // Server rejected a card play — triggers an optimistic update rollback.
    _socket!.on('card_play_rejected', (data) {
      print('❌ Card play rejected: ${data['reason']}');
      _cardPlayRejectedController.add(data);
    });

    // Another player drew a card — only the count is broadcast (no card data).
    _socket!.on('card_drawn', (data) {
      print('📥 Other player drew: ${data['userId']} drew ${data['count']} card(s)');
      _cardDrawnController.add(data);
    });

    // This player received drawn cards — includes the actual card data.
    _socket!.on('cards_drawn', (data) {
      print('📨 I received ${data['cards'].length} card(s)');
      _cardsDrawnController.add(data);
    });

    // The active turn has moved to a different player.
    _socket!.on('turn_changed', (data) {
      print('🔄 Turn changed to: ${data['currentTurn']}');
      _turnChangedController.add(data);
    });

    // A player chose a suit after playing a wild card (King/Ace).
    _socket!.on('suit_chosen', (data) {
      print('👑 Suit chosen: ${data['suit']} by ${data['userId']}');
      _suitChosenController.add(data);
    });

    // This client needs to display a suit selection UI.
    _socket!.on('choose_suit_required', (data) {
      print('👑 Choose suit required');
      _chooseSuitRequiredController.add(data);
    });

    _socket!.on('player_turn', (data) {
      print('👤 Player turn: ${data['username']}');
      _playerTurnController.add(data);
    });

    // A player called "Crazy Eights" (announced they have one card left).
    _socket!.on('crazy_eights_called', (data) {
      print('🎯 Crazy Eights called by: ${data['userId']}');
      _crazyEightsCalledController.add(data);
    });

    // A player forgot to call "Crazy Eights" and was caught.
    _socket!.on('crazy_eights_violation', (data) {
      print('⚠️ Crazy Eights violation: ${data['username']}');
      _crazyEightsViolationController.add(data);
    });

    // A challenge of another player's Crazy Eights call succeeded.
    _socket!.on('challenge_successful', (data) {
      print('✅ Challenge successful');
      _challengeSuccessfulController.add(data);
    });

    // A challenge failed (the target did correctly call Crazy Eights).
    _socket!.on('challenge_failed', (data) {
      print('❌ Challenge failed');
      // Reuses the challenge stream — consumers check for a 'success' field.
      _challengeSuccessfulController.add(data);
    });

    // A Jack was played — the player must choose skip or reverse.
    _socket!.on('jack_choice_needed', (data) {
      print('🃏 Jack choice needed');
      _jackChoiceNeededController.add(data);
    });

    // A player chose an action for their Jack play.
    _socket!.on('jack_action_chosen', (data) {
      print('🃏 Jack action chosen: ${data['action']}');
      _jackActionChosenController.add(data);
    });

    // This client must display the Jack action selection UI.
    _socket!.on('choose_jack_action_required', (data) {
      print('🃏 Choose Jack action required');
      _chooseJackActionRequiredController.add(data);
    });

    // Cards were received as a result of a Crazy Eights penalty or special rule.
    _socket!.on('cards_received', (data) {
      print('📨 Cards received: ${data['cards'].length} card(s)');
      _cardsReceivedController.add(data);
    });

    // The game has ended — the winner is known.
    _socket!.on('game_ended', (data) {
      print('🏆 Game ended! Winner: ${data['winnerName']}');
      _gameActionController.add({'type': 'game_ended', 'data': data});
    });

    // ---- Error Handling ----

    _socket!.on('error', (data) {
      print('❌ Server error: ${data['message']}');
      _errorController.add(data['message'] ?? 'Unknown error');
    });

    // Latency check response — used for connection health monitoring.
    _socket!.on('pong', (data) {
      print('🏓 Pong received at ${data['timestamp']}');
    });

    // Generic game action event (used by some game types).
    _socket!.on('game_action', (data) {
      print('🎮 Game action received: ${data['action']}');
      _gameActionController.add(data);
    });

    // ---- Voice Chat Events ----
    // Route voice chat events to their respective stream controllers.
    // The voice service (VoiceChatService) listens to these streams.

    _socket!.on('voice_participants_updated', (data) {
      _voiceParticipantsUpdatedController.add(data);
    });

    _socket!.on('voice_joined', (data) {
      _voiceJoinedController.add(data);
    });

    _socket!.on('voice_participant_left', (data) {
      _voiceParticipantLeftController.add(data);
    });

    _socket!.on('voice_mute_updated', (data) {
      _voiceMuteUpdatedController.add(data);
    });

    _socket!.on('voice_user_kicked', (data) {
      _voiceUserKickedController.add(data);
    });

    _socket!.on('voice_error', (data) {
      _voiceErrorController.add(data);
    });

    // ---- WebRTC Signalling Events ----
    // These relay WebRTC session negotiation messages between peers
    // via the server as the signalling channel. The voice services
    // listen to these streams to drive peer connection setup.

    _socket!.on('webrtc_offer_received', (data) {
      _webrtcOfferReceivedController.add(data);
    });

    _socket!.on('webrtc_answer_received', (data) {
      _webrtcAnswerReceivedController.add(data);
    });

    _socket!.on('webrtc_ice_candidate_received', (data) {
      _webrtcIceCandidateReceivedController.add(data);
    });
  }

  // ===========================================
  // ROOM MANAGEMENT
  // ===========================================

  /// Creates a new multiplayer game room on the server.
  ///
  /// On success, the server emits a 'room_created' event with the generated
  /// room ID, which is stored in [currentRoomId].
  ///
  /// Parameters:
  ///   - [gameType]: The type of game to create (e.g., 'blackjack', 'crazy_eights').
  ///   - [maxPlayers]: The maximum number of players allowed in the room.
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

  /// Joins an existing game room.
  ///
  /// Used both for initial joins and for reconnecting after a disconnect.
  /// The server responds with either 'player_joined' or 'rejoined_room'.
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

  /// Leaves the current game room and clears [currentRoomId].
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

  /// Signals that this player is ready to start the game.
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

  /// Cancels the ready state for this player.
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

  /// Signals that this player is ready to start the next round.
  ///
  /// Used in Blackjack to indicate the player wants to continue after
  /// a round has ended.
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

  /// Sends a generic game action event to the server.
  ///
  /// Used as the underlying transport for all game-specific actions.
  /// The server dispatches the action to the appropriate game handler
  /// based on [action].
  ///
  /// Parameters:
  ///   - [roomId]: The room the action belongs to.
  ///   - [action]: A string identifying the action (e.g., 'hit', 'stand', 'play_card').
  ///   - [payload]: Game-specific data for the action.
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
  // These methods wrap [sendGameAction] for each Blackjack action,
  // providing a typed API and removing boilerplate from game screens.

  /// Places a bet for the given player.
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

  /// Starts the dealing phase after all bets are placed.
  void startRound({required String roomId}) {
    sendGameAction(
      roomId: roomId,
      action: 'start_round',
      payload: {},
    );
  }

  /// Requests an additional card (Hit).
  void hit({required String roomId, required String userId}) {
    sendGameAction(
      roomId: roomId,
      action: 'hit',
      payload: {'userId': userId},
    );
  }

  /// Ends the player's turn without drawing another card (Stand).
  void stand({required String roomId, required String userId}) {
    sendGameAction(
      roomId: roomId,
      action: 'stand',
      payload: {'userId': userId},
    );
  }

  /// Doubles the bet and receives exactly one more card (Double Down).
  void doubleDown({required String roomId, required String userId}) {
    sendGameAction(
      roomId: roomId,
      action: 'double_down',
      payload: {'userId': userId},
    );
  }

  /// Splits a pair into two separate hands (Split).
  void split({required String roomId, required String userId}) {
    sendGameAction(
      roomId: roomId,
      action: 'split',
      payload: {'userId': userId},
    );
  }

  /// Places or declines an insurance side bet when the dealer shows an Ace.
  ///
  /// Parameters:
  ///   - [takeInsurance]: `true` to take insurance, `false` to decline.
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
  // CRAZY EIGHTS GAME ACTIONS
  // ===========================================

  /// Starts a Crazy Eights game session in the room.
  void startCrazyEights({required String roomId}) {
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

  /// Plays a card from the player's hand.
  ///
  /// Supports both the standard play and the case where a wild card (King/Ace)
  /// is played with an immediate suit selection (single-step flow).
  ///
  /// Card rank is normalised before sending: English word names (e.g., "six")
  /// are converted to their numeric equivalents ("6") to match the server's
  /// expected format. See [_normaliseCrazyEightsRank].
  ///
  /// Parameters:
  ///   - [cardIndex]: The index of the card in the player's hand.
  ///   - [cardSuit]: The suit of the card being played.
  ///   - [cardRank]: The rank of the card (normalised internally).
  ///   - [chosenSuit]: Optional suit selection when playing a wild card.
  void playCard({
    required String roomId,
    required String userId,
    required int cardIndex,
    required String cardSuit,
    required String cardRank,
    String? chosenSuit,
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

    // Include a chosen suit for King/Ace plays that use the single-step flow.
    if (chosenSuit != null) {
      payload['chosenSuit'] = chosenSuit;
    }

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'play_card',
      'payload': payload,
    });
  }

  /// Chooses a suit after playing a wild card (legacy two-step flow).
  ///
  /// Retained for backwards compatibility. New code should prefer passing
  /// [chosenSuit] directly in [playCard].
  void chooseSuit({
    required String roomId,
    required String userId,
    required String suit, // 'hearts', 'diamonds', 'clubs', or 'spades'
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

  /// Draws a card from the deck.
  void drawCard({required String roomId, required String userId}) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('📥 Drawing card');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'draw_card',
      'payload': {'userId': userId},
    });
  }

  /// Calls "Crazy Eights" to declare the player has one card remaining.
  ///
  /// Must be called before playing the second-to-last card; failure to do so
  /// allows other players to challenge and penalise this player.
  void callCrazyEights({required String roomId, required String userId}) {
    if (!isConnected) {
      print('❌ Not connected');
      return;
    }

    print('🎯 Calling Crazy Eights');

    _socket!.emit('game_action', {
      'roomId': roomId,
      'action': 'call_crazy_eights',
      'payload': {'userId': userId},
    });
  }

  /// Challenges another player who failed to call "Crazy Eights".
  ///
  /// If the challenge is successful, the target player receives penalty cards.
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
        'challengedId': targetId, // Server expects 'challengedId' (not 'targetId').
      },
    });
  }

  /// Chooses an action for a Jack card play (skip or reverse turn order).
  ///
  /// Parameters:
  ///   - [action]: Either 'skip' or 'reverse'.
  void chooseJackAction({
    required String roomId,
    required String userId,
    required String action,
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
  // CHAT METHODS
  // ===========================================

  /// Sends a chat message to all players in the room.
  ///
  /// Messages are trimmed of whitespace and capped at 500 characters.
  /// Empty messages are discarded without sending.
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
      // Truncate to server's maximum message length.
      'message': trimmedMessage.substring(
        0,
        trimmedMessage.length > 500 ? 500 : trimmedMessage.length,
      ),
    });
  }

  /// Requests the chat history for a room (sent on joining).
  ///
  /// The server responds with a 'chat_history' event containing up to
  /// [limit] recent messages.
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

  /// Notifies the room that this user has started typing.
  ///
  /// Should be called when the user begins entering text in the chat input.
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

  /// Notifies the room that this user has stopped typing.
  ///
  /// Should be called when the user clears the input, sends a message,
  /// or stops typing after a debounce delay.
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

  /// Sends a ping to the server to test latency or keep the connection alive.
  void ping() {
    if (!isConnected) return;
    _socket!.emit('ping');
  }

  /// Requests debug information about the specified room from the server.
  ///
  /// The server responds with a 'debug_info' event. For development use only.
  void debugRoomState(String roomId) {
    if (!isConnected) return;

    _socket!.emit('debug_room_state', {'roomId': roomId});

    _socket!.once('debug_info', (data) {
      print('🔍 Debug Info: $data');
    });
  }

  // ===========================================
  // INTERNAL HELPERS
  // ===========================================

  /// Normalises a Crazy Eights card rank from word form to numeric/canonical form.
  ///
  /// The game engine occasionally sends rank values as English words
  /// (e.g., "six", "seven") rather than numeric strings ("6", "7").
  /// The server expects numeric strings for rank comparison, so any
  /// word-form rank is converted here before being sent.
  ///
  /// Court cards (jack, queen, king, ace) and already-numeric ranks are
  /// passed through unchanged.
  ///
  /// Examples:
  ///   - "six"   → "6"
  ///   - "eight" → "8"
  ///   - "king"  → "king" (unchanged)
  ///   - "7"     → "7"    (unchanged)
  String _normaliseCrazyEightsRank(String rank) {
    final r = rank.toLowerCase().trim();
    switch (r) {
      case 'two':   return '2';
      case 'three': return '3';
      case 'four':  return '4';
      case 'five':  return '5';
      case 'six':   return '6';
      case 'seven': return '7';
      case 'eight': return '8';
      case 'nine':  return '9';
      // Canonical numeric and court card values pass through unchanged.
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
        return rank; // Unknown rank — return as-is and let the server validate.
    }
  }

  // ===========================================
  // VOICE CHAT EMIT METHODS
  // ===========================================
  // These methods emit Socket.IO events to the server for voice chat
  // session management and WebRTC signalling.

  /// Notifies the server that this user is joining the voice channel.
  void voiceJoin({
    required String roomId,
    required String userId,
    required String username,
  }) {
    if (!isConnected) return;
    _socket!.emit('voice_join', {
      'roomId': roomId,
      'userId': userId,
      'username': username,
    });
  }

  /// Notifies the server that this user is leaving the voice channel.
  void voiceLeave({
    required String roomId,
    required String userId,
  }) {
    if (!isConnected) return;
    _socket!.emit('voice_leave', {
      'roomId': roomId,
      'userId': userId,
    });
  }

  /// Broadcasts a mute state change to other voice channel participants.
  void voiceMuteToggle({
    required String roomId,
    required String userId,
    required bool muted,
  }) {
    if (!isConnected) return;
    _socket!.emit('voice_mute_toggle', {
      'roomId': roomId,
      'userId': userId,
      'muted': muted,
    });
  }

  /// Sends a WebRTC SDP offer to a specific peer via the signalling server.
  ///
  /// Called by the initiating peer after creating an offer via
  /// RTCPeerConnection.createOffer().
  void sendWebRTCOffer({
    required String roomId,
    required String targetUserId,
    required String fromUserId,
    required Map<String, dynamic> offer,
  }) {
    if (!isConnected) return;
    _socket!.emit('webrtc_offer', {
      'roomId': roomId,
      'targetUserId': targetUserId,
      'fromUserId': fromUserId,
      'offer': offer,
    });
  }

  /// Sends a WebRTC SDP answer to a specific peer via the signalling server.
  ///
  /// Called by the receiving peer after setting the remote description from
  /// the received offer.
  void sendWebRTCAnswer({
    required String roomId,
    required String targetUserId,
    required String fromUserId,
    required Map<String, dynamic> answer,
  }) {
    if (!isConnected) return;
    _socket!.emit('webrtc_answer', {
      'roomId': roomId,
      'targetUserId': targetUserId,
      'fromUserId': fromUserId,
      'answer': answer,
    });
  }

  /// Sends a WebRTC ICE candidate to a specific peer via the signalling server.
  ///
  /// ICE candidates are exchanged after the offer/answer to negotiate the
  /// best network path between two peers (NAT traversal).
  void sendWebRTCIceCandidate({
    required String roomId,
    required String targetUserId,
    required String fromUserId,
    required Map<String, dynamic> candidate,
  }) {
    if (!isConnected) return;
    _socket!.emit('webrtc_ice_candidate', {
      'roomId': roomId,
      'targetUserId': targetUserId,
      'fromUserId': fromUserId,
      'candidate': candidate,
    });
  }

  /// Reports a voice chat participant via the signalling server.
  void voiceReportUser({
    required String roomId,
    required String reportedUserId,
    required String reportedUsername,
    required String reason,
    required String reporterId,
  }) {
    if (!isConnected) return;
    _socket!.emit('voice_report_user', {
      'roomId': roomId,
      'reportedUserId': reportedUserId,
      'reportedUsername': reportedUsername,
      'reason': reason,
      'reporterId': reporterId,
    });
  }

  // ===========================================
  // CLEANUP
  // ===========================================

  /// Disconnects the socket and closes all stream controllers.
  ///
  /// Should be called when the app is being disposed. After calling this
  /// method, the service can no longer be used.
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
    _chatHistoryController.close();
    _userTypingController.close();
    _gameStartedController.close();
    _cardPlayedController.close();
    _cardPlayRejectedController.close();
    _cardDrawnController.close();
    _cardsDrawnController.close();
    _playerTurnController.close();
    _turnChangedController.close();
    _suitChosenController.close();
    _chooseSuitRequiredController.close();
    _crazyEightsCalledController.close();
    _crazyEightsViolationController.close();
    _challengeSuccessfulController.close();
    _jackChoiceNeededController.close();
    _jackActionChosenController.close();
    _chooseJackActionRequiredController.close();
    _cardsReceivedController.close();
    _voiceParticipantsUpdatedController.close();
    _voiceJoinedController.close();
    _voiceParticipantLeftController.close();
    _voiceMuteUpdatedController.close();
    _voiceUserKickedController.close();
    _voiceErrorController.close();
    _webrtcOfferReceivedController.close();
    _webrtcAnswerReceivedController.close();
    _webrtcIceCandidateReceivedController.close();
  }
}