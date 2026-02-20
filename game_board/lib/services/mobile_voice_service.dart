// ====================================
// lib/services/mobile_voice_service.dart
// WebRTC Voice Chat Service (MOBILE)
// ====================================
//
// Mobile-specific implementation of the WebRTC voice chat service.
//
// This file should be used on Android and iOS targets. For web, see
// web_voice_service.dart which handles web-specific audio routing via
// HTML AudioElement objects.
//
// Key differences from the web implementation:
//   - Audio playback is handled automatically by the flutter_webrtc plugin
//     on mobile — no manual AudioElement management is required.
//   - Uses a singleton pattern to prevent duplicate instances from being
//     created across widget rebuilds.
//   - onTrack audio tracks are explicitly enabled to ensure playback
//     functions correctly on physical devices.
//
// Architecture:
//   - One RTCPeerConnection is created per remote participant.
//   - ICE candidates are exchanged via the signalling server (SocketService).
//   - The offer/answer WebRTC negotiation flow is:
//       Joining user → sends offer to each existing participant
//       Existing participant → receives offer, sends answer back
//   - State changes are broadcast via Dart Streams for the UI to observe.

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

// ====================================
// VOICE PARTICIPANT MODEL
// ====================================

/// Represents a single participant in the voice chat channel.
///
/// Immutable; a new instance is created whenever a participant's state
/// (e.g., mute status) changes.
class VoiceParticipant {
  final String userId;
  final String username;
  final bool muted;

  VoiceParticipant({
    required this.userId,
    required this.username,
    this.muted = false,
  });

  /// Deserialises a [VoiceParticipant] from a server-provided JSON map.
  ///
  /// Handles null or malformed data defensively by returning a participant
  /// with empty fields rather than throwing, preventing a bad payload from
  /// crashing the voice chat session.
  factory VoiceParticipant.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return VoiceParticipant(
        userId: '',
        username: '',
        muted: false,
      );
    }

    return VoiceParticipant(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      muted: json['muted'] == true,
    );
  }
}

// ====================================
// VOICE CHAT SERVICE (MOBILE)
// ====================================

class VoiceChatService {
  /// Reference to the shared socket service for signalling.
  final SocketService _socketService;

  /// Singleton instance — prevents duplicate WebRTC connections
  /// from being created if the service is accessed multiple times.
  static VoiceChatService? _instance;

  // ---- WebRTC State ----

  /// Active peer connections keyed by remote user ID.
  final Map<String, RTCPeerConnection> _peerConnections = {};

  /// Remote media streams keyed by remote user ID.
  final Map<String, MediaStream> _remoteStreams = {};

  /// Current list of participants in the voice channel.
  final List<VoiceParticipant> _participants = [];

  /// The local microphone stream captured from this device.
  MediaStream? _localStream;

  // ---- Session State ----

  /// Whether this user is currently in a voice chat session.
  bool _inVoiceChat = false;

  /// Whether this user's microphone is currently muted.
  bool _isMuted = false;

  /// The ID of the room this voice session belongs to.
  String? _currentRoomId;

  /// The ID of the currently authenticated user.
  String? _currentUserId;

  // ---- Stream Controllers (broadcast to UI) ----

  /// Emits an updated participants list whenever the voice channel membership changes.
  final _participantsController =
      StreamController<List<VoiceParticipant>>.broadcast();

  /// Emits error messages (e.g., microphone denied) for the UI to display.
  final _errorController = StreamController<String>.broadcast();

  // ---- ICE Server Configuration ----

  /// STUN servers used for NAT traversal during peer connection establishment.
  /// Multiple Google STUN servers are listed for redundancy.
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  // ================= GETTERS =================

  /// Stream that emits a new list whenever voice channel participants change.
  Stream<List<VoiceParticipant>> get participantsStream =>
      _participantsController.stream;

  /// Stream that emits user-facing error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Whether the user is currently connected to voice chat.
  bool get inVoiceChat => _inVoiceChat;

  /// Whether the user's microphone is currently muted.
  bool get isMuted => _isMuted;

