// lib/screens/multiplayer_blackjack_lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../models/user.dart';
import '../../services/socket_service.dart';
import 'multiplayer_blackjack_game_screen.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Room browser and creation screen for multiplayer Blackjack.
///
/// Available rooms are fetched from the REST API rather than via Socket.IO so
/// the list is available immediately without needing an active room subscription.
/// Creating a room fires a Socket.IO event; the server responds with
/// [onRoomCreated], at which point [currentRoomId] is set and we navigate to
/// [MultiplayerBlackjackGameScreen] as host.
///
/// Joining a room navigates immediately to the game screen (as non-host),
/// letting the game screen handle the join confirmation from the server.
class MultiplayerBlackjackScreen extends StatefulWidget {
  final User user;

  const MultiplayerBlackjackScreen({super.key, required this.user});

  @override
  State<MultiplayerBlackjackScreen> createState() => _MultiplayerBlackjackScreenState();
}

class _MultiplayerBlackjackScreenState extends State<MultiplayerBlackjackScreen> {
  final SocketService _socketService = SocketService();

  List<Map<String, dynamic>> _availableRooms = [];
  bool _isLoadingRooms  = false;
  bool _isConnecting    = false;
  bool _isCreatingRoom  = false;

  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;

  int  _selectedMaxPlayers = 3;
  bool _isConnected        = false;

  @override
  void initState() {
    super.initState();
    if (_socketService.isConnected) {
      setState(() { _isConnected = true; _isConnecting = false; });
      _loadAvailableRooms();
    } else {
      _connectToSocket();
    }
    _setupSocketListeners();
  }

