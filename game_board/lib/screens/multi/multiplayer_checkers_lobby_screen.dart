// lib/screens/multiplayer_checkers_lobby_screen.dart
//
// TODO: Remove this entire file once the Checkers game is deleted from the
// project. It is only retained to avoid breaking the multiplayer lobby navigation.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../models/user.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import 'multiplayer_checkers_game_screen.dart';

/// Room browser for 2-player multiplayer Checkers.
///
/// Checkers is always exactly 2 players, so there is no player-count picker in
/// the create-room dialog. The room list is filtered server-side to only show
/// rooms with fewer than 2 players.
///
/// [_hasNavigated] guards against duplicate navigation when both [onRoomCreated]
/// and [_joinRoom] fire close together (e.g. if the creator's own event echoes
/// back while they are already navigating).
class MultiplayerCheckersLobbyScreen extends StatefulWidget {
  final User user;

  const MultiplayerCheckersLobbyScreen({super.key, required this.user});

  @override
  State<MultiplayerCheckersLobbyScreen> createState() => _MultiplayerCheckersLobbyScreenState();
}

class _MultiplayerCheckersLobbyScreenState extends State<MultiplayerCheckersLobbyScreen> {
  final SocketService _socketService = SocketService();

  List<Map<String, dynamic>> _availableRooms = [];
  bool    _isLoadingRooms = false;
  String? _currentRoomId;

  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _errorSub;

  /// Prevents double-navigation if both the socket callback and the join button
  /// fire before the route transition completes.
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _socketService.connect(widget.user.id, widget.user.username);
    _setupSocketListeners();
    _loadAvailableRooms();
  }

  @override
  void dispose() {
    _roomCreatedSub?.cancel();
    _connectionSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    _roomCreatedSub = _socketService.onRoomCreated.listen((data) {
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      final roomId = data['roomId'];
      final room   = data['room'];
      setState(() => _currentRoomId = roomId);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MultiplayerCheckersGameScreen(
          user:    widget.user,
          roomId:  roomId,
          players: (room['players'] as List).cast<Map<String, dynamic>>(),
        )),
      ).then((_) { setState(() => _currentRoomId = null); _loadAvailableRooms(); });
    });

    _connectionSub = _socketService.onConnectionChange.listen((_) { if (mounted) setState(() {}); });

    _errorSub = _socketService.onError.listen((error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    });
  }

  Future<void> _loadAvailableRooms() async {
    setState(() => _isLoadingRooms = true);
    try {
      final token    = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${_socketService.baseUrl}/api/rooms/available/checkers'),
        headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rooms = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Only show rooms that still have room for a second player.
            _availableRooms = rooms.cast<Map<String, dynamic>>()
                .where((r) => r['gameType'] == 'checkers' && (r['players'] as List).length < 2)
                .toList();
            _isLoadingRooms = false;
          });
        }
      } else {
        throw Exception('Failed to load rooms');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load rooms: $e')));
      }
    }
  }

  void _createRoom() {
    _socketService.createRoom(userId: widget.user.id, username: widget.user.username, gameType: 'checkers', maxPlayers: 2);
  }

  void _joinRoom(String roomId) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    setState(() => _currentRoomId = roomId);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MultiplayerCheckersGameScreen(
        user:    widget.user,
        roomId:  roomId,
        players: [], // Populated by the game screen once the server confirms the join.
      )),
    ).then((_) { setState(() => _currentRoomId = null); _loadAvailableRooms(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('Checkers Lobby', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A2332),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(Icons.circle, color: _socketService.isConnected ? Colors.green : Colors.orange, size: 12),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _socketService.isConnected ? _createRoom : null,
                icon: const Icon(Icons.add),
                label: const Text('Create New Game', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available Games', style: TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadAvailableRooms),
              ],
            ),
          ),

          Expanded(
            child: _isLoadingRooms
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFA500)))
                : _availableRooms.isEmpty
                    ? const Center(child: Text('No games available.\nCreate one to get started!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _availableRooms.length,
                        itemBuilder: (_, index) => _buildRoomCard(_availableRooms[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomId      = room['roomId'] as String;
    final players     = (room['players'] as List).cast<Map<String, dynamic>>();
    final hostUsername = players.isNotEmpty ? (players[0]['username'] ?? 'Unknown') : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFFA500), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$hostUsername\'s Game', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${players.length}/2 players', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _joinRoom(roomId),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}