  /// A read-only snapshot of the current participant list.
  List<VoiceParticipant> get participants =>
      List.unmodifiable(_participants);

  // ================= CONSTRUCTOR =================

  /// Returns the singleton instance, creating it on first call.
  factory VoiceChatService(SocketService socketService) {
    return _instance ??= VoiceChatService._internal(socketService);
  }

  /// Private constructor — sets up socket listeners immediately on creation.
  VoiceChatService._internal(this._socketService) {
    _setupSocketListeners();
    print('📱 VoiceChatService (MOBILE) initialised (singleton)');
  }

  // ================= JOIN / LEAVE =================

  /// Joins the voice channel for the given room.
  ///
  /// Requests microphone access from the device, then notifies the server
  /// that this user has joined the voice channel. Peer connections to
  /// existing participants will be initiated by the server notifying this
  /// client of those users via the [onVoiceJoined] socket event.
  ///
  /// Parameters:
  ///   - [roomId]: The game room to join voice in.
  ///   - [userId]: The authenticated user's ID.
  ///   - [username]: The user's display name, sent to other participants.
  Future<void> joinVoiceChat({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    try {
      _currentRoomId = roomId;
      _currentUserId = userId;

      // Request microphone access with noise suppression and echo cancellation
      // enabled for a better voice chat experience.
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      print('🎤 Microphone access granted');

      // Notify the server — it will inform other participants to initiate
      // WebRTC peer connections with this user.
      _socketService.voiceJoin(
        roomId: roomId,
        userId: userId,
        username: username,
      );

      _inVoiceChat = true;
    } catch (e) {
      // Microphone access was denied or an error occurred — clean up
      // any partial state and surface the error to the UI.
      print('❌ Microphone access error: $e');
      _errorController.add('Microphone access denied');
      await _cleanup();
    }
  }

  /// Leaves the voice channel and releases all WebRTC and media resources.
  ///
  /// Notifies the server of the departure so other participants can close
  /// their peer connections with this user.
  Future<void> leaveVoiceChat() async {
    if (!_inVoiceChat) return;

    print('👋 Leaving voice chat');

    _socketService.voiceLeave(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
    );

    await _cleanup();
  }

  // ================= MUTE =================

  /// Toggles the local microphone mute state.
  ///
  /// Disabling audio tracks locally stops audio from being transmitted over
  /// the peer connections. The server is also notified so other participants'
  /// UIs can show the correct mute indicator for this user.
  Future<void> toggleMute() async {
    if (_localStream == null) return;

    _isMuted = !_isMuted;

    // Enable or disable each audio track in the local stream.
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }

    print('🔇 Mute toggled: $_isMuted');

    // Notify the server so other participants see the updated mute status.
    _socketService.voiceMuteToggle(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      muted: _isMuted,
    );
  }

  // ================= REPORT =================

  /// Reports another voice chat participant for inappropriate behaviour.
  ///
  /// Sends the report via the signalling server. Only valid during an active
  /// voice session. For HTTP-based reporting outside voice chat, use
  /// FriendsService.reportUser().
  ///
  /// Parameters:
  ///   - [reportedUserId]: The ID of the user being reported.
  ///   - [reportedUsername]: The username of the user being reported.
  ///   - [reason]: The reason for the report.
  void reportUser({
    required String reportedUserId,
    required String reportedUsername,
    required String reason,
  }) {
    if (!_inVoiceChat) return;

    _socketService.voiceReportUser(
      roomId: _currentRoomId!,
      reportedUserId: reportedUserId,
      reportedUsername: reportedUsername,
      reason: reason,
      reporterId: _currentUserId!,
    );
  }

  // ================= PEER CONNECTION =================

  /// Creates and configures a WebRTC peer connection for a remote participant.
  ///
  /// Attaches local audio tracks to the connection so they are transmitted
  /// to the remote peer. Sets up callbacks for:
  ///   - [onTrack]: Receiving remote audio streams.
  ///   - [onIceCandidate]: Forwarding ICE candidates via the signalling server.
  ///   - [onConnectionState]: Detecting failed/closed connections and cleaning up.
  ///
  /// The created connection is stored in [_peerConnections] keyed by [userId].
  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    print('🔗 Creating peer connection with $userId');