  void _connectToSocket() {
    setState(() => _isConnecting = true);
    _socketService.connect(widget.user.id, widget.user.username);

    // Poll once after 2 s as a fallback; the connection listener will also
    // trigger _loadAvailableRooms when the socket connects.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (_socketService.isConnected) setState(() { _isConnected = true; _isConnecting = false; });
        _loadAvailableRooms();
      }
    });
  }

  void _setupSocketListeners() {
    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (mounted) {
        setState(() { _isConnected = connected; _isConnecting = false; });
        if (connected) _loadAvailableRooms();
      }
    });

    _roomCreatedSub = _socketService.onRoomCreated.listen((data) {
      if (!mounted) return;
      final roomId = data['roomId'] as String;

      // Setting currentRoomId before navigation ensures the game screen can
      // reference it during its initState before any events arrive.
      _socketService.currentRoomId = roomId;
      _showMessage('Room created successfully!');

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MultiplayerBlackjackGameScreen(user: widget.user, roomId: roomId, isHost: true)),
        ).then((_) {
          _socketService.currentRoomId = null;
          _loadAvailableRooms();
        });
      });

      setState(() => _isCreatingRoom = false);
    });

    _errorSub = _socketService.onError.listen((error) {
      if (mounted) { _showError(error); setState(() => _isCreatingRoom = false); }
    });
  }

  Future<void> _loadAvailableRooms() async {
    if (!_isConnected) return;
    setState(() => _isLoadingRooms = true);
    try {
      final response = await http.get(
        Uri.parse('${_socketService.baseUrl}/api/rooms/available/blackjack'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${await _getToken()}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rooms = jsonDecode(response.body);
        if (mounted) setState(() { _availableRooms = rooms.cast<Map<String, dynamic>>(); _isLoadingRooms = false; });
      } else {
        throw Exception('Failed to load rooms');
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (mounted) setState(() { _isLoadingRooms = false; _availableRooms = []; });
    }
  }

  Future<String?> _getToken() => AuthService.getToken();

  void _createRoom() {
    if (!_isConnected) { _showError('Not connected to server'); return; }
    setState(() => _isCreatingRoom = true);
    _socketService.createRoom(userId: widget.user.id, username: widget.user.username, gameType: 'blackjack', maxPlayers: _selectedMaxPlayers);
  }

  void _joinRoom(String roomId) {
    if (!_isConnected) { _showError('Not connected to server'); return; }
    _socketService.currentRoomId = roomId;
    _socketService.joinRoom(roomId: roomId, userId: widget.user.id, username: widget.user.username);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MultiplayerBlackjackGameScreen(user: widget.user, roomId: roomId, isHost: false)),
    ).then((_) { _socketService.currentRoomId = null; _loadAvailableRooms(); });
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Room', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Max Players', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 2, label: Text('2', style: Theme.of(context).textTheme.bodyMedium)),
                ButtonSegment(value: 3, label: Text('3', style: Theme.of(context).textTheme.bodyMedium)),
              ],
              selected: {_selectedMaxPlayers},
              onSelectionChanged: (selected) => setState(() => _selectedMaxPlayers = selected.first),
            ),
            const SizedBox(height: 16),
            Text('Room will be created with ${widget.user.username} as host.', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.grey[400])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium)),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _createRoom(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavyDark),
            child: Text('Create', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primaryNavyLight, duration: const Duration(seconds: 2)));
  }

  void _showError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 5)));
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
        color: AppColors.primaryNavyDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header with connection status and refresh.
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Multiplayer Blackjack', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isConnecting ? Colors.orange : _isConnected ? AppColors.primaryNavyLight : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isConnecting ? 'Connecting...' : _isConnected ? 'Connected' : 'Disconnected',
                                style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                      onPressed: _isLoadingRooms ? null : _loadAvailableRooms,
                      style: IconButton.styleFrom(backgroundColor: AppColors.primaryNavyDark.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ),

              // Create room CTA.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingRoom || !_isConnected ? null : _showCreateRoomDialog,
                    icon: _isCreatingRoom
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.textPrimary)))
                        : const Icon(Icons.add_circle, size: 28),
                    label: Text(_isCreatingRoom ? 'Creating Room...' : 'Create New Room', style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavyDark,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.surfaceDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              // Divider with "Available Rooms" label.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.textPrimary)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Available Rooms', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    const Expanded(child: Divider(color: AppColors.textPrimary)),
                  ],
                ),
              ),

              Expanded(child: _buildRoomsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_isLoadingRooms) return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.amber)));

    if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: AppColors.textPrimary),
            const SizedBox(height: 16),
            const Text('Not connected to server', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _connectToSocket,
              icon: const Icon(Icons.refresh),
              label: Text('Retry', style: Theme.of(context).textTheme.bodyMedium),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavyDark),
            ),
          ],
        ),
      );
    }

    if (_availableRooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino, size: 64, color: AppColors.textPrimary),
            SizedBox(height: 16),
            Text('No rooms available', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 18)),
            SizedBox(height: 8),
            Text('Create a room to start playing!', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableRooms.length,
      itemBuilder: (_, index) => _buildRoomCard(_availableRooms[index]),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final players   = room['players'] as List;
    final maxPlayers = room['maxPlayers'] ?? 3;
    final roomId    = room['roomId'] ?? '';
    final createdAt = room['createdAt'];

    // Human-readable creation time for the room card subtitle.
    String timeAgo = 'Just now';
    if (createdAt != null) {
      final diff = DateTime.now().difference(DateTime.parse(createdAt));
      if      (diff.inMinutes < 1)  timeAgo = 'Just now';
      else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
      else if (diff.inHours   < 24) timeAgo = '${diff.inHours}h ago';
      else                           timeAgo = '${diff.inDays}d ago';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.withValues(alpha: 0.3), width: 2)),
      color: const Color(0xFF1E4A2D),
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
                  const Icon(Icons.casino, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Blackjack Room', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(timeAgo, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber, width: 1)),
                    child: Text('${players.length}/$maxPlayers', style: const TextStyle(fontFamily: 'Inter', color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: players.map((player) => Chip(
                  avatar: const Icon(Icons.person, size: 16, color: AppColors.textPrimary),
                  label: Text(player['username'] ?? 'Unknown', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14)),
                  backgroundColor: AppColors.primaryNavyDark,
                )).toList(),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text('Join Room', style: TextStyle(fontFamily: 'Inter', color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}