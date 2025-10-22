// ====================================
// lib/services/socket_service.dart
// Universal multiplayer socket service for all games - COMPLETE
// ====================================
// ignore_for_file: avoid_print

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // Socket instance
  IO.Socket? _socket;
  
  // IMPORTANT: Replace with your server IP/URL
  final String baseUrl = 'http://51.21.236.10:3000';
  
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

    _socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
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
  // CHAT
  // ===========================================
  
  void sendMessage({
    required String roomId,
    required String userId,
    required String message,
  }) {
    if (!isConnected || message.trim().isEmpty) return;

    _socket!.emit('send_message', {
      'roomId': roomId,
      'userId': userId,
      'message': message.trim(),
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
  }
}