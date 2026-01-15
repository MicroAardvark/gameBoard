// ====================================
// lib/screens/multiplayer_blackjack_screen.dart
// FIXED - Properly sets currentRoomId before navigation
// ====================================
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/user.dart';
import '../services/socket_service.dart';
import 'multiplayer_blackjack_game_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class MultiplayerBlackjackScreen extends StatefulWidget {
  final User user;

  const MultiplayerBlackjackScreen({super.key, required this.user});

  @override
  State<MultiplayerBlackjackScreen> createState() => _MultiplayerBlackjackScreenState();
}

class _MultiplayerBlackjackScreenState extends State<MultiplayerBlackjackScreen> {
  final SocketService _socketService = SocketService();
  
  List<Map<String, dynamic>> _availableRooms = [];
  bool _isLoadingRooms = false;
  bool _isConnecting = false;
  bool _isCreatingRoom = false;
  
  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;

  int _selectedMaxPlayers = 3;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToSocket();
    _setupSocketListeners();
  }

  void _connectToSocket() {
    setState(() => _isConnecting = true);
    
    _socketService.connect(
      widget.user.id,
      widget.user.username,
    );
    
    // Give it a moment to connect
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        _loadAvailableRooms();
      }
    });
  }

  void _setupSocketListeners() {
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          _isConnecting = false;
        });
        
        if (connected) {
          _loadAvailableRooms();
        }
      }
    });

    _roomCreatedSub = _socketService.onRoomCreated.listen((data) {
      if (mounted) {
        final roomId = data['roomId'];
        
        print('🎯 Room created event received: $roomId');
        
        // IMPORTANT: Set the currentRoomId immediately
        _socketService.currentRoomId = roomId;
        
        _showMessage('Room created successfully!');
        
        // Small delay to ensure socket is fully set up
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            // Navigate to game screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MultiplayerBlackjackGameScreen(
                  user: widget.user,
                  roomId: roomId,
                  isHost: true,
                ),
              ),
            ).then((_) {
              // Clear room ID when returning
              _socketService.currentRoomId = null;
              // Refresh rooms when returning
              _loadAvailableRooms();
            });
          }
        });
        
        setState(() => _isCreatingRoom = false);
      }
    });

    _errorSub = _socketService.onError.listen((error) {
      if (mounted) {
        _showError(error);
        setState(() {
          _isCreatingRoom = false;
        });
      }
    });
  }

  Future<void> _loadAvailableRooms() async {
    if (!_isConnected) return;
    
    setState(() => _isLoadingRooms = true);

    try {
      // Use HTTP API to fetch available rooms
      final response = await http.get(
        Uri.parse('${_socketService.baseUrl}/api/rooms/available/blackjack'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rooms = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _availableRooms = rooms.cast<Map<String, dynamic>>();
            _isLoadingRooms = false;
          });
        }
      } else {
        throw Exception('Failed to load rooms');
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
          _availableRooms = [];
        });
      }
    }
  }

  Future<String?> _getToken() async {
    return await AuthService.getToken();
  }

  void _createRoom() {
    if (!_isConnected) {
      _showError('Not connected to server');
      return;
    }

    setState(() => _isCreatingRoom = true);

    print('📝 Creating blackjack room...');

    _socketService.createRoom(
      userId: widget.user.id,
      username: widget.user.username,
      gameType: 'blackjack',
      maxPlayers: _selectedMaxPlayers,
    );
  }

  void _joinRoom(String roomId) {
    if (!_isConnected) {
      _showError('Not connected to server');
      return;
    }

    print('👤 Joining room: $roomId');

    // Set the room ID before joining
    _socketService.currentRoomId = roomId;

    _socketService.joinRoom(
      roomId: roomId,
      userId: widget.user.id,
      username: widget.user.username,
    );

    // Navigate to game screen immediately
    // The game screen will handle the join confirmation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerBlackjackGameScreen(
          user: widget.user,
          roomId: roomId,
          isHost: false,
        ),
      ),
    ).then((_) {
      // Clear room ID when returning
      _socketService.currentRoomId = null;
      // Refresh rooms when returning
      _loadAvailableRooms();
    });
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Create Room',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Max Players',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {_selectedMaxPlayers},
              onSelectionChanged: (Set<int> selected) {
                setState(() {
                  _selectedMaxPlayers = selected.first;
                });
              },
            ),
            SizedBox(height: 16),
            Text(
              'Room will be created with ${widget.user.username} as host.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createRoom();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavyDark,
            ),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryNavyLight,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade700,
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _roomCreatedSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D3B1F),
              Color(0xFF1E4A2D),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multiplayer Blackjack',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isConnecting
                                      ? Colors.orange
                                      : _isConnected
                                          ? AppColors.primaryNavyLight
                                          : Colors.red,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _isConnecting
                                    ? 'Connecting...'
                                    : _isConnected
                                        ? 'Connected'
                                        : 'Disconnected',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.textPrimary),
                      onPressed: _isLoadingRooms ? null : _loadAvailableRooms,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryNavyDark.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),

              // Create Room Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingRoom || !_isConnected
                        ? null
                        : _showCreateRoomDialog,
                    icon: _isCreatingRoom
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.textPrimary),
                            ),
                          )
                        : Icon(Icons.add_circle, size: 28),
                    label: Text(
                      _isCreatingRoom ? 'Creating Room...' : 'Create New Room',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavyDark,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.surfaceDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // Divider
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.textPrimary)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Available Rooms',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.textPrimary)),
                  ],
                ),
              ),

              // Rooms List
              Expanded(
                child: _buildRoomsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_isLoadingRooms) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.amber),
        ),
      );
    }

    if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: AppColors.textPrimary),
            SizedBox(height: 16),
            Text(
              'Not connected to server',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _connectToSocket,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavyDark,
              ),
            ),
          ],
        ),
      );
    }

    if (_availableRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino, size: 64, color: AppColors.textPrimary),
            SizedBox(height: 16),
            Text(
              'No rooms available',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Create a room to start playing!',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _availableRooms.length,
      itemBuilder: (context, index) {
        final room = _availableRooms[index];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final players = room['players'] as List;
    final maxPlayers = room['maxPlayers'] ?? 3;
    final roomId = room['roomId'] ?? '';
    final createdAt = room['createdAt'];
    
    // Calculate time since creation
    String timeAgo = 'Just now';
    if (createdAt != null) {
      final created = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(created);
      
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3), width: 2),
      ),
      color: Color(0xFF1E4A2D),
      child: InkWell(
        onTap: () => _joinRoom(roomId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.casino, color: Colors.amber, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Blackjack Room',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Text(
                      '${players.length}/$maxPlayers',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Players
              Wrap(
                spacing: 8,
                children: players.map((player) {
                  return Chip(
                    avatar: Icon(Icons.person, size: 16, color: AppColors.textPrimary),
                    label: Text(
                      player['username'] ?? 'Unknown',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    backgroundColor: AppColors.primaryNavyDark,
                  );
                }).toList(),
              ),
              
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Join Room',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}