// lib/screens/chat_test_screen.dart
// Fully responsive test screen with Join Room functionality
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../models/user.dart';

class ChatTestScreen extends StatefulWidget {
  final User user;
  
  const ChatTestScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ChatTestScreen> createState() => _ChatTestScreenState();
}

class _ChatTestScreenState extends State<ChatTestScreen> {
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();
  final List<String> _logs = [];
  
  String? _roomId;
  late String _userId;
  late String _username;

  StreamSubscription? _connectionSub;
  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _playerJoinedSub;
  StreamSubscription? _chatMessageSub;
  StreamSubscription? _chatHistorySub;
  StreamSubscription? _typingSub;
  StreamSubscription? _errorSub;

  @override
  void initState() {
    super.initState();
    _userId = widget.user.id;
    _username = widget.user.username;
    
    _addLog('👤 Testing as: $_username');
    _addLog('🆔 User ID: $_userId');
    
    _setupListeners();
  }

  void _setupListeners() {
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      _addLog(connected ? '✅ Connected' : '❌ Disconnected');
    });

    _roomCreatedSub = _socketService.onRoomCreated.listen((data) {
      setState(() {
        _roomId = data['roomId'];
        _roomIdController.text = _roomId ?? '';
      });
      _addLog('📝 Room created: $_roomId');
      _addLog('📋 Room ID copied to clipboard!');
      
      if (_roomId != null) {
        Clipboard.setData(ClipboardData(text: _roomId!));
      }
    });

    _playerJoinedSub = _socketService.onPlayerJoined.listen((data) {
      final player = data['player'];
      _addLog('👥 ${player['username']} joined the room!');
    });

    _chatMessageSub = _socketService.onChatMessage.listen((data) {
      final isOwnMessage = data['userId'] == _userId;
      final prefix = isOwnMessage ? '📤' : '📥';
      _addLog('$prefix ${data['username']}: ${data['message']}');
    });

    _chatHistorySub = _socketService.onChatHistory.listen((data) {
      final messages = data['messages'] as List;
      _addLog('📜 Received ${messages.length} messages');
      for (var msg in messages) {
        _addLog('  - ${msg['username']}: ${msg['message']}');
      }
    });

    _typingSub = _socketService.onUserTyping.listen((data) {
      if (data['userId'] != _userId) {
        _addLog('⌨️ ${data['username']} is ${data['isTyping'] ? "typing" : "stopped typing"}');
      }
    });

    _errorSub = _socketService.onError.listen((error) {
      _addLog('❌ Error: $error');
    });
  }

  void _addLog(String log) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)} $log');
    });
  }

  void _connect() {
    _socketService.connect(_userId, _username);
    _addLog('🔌 Connecting...');
  }

  void _createRoom() {
    _socketService.createRoom(
      userId: _userId,
      username: _username,
      gameType: 'blackjack',
      maxPlayers: 3,
    );
    _addLog('📝 Creating room...');
  }

  void _joinRoom() {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      _addLog('❌ Please enter a Room ID!');
      return;
    }

    _socketService.joinRoom(
      roomId: roomId,
      userId: _userId,
      username: _username,
    );
    
    setState(() {
      _roomId = roomId;
    });
    
    _addLog('🚪 Joining room: $roomId');
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Join Room',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter Room ID:',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _roomIdController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'blackjack_xxxxx',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 10),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinRoom();
            },
            child: const Text('Join', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_roomId == null) {
      _addLog('❌ No room joined!');
      return;
    }
    
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _socketService.sendMessage(
      roomId: _roomId!,
      userId: _userId,
      message: message,
    );
    _messageController.clear();
  }

  void _getChatHistory() {
    if (_roomId == null) {
      _addLog('❌ No room joined!');
      return;
    }

    _socketService.getChatHistory(roomId: _roomId!);
    _addLog('📜 Requesting chat history...');
  }

  void _startTyping() {
    if (_roomId == null) return;
    _socketService.sendTypingStart(
      roomId: _roomId!,
      userId: _userId,
      username: _username,
    );
  }

  void _stopTyping() {
    if (_roomId == null) return;
    _socketService.sendTypingStop(
      roomId: _roomId!,
      userId: _userId,
      username: _username,
    );
  }

  void _copyRoomId() {
    if (_roomId != null) {
      Clipboard.setData(ClipboardData(text: _roomId!));
      _addLog('📋 Room ID copied!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID copied!'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _roomCreatedSub?.cancel();
    _playerJoinedSub?.cancel();
    _chatMessageSub?.cancel();
    _chatHistorySub?.cancel();
    _typingSub?.cancel();
    _errorSub?.cancel();
    _messageController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;
    final buttonFontSize = isSmall ? 10.0 : 12.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Chat Test',
          style: TextStyle(fontSize: isSmall ? 16 : 18),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          if (_roomId != null)
            IconButton(
              icon: Icon(Icons.copy, size: isSmall ? 18 : 22),
              onPressed: _copyRoomId,
              tooltip: 'Copy Room ID',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar (Compact)
          Container(
            padding: EdgeInsets.all(isSmall ? 8 : 12),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _socketService.isConnected ? Icons.check_circle : Icons.cancel,
                      color: _socketService.isConnected ? Colors.green : Colors.red,
                      size: isSmall ? 16 : 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _socketService.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmall ? 4 : 6),
                Text(
                  'User: $_username',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isSmall ? 10 : 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_roomId != null) ...[
                  SizedBox(height: isSmall ? 4 : 6),
                  Container(
                    padding: EdgeInsets.all(isSmall ? 4 : 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _roomId!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmall ? 9 : 10,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.copy, size: isSmall ? 14 : 16),
                            onPressed: _copyRoomId,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Control Buttons (Compact)
          Container(
            padding: EdgeInsets.all(isSmall ? 6 : 8),
            color: Colors.grey[850],
            child: Column(
              children: [
                // Row 1: Connection & Room
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          onPressed: _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 8 : 10,
                              horizontal: isSmall ? 4 : 8,
                            ),
                          ),
                          child: Text(
                            'Connect',
                            style: TextStyle(fontSize: buttonFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          onPressed: _createRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 8 : 10,
                              horizontal: isSmall ? 4 : 8,
                            ),
                          ),
                          child: Text(
                            'Create',
                            style: TextStyle(fontSize: buttonFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          onPressed: _showJoinDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 8 : 10,
                              horizontal: isSmall ? 4 : 8,
                            ),
                          ),
                          child: Text(
                            'Join',
                            style: TextStyle(fontSize: buttonFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmall ? 4 : 6),
                // Row 2: Chat Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          onPressed: _getChatHistory,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 8 : 10,
                              horizontal: isSmall ? 4 : 8,
                            ),
                          ),
                          child: Text(
                            'History',
                            style: TextStyle(fontSize: buttonFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _logs.clear());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 8 : 10,
                              horizontal: isSmall ? 4 : 8,
                            ),
                          ),
                          child: Text(
                            'Clear',
                            style: TextStyle(fontSize: buttonFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logs Display
          Expanded(
            child: Container(
              color: Colors.black,
              child: _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: isSmall ? 48 : 64,
                            color: Colors.grey[700],
                          ),
                          SizedBox(height: isSmall ? 8 : 12),
                          Text(
                            'No activity yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isSmall ? 14 : 16,
                            ),
                          ),
                          SizedBox(height: isSmall ? 4 : 6),
                          Text(
                            'Click Connect to start!',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: isSmall ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(isSmall ? 6 : 8),
                      itemCount: _logs.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        Color logColor = Colors.white;

                        if (log.contains('❌')) {
                          logColor = Colors.red;
                        } else if (log.contains('✅') || log.contains('📥')) {
                          logColor = Colors.green;
                        } else if (log.contains('📤')) {
                          logColor = Colors.blue;
                        } else if (log.contains('⌨️')) {
                          logColor = Colors.yellow;
                        }

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: isSmall ? 1 : 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: logColor,
                              fontSize: isSmall ? 10 : 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Message Input (Compact)
          Container(
            padding: EdgeInsets.all(isSmall ? 6 : 8),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall ? 12 : 14,
                    ),
                    decoration: InputDecoration(
                      hintText: _roomId == null
                          ? 'Join a room first...'
                          : 'Type message...',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isSmall ? 11 : 13,
                      ),
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 12 : 16,
                        vertical: isSmall ? 8 : 10,
                      ),
                    ),
                    enabled: _roomId != null,
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        _startTyping();
                      } else {
                        _stopTyping();
                      }
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: isSmall ? 6 : 8),
                SizedBox(
                  width: isSmall ? 36 : 44,
                  height: isSmall ? 36 : 44,
                  child: IconButton(
                    onPressed: _roomId != null ? _sendMessage : null,
                    icon: Icon(
                      Icons.send,
                      size: isSmall ? 18 : 22,
                    ),
                    color: _roomId != null ? Colors.blue : Colors.grey,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}