// ====================================
// lib/screens/multiplayer_crazy_eights_lobby_screen.dart
// Multiplayer lobby for Crazy Eights (same flow as Blackjack lobby)
// ====================================
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import 'multiplayer_crazy_eights_game_screen.dart';

class MultiplayerCrazyEightsLobbyScreen extends StatefulWidget {
  final User user;

  const MultiplayerCrazyEightsLobbyScreen({super.key, required this.user});

  @override
  State<MultiplayerCrazyEightsLobbyScreen> createState() =>
      _MultiplayerCrazyEightsLobbyScreenState();
}

class _MultiplayerCrazyEightsLobbyScreenState
    extends State<MultiplayerCrazyEightsLobbyScreen> {
  final SocketService _socketService = SocketService();

  List<Map<String, dynamic>> _availableRooms = [];
  bool _isLoadingRooms = false;
  bool _isConnecting = false;
  bool _isCreatingRoom = false;

  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;

  // Crazy Eights supports 2–4 players
  int _selectedMaxPlayers = 4;
  bool _isConnected = false;

  static const String _gameType = 'crazyEights';

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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _loadAvailableRooms();
    });
  }

  void _setupSocketListeners() {
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (!mounted) return;

      setState(() {
        _isConnected = connected;
        _isConnecting = false;
      });

      if (connected) {
        _loadAvailableRooms();
      }
    });

    _roomCreatedSub = _socketService.onRoomCreated.listen((data) {
      if (!mounted) return;

      final roomId = data['roomId'] as String?;
      if (roomId == null || roomId.isEmpty) {
        _showError('Room created but roomId was missing.');
        setState(() => _isCreatingRoom = false);
        return;
      }

      // IMPORTANT: Set currentRoomId immediately
      _socketService.currentRoomId = roomId;

      _showMessage('Room created successfully!');

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerCrazyEightsGameScreen(
              user: widget.user,
              roomId: roomId,
              isHost: true,
            ),
          ),
        ).then((_) {
          _socketService.currentRoomId = null;
          _loadAvailableRooms();
        });
      });

      setState(() => _isCreatingRoom = false);
    });

    _errorSub = _socketService.onError.listen((error) {
      if (!mounted) return;

      _showError(error);
      setState(() => _isCreatingRoom = false);
    });
  }

  Future<void> _loadAvailableRooms() async {
    if (!_isConnected) return;

    setState(() => _isLoadingRooms = true);

    try {
      final token = await _getToken();
      final response = await http
          .get(
            Uri.parse('${_socketService.baseUrl}/api/rooms/available/$_gameType'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rooms = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          _availableRooms = rooms.cast<Map<String, dynamic>>();
          _isLoadingRooms = false;
        });
      } else {
        throw Exception('Failed to load rooms (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (!mounted) return;

      setState(() {
        _isLoadingRooms = false;
        _availableRooms = [];
      });
    }
  }

  Future<String?> _getToken() async {
    return AuthService.getToken();
  }

  void _createRoom() {
    if (!_isConnected) {
      _showError('Not connected to server');
      return;
    }

    setState(() => _isCreatingRoom = true);

    _socketService.createRoom(
      userId: widget.user.id,
      username: widget.user.username,
      gameType: _gameType,
      maxPlayers: _selectedMaxPlayers,
    );
  }

  void _joinRoom(String roomId) {
    if (!_isConnected) {
      _showError('Not connected to server');
      return;
    }

    // Set the room ID before joining
    _socketService.currentRoomId = roomId;

    _socketService.joinRoom(
      roomId: roomId,
      userId: widget.user.id,
      username: widget.user.username,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerCrazyEightsGameScreen(
          user: widget.user,
          roomId: roomId,
          isHost: false,
        ),
      ),
    ).then((_) {
      _socketService.currentRoomId = null;
      _loadAvailableRooms();
    });
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Room',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Max Players',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 2,
                  label: Text('2', style: Theme.of(context).textTheme.bodyMedium),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('3', style: Theme.of(context).textTheme.bodyMedium),
                ),
                ButtonSegment(
                  value: 4,
                  label: Text('4', style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
              selected: {_selectedMaxPlayers},
              onSelectionChanged: (Set<int> selected) {
                setState(() => _selectedMaxPlayers = selected.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Room will be created with ${widget.user.username} as host.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createRoom();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavyDark,
            ),
            child: Text('Create', style: Theme.of(context).textTheme.bodyMedium),
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
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
        decoration: const BoxDecoration(
          color: AppColors.primaryNavyDark,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Multiplayer Crazy Eights',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
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
                              const SizedBox(width: 8),
                              Text(
                                _isConnecting
                                    ? 'Connecting...'
                                    : _isConnected
                                        ? 'Connected'
                                        : 'Disconnected',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                      onPressed: _isLoadingRooms ? null : _loadAvailableRooms,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.primaryNavyDark.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),

              // Create Room Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingRoom || !_isConnected
                        ? null
                        : _showCreateRoomDialog,
                    icon: _isCreatingRoom
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.textPrimary),
                            ),
                          )
                        : const Icon(Icons.add_circle, size: 28),
                    label: Text(
                      _isCreatingRoom ? 'Creating Room...' : 'Create New Room',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: const [
                    Expanded(child: Divider(color: AppColors.textPrimary)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Available Rooms',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
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
              Expanded(child: _buildRoomsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_isLoadingRooms) {
      return const Center(
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
            const Icon(Icons.wifi_off, size: 64, color: AppColors.textPrimary),
            const SizedBox(height: 16),
            const Text(
              'Not connected to server',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _connectToSocket,
              icon: const Icon(Icons.refresh),
              label: Text('Retry', style: Theme.of(context).textTheme.bodyMedium),
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
          children: const [
            Icon(Icons.style, size: 64, color: AppColors.textPrimary),
            SizedBox(height: 16),
            Text(
              'No rooms available',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create a room to start playing!',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableRooms.length,
      itemBuilder: (context, index) => _buildRoomCard(_availableRooms[index]),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final players = (room['players'] as List?) ?? const [];
    final maxPlayers = room['maxPlayers'] ?? 4;
    final roomId = room['roomId'] ?? '';
    final createdAt = room['createdAt'];

    // Calculate time since creation
    var timeAgo = 'Just now';
    if (createdAt != null) {
      final created = DateTime.tryParse(createdAt.toString());
      if (created != null) {
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
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3), width: 2),
      ),
      color: AppColors.primaryNavyDark.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () => _joinRoom(roomId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.style, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crazy Eights Room',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Text(
                      '${players.length}/$maxPlayers',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((player) {
                  final username = (player as Map?)?['username']?.toString() ?? 'Unknown';
                  return Chip(
                    avatar: const Icon(Icons.person,
                        size: 16, color: AppColors.textPrimary),
                    label: Text(
                      username,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    backgroundColor: AppColors.primaryNavyDark,
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.arrow_forward, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Join Room',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
