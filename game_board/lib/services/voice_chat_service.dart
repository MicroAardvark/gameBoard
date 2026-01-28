// lib/services/voice_chat_service.dart
// WebRTC Voice Chat Service for Flutter
// FIXED: Works with existing SocketService architecture

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

/// Voice chat participant model
class VoiceParticipant {
  final String userId;
  final String username;
  final bool muted;

  VoiceParticipant({
    required this.userId,
    required this.username,
    this.muted = false,
  });

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) {
    return VoiceParticipant(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      muted: json['muted'] ?? false,
    );
  }
}

class VoiceChatService {
  final SocketService _socketService;
  
  // WebRTC peer connections: userId -> RTCPeerConnection
  final Map<String, RTCPeerConnection> _peerConnections = {};
  
  // Local audio stream
  MediaStream? _localStream;
  
  // Remote audio streams: userId -> MediaStream
  final Map<String, MediaStream> _remoteStreams = {};
  
  // State
  bool _inVoiceChat = false;
  bool _isMuted = false;
  String? _currentRoomId;
  String? _currentUserId;
  
  // Stream controllers for UI updates
  final _participantsController = StreamController<List<VoiceParticipant>>.broadcast();
  final _muteStateController = StreamController<Map<String, bool>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Participants list
  final List<VoiceParticipant> _participants = [];

