// lib/services/voice_chat_service.dart
//
// VoiceChatService — platform-neutral WebRTC voice chat implementation.
//
// This is the base voice chat service used when platform-conditional imports
// are not in place. For production usage, prefer the platform-specific
// implementations:
//   - mobile_voice_service.dart (Android / iOS)
//   - web_voice_service.dart (Flutter Web — handles HTML AudioElement routing)
//
// Architecture:
//   - One RTCPeerConnection per remote participant.
//   - Signalling (offer/answer/ICE) is routed through [SocketService].
//   - UI state updates are delivered via broadcast [Stream]s.
//   - The offer/answer handshake flow:
//       New user joins → server fires 'voice_joined' event to existing users
//       Existing user creates offer → sends to new user via signalling server
//       New user responds with answer → connection established
//       ICE candidates exchanged → optimal network path selected
//
// Dependencies:
//   - flutter_webrtc: Provides RTCPeerConnection, MediaStream, etc.
//   - SocketService: Wraps Socket.IO for real-time signalling events.

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

// ====================================
// VOICE PARTICIPANT MODEL
// ====================================

/// Represents a participant in the active voice channel.
///
/// Immutable snapshot — a new instance is created when a participant's
/// mute status changes rather than mutating the existing object.
class VoiceParticipant {
  final String userId;
  final String username;
  final bool muted;

  VoiceParticipant({
    required this.userId,
    required this.username,
    this.muted = false,
  });

  /// Deserialises a [VoiceParticipant] from server JSON data.
  factory VoiceParticipant.fromJson(Map<String, dynamic> json) {
    return VoiceParticipant(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      muted: json['muted'] ?? false,
    );
  }
}

// ====================================
// VOICE CHAT SERVICE
// ====================================

class VoiceChatService {
  final SocketService _socketService;

  // ---- WebRTC State ----

  /// Active peer connections keyed by the remote user's ID.
  final Map<String, RTCPeerConnection> _peerConnections = {};

  /// The local microphone audio stream captured from this device.
  MediaStream? _localStream;

  /// Remote audio streams keyed by the remote user's ID.
  final Map<String, MediaStream> _remoteStreams = {};

  // ---- Session State ----

  bool _inVoiceChat = false;
  bool _isMuted = false;
  String? _currentRoomId;
  String? _currentUserId;

  // ---- Stream Controllers (UI bindings) ----

  /// Emits an updated participant list on every voice channel membership change.
  final _participantsController = StreamController<List<VoiceParticipant>>.broadcast();

  /// Emits per-user mute state changes as a map of { userId: muted }.
  final _muteStateController = StreamController<Map<String, bool>>.broadcast();

  /// Emits user-facing error messages.
  final _errorController = StreamController<String>.broadcast();

  /// In-memory list of current voice channel participants.
  final List<VoiceParticipant> _participants = [];

  // ---- ICE Server Configuration ----