    final pc = await createPeerConnection(_iceServers);

    // Add local microphone tracks so the remote peer can hear this user.
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // Handle incoming audio tracks from the remote peer.
    pc.onTrack = (RTCTrackEvent event) {
      print('🎵 Received remote track from $userId');

      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams[0];
        _remoteStreams[userId] = remoteStream;

        // On mobile, flutter_webrtc handles audio routing automatically;
        // we just need to ensure tracks are active.
        _playRemoteAudioMobile(userId, remoteStream);
      }
    };

    // Forward ICE candidates to the remote peer via the signalling server.
    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        print('🧊 Sending ICE candidate to $userId');
        _socketService.sendWebRTCIceCandidate(
          roomId: _currentRoomId!,
          targetUserId: userId,
          fromUserId: _currentUserId!,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    // Clean up stale state when a connection fails or is closed.
    pc.onConnectionState = (state) {
      print('🔌 Connection state with $userId: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ Connected to $userId');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print('❌ Connection failed/closed with $userId');
        _peerConnections.remove(userId);
        _remoteStreams.remove(userId);
      }
    };

    // Log ICE connection state changes for debugging purposes.
    pc.onIceConnectionState = (state) {
      print('🧊 ICE connection state with $userId: $state');
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  // ================= MOBILE AUDIO PLAYBACK =================

  /// Ensures remote audio tracks are active and playable on mobile.
  ///
  /// On mobile, the flutter_webrtc plugin automatically routes audio from
  /// RTCPeerConnection tracks to the device speaker once the connection is
  /// established. This method explicitly enables each track as a safeguard,
  /// since tracks can sometimes arrive in a disabled state.
  ///
  /// No manual AudioElement management is needed on mobile — this is a
  /// key difference from the web implementation.
  void _playRemoteAudioMobile(String userId, MediaStream stream) {
    print('🔊 Setting up audio playback for $userId');

    for (final track in stream.getAudioTracks()) {
      track.enabled = true;
      print('✅ Audio track enabled for $userId: ${track.id}');
    }

    // flutter_webrtc handles actual audio routing to the device speaker.
  }

  // ================= SOCKET LISTENERS =================

  /// Registers all Socket.IO event listeners for voice chat signalling.
  ///
  /// This method wires the socket events from [SocketService] to the
  /// WebRTC peer connection logic in this service. All signalling events
  /// are received here and trigger the appropriate WebRTC actions.
  void _setupSocketListeners() {
    // ---- Participants Updated ----
    // Received whenever the server sends a full list of voice channel members.
    // Replaces the existing list entirely (full sync rather than delta update).
    _socketService.onVoiceParticipantsUpdated.listen((data) {
      final list = data['participants'] as List?;
      if (list == null) return;

      print('👥 Participants updated: ${list.length} participants');

      _participants
        ..clear()
        ..addAll(list.map((e) => VoiceParticipant.fromJson(e)));

      if (!_participantsController.isClosed) {
        _participantsController.add(_participants);
      }
    });

    // ---- New User Joined ----
    // Received when another user joins the voice channel.
    // The joining user's client initiates the WebRTC offer to establish the connection.
    _socketService.onVoiceJoined.listen((data) async {
      final peerId = data['userId'];
      print('👤 User joined voice: $peerId');

      // Ignore self-join events (fired when this user first joins).
      if (peerId == _currentUserId) {
        print('↩️ Ignoring self-join');
        return;
      }

      // Prevent duplicate connections to the same peer.
      if (_peerConnections.containsKey(peerId)) {
        print('⚠️ Already have connection with $peerId');
        return;
      }

      // Initiate the WebRTC handshake by creating and sending an offer.
      print('📞 Initiating call to $peerId');
      final pc = await _createPeerConnection(peerId);

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      print('📤 Sending offer to $peerId');
      _socketService.sendWebRTCOffer(
        roomId: _currentRoomId!,
        targetUserId: peerId,
        fromUserId: _currentUserId!,
        offer: offer.toMap(),
      );
    });

    // ---- Offer Received ----
    // Received when a remote peer has initiated a WebRTC connection to this user.
    // Respond by creating an answer to complete the handshake.
    _socketService.onWebRTCOfferReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final offer = data['offer'];

      print('📥 Received offer from $peerId');

      if (peerId == null || offer == null) {
        print('⚠️ Invalid offer data');
        return;
      }

      if (peerId == _currentUserId) {
        print('↩️ Ignoring offer from self');
        return;
      }

      final pc = await _createPeerConnection(peerId);

      // Set the remote description from the offer, then create and send an answer.
      print('🤝 Setting remote description and creating answer');
      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      print('📤 Sending answer to $peerId');
      _socketService.sendWebRTCAnswer(
        roomId: _currentRoomId!,
        targetUserId: peerId,
        fromUserId: _currentUserId!,
        answer: answer.toMap(),
      );
    });

    // ---- Answer Received ----
    // Received in response to an offer this client previously sent.
    // Completes the WebRTC handshake by setting the remote description.
    _socketService.onWebRTCAnswerReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final answer = data['answer'];

      print('📥 Received answer from $peerId');

      if (peerId == null || answer == null) {
        print('⚠️ Invalid answer data');
        return;
      }

      final pc = _peerConnections[peerId];
      if (pc == null) {
        print('❌ No peer connection found for $peerId');
        return;
      }

      print('🤝 Setting remote description from answer');
      await pc.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    });

    // ---- ICE Candidate Received ----
    // ICE candidates are exchanged after the offer/answer to establish
    // the optimal network path between peers (NAT traversal).
    _socketService.onWebRTCIceCandidateReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final candidate = data['candidate'];

      print('🧊 Received ICE candidate from $peerId');

      if (peerId == null || peerId is! String) {
        print('⚠️ Invalid peer ID');
        return;
      }

      if (candidate == null) {
        print('⚠️ Null candidate');
        return;
      }

      final pc = _peerConnections[peerId];
      if (pc == null) {
        print('⚠️ No peer connection for ICE candidate from $peerId');
        return;
      }

      try {
        await pc.addCandidate(
          RTCIceCandidate(
            candidate['candidate'],
            candidate['sdpMid'],
            candidate['sdpMLineIndex'],
          ),
        );
        print('✅ ICE candidate added for $peerId');
      } catch (e) {
        print('❌ Error adding ICE candidate: $e');
      }
    });

    // ---- Participant Left ----
    // Received when another user leaves the voice channel.
    // Closes their peer connection and removes them from the participant list.
    _socketService.onVoiceParticipantLeft.listen((data) async {
      final peerId = data['userId'];
      print('👋 User left voice: $peerId');

      if (peerId != null) {
        final pc = _peerConnections.remove(peerId);
        await pc?.close();
        _remoteStreams.remove(peerId);

        _participants.removeWhere((p) => p.userId == peerId);
        if (!_participantsController.isClosed) {
          _participantsController.add(_participants);
        }
      }
    });
  }

  // ================= CLEANUP =================

  /// Releases all voice chat resources and resets service state.
  ///
  /// Closes all peer connections, stops the local microphone stream,
  /// clears remote streams, and resets all session flags. Called on both
  /// normal leave and error paths.
  Future<void> _cleanup() async {
    print('🧹 Cleaning up voice chat');

    // Close all active peer connections.
    for (final pc in _peerConnections.values) {
      await pc.close();
    }

    _peerConnections.clear();
    _remoteStreams.clear();
    _participants.clear();

    // Notify UI that the participant list is now empty.
    if (!_participantsController.isClosed) {
      _participantsController.add([]);
    }

    // Stop microphone tracks and dispose of the local stream.
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();

    _localStream = null;
    _inVoiceChat = false;
    _isMuted = false;
  }

  /// Disposes the service when it is no longer needed.
  ///
  /// Note: Stream controllers are intentionally not closed here because
  /// they are broadcast streams that may still have active listeners at
  /// the time of disposal. The underlying streams will be garbage collected
  /// when there are no more references.
  void dispose() {
    leaveVoiceChat();
  }
}