  // ICE servers for NAT traversal
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  // Media constraints for audio-only
  final Map<String, dynamic> _mediaConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': false,
  };

  // Streams
  Stream<List<VoiceParticipant>> get participantsStream => _participantsController.stream;
  Stream<Map<String, bool>> get muteStateStream => _muteStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  // Getters
  bool get inVoiceChat => _inVoiceChat;
  bool get isMuted => _isMuted;
  List<VoiceParticipant> get participants => List.unmodifiable(_participants);

  VoiceChatService(this._socketService) {
    _setupSocketListeners();
  }

  // ===================================
  // SOCKET LISTENERS SETUP
  // ===================================

  void _setupSocketListeners() {
    // Voice participants updated
    _socketService.onVoiceParticipantsUpdated.listen((data) {
      _handleParticipantsUpdate(data);
    });

    // User joined voice
    _socketService.onVoiceJoined.listen((data) {
      _handleVoiceJoined(data);
    });

    // User left voice
    _socketService.onVoiceParticipantLeft.listen((data) {
      _handleParticipantLeft(data);
    });

    // Mute status updated
    _socketService.onVoiceMuteUpdated.listen((data) {
      _handleMuteUpdate(data);
    });

    // User was kicked
    _socketService.onVoiceUserKicked.listen((data) {
      if (data['userId'] == _currentUserId) {
        leaveVoiceChat();
        _errorController.add('You were removed from voice chat');
      }
    });

    // WebRTC signalling events
    _socketService.onWebRTCOfferReceived.listen((data) {
      _handleWebRTCOffer(data);
    });

    _socketService.onWebRTCAnswerReceived.listen((data) {
      _handleWebRTCAnswer(data);
    });

    _socketService.onWebRTCIceCandidateReceived.listen((data) {
      _handleICECandidate(data);
    });

    // Errors
    _socketService.onVoiceError.listen((data) {
      _errorController.add(data['error'] ?? 'Voice chat error');
    });
  }

  // ===================================
  // JOIN & LEAVE VOICE CHAT
  // ===================================

  /// Join voice chat in a room
  Future<void> joinVoiceChat({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    try {
      if (_inVoiceChat) {
        return;
      }
      
      _currentRoomId = roomId;
      _currentUserId = userId;

      // Get user media (microphone access)
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);
      
      if (_localStream == null) {
        throw Exception('Failed to get microphone access');
      }

      // Notify server via SocketService
      _socketService.voiceJoin(
        roomId: roomId,
        userId: userId,
        username: username,
      );

      _inVoiceChat = true;

    } catch (e) {
      _errorController.add('Failed to access microphone: $e');
      await _cleanup();
    }
  }

  /// Leave voice chat
  Future<void> leaveVoiceChat() async {
    if (!_inVoiceChat) return;

    // Notify server
    _socketService.voiceLeave(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
    );

    await _cleanup();
  }

  /// Cleanup all WebRTC resources
  Future<void> _cleanup() async {
    // Close all peer connections
    for (var connection in _peerConnections.values) {
      await connection.close();
    }
    _peerConnections.clear();

    // Stop local stream
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }

    // Clear remote streams
    for (var stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();

    _participants.clear();
    _inVoiceChat = false;
    _isMuted = false;
    _currentRoomId = null;
    _currentUserId = null;

    _participantsController.add([]);
  }

  // ===================================
  // MUTE CONTROLS
  // ===================================

  /// Toggle mute status
  Future<void> toggleMute() async {
    if (!_inVoiceChat || _localStream == null) return;

    _isMuted = !_isMuted;

    // Mute/unmute local audio tracks
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    // Notify server
    _socketService.voiceMuteToggle(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      muted: _isMuted,
    );
  }

  // ===================================
  // WEBRTC PEER CONNECTION MANAGEMENT
  // ===================================

  /// Create peer connection for a specific user
  Future<RTCPeerConnection> _createPeerConnection(String targetUserId) async {
    final connection = await createPeerConnection(_iceServers);

    // Add local stream to connection
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        connection.addTrack(track, _localStream!);
      });
    }

    // Handle ICE candidates
    connection.onIceCandidate = (candidate) {
      if (candidate != null) {
        _socketService.sendWebRTCIceCandidate(
          roomId: _currentRoomId!,
          targetUserId: targetUserId,
          fromUserId: _currentUserId!,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    // Handle remote stream
    connection.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[targetUserId] = event.streams[0];
      }
    };

    // Handle connection state changes
    connection.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _peerConnections.remove(targetUserId);
        _remoteStreams.remove(targetUserId);
      }
    };

    _peerConnections[targetUserId] = connection;
    return connection;
  }

  /// Create and send offer to peer
  Future<void> _createOffer(String targetUserId) async {
    try {
      final connection = await _createPeerConnection(targetUserId);
      
      final offer = await connection.createOffer();
      await connection.setLocalDescription(offer);

      _socketService.sendWebRTCOffer(
        roomId: _currentRoomId!,
        targetUserId: targetUserId,
        fromUserId: _currentUserId!,
        offer: {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      );
    } catch (e) {
      // Handle error silently in production
    }
  }

  /// Create and send answer to peer
  Future<void> _createAnswer(String targetUserId, RTCSessionDescription offer) async {
    try {
      final connection = await _createPeerConnection(targetUserId);
      
      await connection.setRemoteDescription(offer);
      final answer = await connection.createAnswer();
      await connection.setLocalDescription(answer);

      _socketService.sendWebRTCAnswer(
        roomId: _currentRoomId!,
        targetUserId: targetUserId,
        fromUserId: _currentUserId!,
        answer: {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      );
    } catch (e) {
      // Handle error silently in production
    }
  }

  // ===================================
  // WEBRTC SIGNALLING HANDLERS
  // ===================================

  void _handleWebRTCOffer(dynamic data) async {
    final fromUserId = data['fromUserId'];
    final offerData = data['offer'];

    if (fromUserId == null || offerData == null) return;

    final offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );

    await _createAnswer(fromUserId, offer);
  }

  void _handleWebRTCAnswer(dynamic data) async {
    final fromUserId = data['fromUserId'];
    final answerData = data['answer'];

    if (fromUserId == null || answerData == null) return;

    final connection = _peerConnections[fromUserId];
    if (connection == null) return;

    final answer = RTCSessionDescription(
      answerData['sdp'],
      answerData['type'],
    );

    await connection.setRemoteDescription(answer);
  }

  void _handleICECandidate(dynamic data) async {
    final fromUserId = data['fromUserId'];
    final candidateData = data['candidate'];

    if (fromUserId == null || candidateData == null) return;

    final connection = _peerConnections[fromUserId];
    if (connection == null) return;

    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );

    await connection.addCandidate(candidate);
  }

  // ===================================
  // PARTICIPANT MANAGEMENT
  // ===================================

  void _handleVoiceJoined(dynamic data) {
    final participantsData = data['participants'] as List?;
    if (participantsData == null) return;

    // Create offers to all existing participants
    for (var participant in participantsData) {
      final userId = participant['userId'];
      if (userId != null && userId != _currentUserId) {
        _createOffer(userId);
      }
    }
  }

  void _handleParticipantsUpdate(dynamic data) {
    final participantsData = data['participants'] as List?;
    if (participantsData == null) return;

    _participants.clear();
    _participants.addAll(
      participantsData.map((json) => VoiceParticipant.fromJson(json))
    );

    _participantsController.add(_participants);
  }

  void _handleParticipantLeft(dynamic data) {
    final userId = data['userId'];
    if (userId == null) return;

    // Close peer connection
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _remoteStreams.remove(userId);

    // Update participants list
    _participants.removeWhere((p) => p.userId == userId);
    _participantsController.add(_participants);
  }

  void _handleMuteUpdate(dynamic data) {
    final userId = data['userId'];
    final muted = data['muted'] ?? false;

    // Update participant mute status
    final index = _participants.indexWhere((p) => p.userId == userId);
    if (index != -1) {
      _participants[index] = VoiceParticipant(
        userId: _participants[index].userId,
        username: _participants[index].username,
        muted: muted,
      );
      _participantsController.add(_participants);
    }

    // Update mute state stream for UI
    _muteStateController.add({userId: muted});
  }

  // ===================================
  // MODERATION
  // ===================================

  /// Report a user for voice chat abuse
  void reportUser({
    required String reportedUserId,
    required String reportedUsername,
    required String reason,
  }) {
    _socketService.voiceReportUser(
      roomId: _currentRoomId!,
      reportedUserId: reportedUserId,
      reportedUsername: reportedUsername,
      reason: reason,
      reporterId: _currentUserId!,
    );
  }

  // ===================================
  // CLEANUP
  // ===================================

  void dispose() {
    leaveVoiceChat();
    _participantsController.close();
    _muteStateController.close();
    _errorController.close();
  }
}