  /// STUN servers used for NAT traversal. Multiple servers provide redundancy.
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  /// getUserMedia constraints — audio-only with quality enhancements enabled.
  final Map<String, dynamic> _mediaConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': false,
  };

  // ---- Public Stream Getters ----

  /// Emits the full participant list whenever the voice channel changes.
  Stream<List<VoiceParticipant>> get participantsStream => _participantsController.stream;

  /// Emits mute state changes as { userId → muted } maps.
  Stream<Map<String, bool>> get muteStateStream => _muteStateController.stream;

  /// Emits user-facing error messages.
  Stream<String> get errorStream => _errorController.stream;

  // ---- Public Getters ----

  bool get inVoiceChat => _inVoiceChat;
  bool get isMuted => _isMuted;

  /// Read-only snapshot of the current participant list.
  List<VoiceParticipant> get participants => List.unmodifiable(_participants);

  // ---- Constructor ----

  VoiceChatService(this._socketService) {
    _setupSocketListeners();
  }

  // ===================================
  // SOCKET LISTENERS SETUP
  // ===================================

  /// Registers all Socket.IO event listeners needed for voice chat signalling.
  ///
  /// Wires incoming socket events to the corresponding WebRTC and state
  /// management handlers in this service.
  void _setupSocketListeners() {
    // Participants list update — full sync from the server.
    _socketService.onVoiceParticipantsUpdated.listen((data) {
      _handleParticipantsUpdate(data);
    });

    // Another user joined the voice channel — initiate offers to connect.
    _socketService.onVoiceJoined.listen((data) {
      _handleVoiceJoined(data);
    });

    // A participant left — close their peer connection.
    _socketService.onVoiceParticipantLeft.listen((data) {
      _handleParticipantLeft(data);
    });

    // A participant's mute state changed.
    _socketService.onVoiceMuteUpdated.listen((data) {
      _handleMuteUpdate(data);
    });

    // This user was kicked from voice chat by a moderator or room host.
    _socketService.onVoiceUserKicked.listen((data) {
      if (data['userId'] == _currentUserId) {
        leaveVoiceChat();
        _errorController.add('You were removed from voice chat');
      }
    });

    // WebRTC signalling events.
    _socketService.onWebRTCOfferReceived.listen((data) {
      _handleWebRTCOffer(data);
    });

    _socketService.onWebRTCAnswerReceived.listen((data) {
      _handleWebRTCAnswer(data);
    });

    _socketService.onWebRTCIceCandidateReceived.listen((data) {
      _handleICECandidate(data);
    });

    // Server-side voice chat error.
    _socketService.onVoiceError.listen((data) {
      _errorController.add(data['error'] ?? 'Voice chat error');
    });
  }

  // ===================================
  // JOIN & LEAVE VOICE CHAT
  // ===================================

  /// Joins the voice channel for the specified room.
  ///
  /// Requests microphone access and notifies the signalling server.
  /// The server will then emit events to facilitate peer connections
  /// with existing voice channel participants.
  ///
  /// Parameters:
  ///   - [roomId]: The game room to join voice in.
  ///   - [userId]: The authenticated user's ID.
  ///   - [username]: Display name broadcast to other participants.
  Future<void> joinVoiceChat({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    try {
      // Prevent joining multiple times without leaving first.
      if (_inVoiceChat) {
        return;
      }

      _currentRoomId = roomId;
      _currentUserId = userId;

      // Request microphone access from the device.
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);

      if (_localStream == null) {
        throw Exception('Failed to get microphone access');
      }

      // Notify the server — other participants will receive a 'voice_joined' event.
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

  /// Leaves the voice channel and cleans up all WebRTC resources.
  Future<void> leaveVoiceChat() async {
    if (!_inVoiceChat) return;

    // Notify the server so other participants can clean up their side.
    _socketService.voiceLeave(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
    );

    await _cleanup();
  }

  /// Releases all WebRTC and media resources and resets session state.
  Future<void> _cleanup() async {
    // Close all active peer connections.
    for (var connection in _peerConnections.values) {
      await connection.close();
    }
    _peerConnections.clear();

    // Stop local microphone tracks and release the stream.
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }

    // Dispose remote streams.
    for (var stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();

    _participants.clear();
    _inVoiceChat = false;
    _isMuted = false;
    _currentRoomId = null;
    _currentUserId = null;

    // Push an empty list to notify the UI.
    _participantsController.add([]);
  }

  // ===================================
  // MUTE CONTROLS
  // ===================================

  /// Toggles the local microphone mute state.
  ///
  /// Disables or enables audio tracks on the local stream and notifies
  /// the server so other participants' UIs update accordingly.
  Future<void> toggleMute() async {
    if (!_inVoiceChat || _localStream == null) return;

    _isMuted = !_isMuted;

    // Toggle the enabled state of each local audio track.
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    // Broadcast the new mute state to all other participants via the server.
    _socketService.voiceMuteToggle(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      muted: _isMuted,
    );
  }

  // ===================================
  // WEBRTC PEER CONNECTION MANAGEMENT
  // ===================================

  /// Creates and configures a WebRTC peer connection for [targetUserId].
  ///
  /// Attaches local audio tracks and registers callbacks for ICE candidate
  /// exchange, remote track arrival, and connection state monitoring.
  Future<RTCPeerConnection> _createPeerConnection(String targetUserId) async {
    final connection = await createPeerConnection(_iceServers);

    // Attach local audio tracks so the remote peer can hear this user.
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        connection.addTrack(track, _localStream!);
      });
    }

    // Forward ICE candidates to the remote peer via the signalling server.
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

    // Store the incoming remote stream for later reference.
    connection.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[targetUserId] = event.streams[0];
      }
    };

    // Clean up on connection failure or closure.
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

  /// Creates a WebRTC offer and sends it to [targetUserId] to initiate a connection.
  Future<void> _createOffer(String targetUserId) async {
    try {
      final connection = await _createPeerConnection(targetUserId);

      // Create the SDP offer and set it as the local description.
      final offer = await connection.createOffer();
      await connection.setLocalDescription(offer);

      // Send the offer to the target peer via the signalling server.
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
      // Silently handle errors in production to avoid surfacing raw
      // WebRTC exceptions to the user.
    }
  }

  /// Creates a WebRTC answer in response to a received [offer] from [targetUserId].
  Future<void> _createAnswer(String targetUserId, RTCSessionDescription offer) async {
    try {
      final connection = await _createPeerConnection(targetUserId);

      // Apply the remote offer and generate a matching answer.
      await connection.setRemoteDescription(offer);
      final answer = await connection.createAnswer();
      await connection.setLocalDescription(answer);

      // Send the answer back to the offerer via the signalling server.
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
      // Silently handle errors in production.
    }
  }

  // ===================================
  // WEBRTC SIGNALLING HANDLERS
  // ===================================

  /// Handles a received WebRTC offer from a remote peer.
  ///
  /// Extracts the SDP offer from the socket event and responds
  /// with a WebRTC answer via [_createAnswer].
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

  /// Handles a received WebRTC answer from a remote peer.
  ///
  /// Sets the remote description on the existing peer connection,
  /// completing the offer/answer handshake.
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

  /// Handles a received ICE candidate from a remote peer.
  ///
  /// ICE candidates are exchanged after the offer/answer to find the optimal
  /// network path between the two peers.
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

  /// Handles the 'voice_joined' event.
  ///
  /// When the server confirms this user has joined, it provides the list of
  /// already-present participants. This user sends a WebRTC offer to each of
  /// them to establish audio connections.
  void _handleVoiceJoined(dynamic data) {
    final participantsData = data['participants'] as List?;
    if (participantsData == null) return;

    // Create peer connection offers to all existing participants.
    for (var participant in participantsData) {
      final userId = participant['userId'];
      if (userId != null && userId != _currentUserId) {
        _createOffer(userId);
      }
    }
  }

  /// Handles a full participant list update from the server.
  ///
  /// Replaces the entire in-memory list and emits it to UI listeners.
  void _handleParticipantsUpdate(dynamic data) {
    final participantsData = data['participants'] as List?;
    if (participantsData == null) return;

    _participants.clear();
    _participants.addAll(
      participantsData.map((json) => VoiceParticipant.fromJson(json))
    );

    _participantsController.add(_participants);
  }

  /// Handles a participant leaving the voice channel.
  ///
  /// Closes their peer connection and removes them from the participant list.
  void _handleParticipantLeft(dynamic data) {
    final userId = data['userId'];
    if (userId == null) return;

    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _remoteStreams.remove(userId);

    _participants.removeWhere((p) => p.userId == userId);
    _participantsController.add(_participants);
  }

  /// Handles a mute status update for a participant.
  ///
  /// Creates a new [VoiceParticipant] instance with the updated mute state
  /// (since the model is immutable) and emits updates to both stream controllers.
  void _handleMuteUpdate(dynamic data) {
    final userId = data['userId'];
    final muted = data['muted'] ?? false;

    // Replace the participant at the matching index with an updated instance.
    final index = _participants.indexWhere((p) => p.userId == userId);
    if (index != -1) {
      _participants[index] = VoiceParticipant(
        userId: _participants[index].userId,
        username: _participants[index].username,
        muted: muted,
      );
      _participantsController.add(_participants);
    }

    // Emit the mute change as a simple map for lightweight UI consumers.
    _muteStateController.add({userId: muted});
  }

  // ===================================
  // MODERATION
  // ===================================

  /// Reports a participant for voice chat abuse.
  ///
  /// Submits the report via the signalling server for review by platform
  /// moderators, in compliance with the platform's obligations under the
  /// UK Online Safety Act 2023.
  ///
  /// Parameters:
  ///   - [reportedUserId]: ID of the user being reported.
  ///   - [reportedUsername]: Display name of the user being reported.
  ///   - [reason]: Description or category of the inappropriate behaviour.
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

  /// Disposes the service, closing all stream controllers and leaving voice chat.
  ///
  /// Unlike the mobile implementation's dispose, this version closes the
  /// broadcast stream controllers as the service lifecycle is managed externally.
  void dispose() {
    leaveVoiceChat();
    _participantsController.close();
    _muteStateController.close();
    _errorController.close();
  }
}