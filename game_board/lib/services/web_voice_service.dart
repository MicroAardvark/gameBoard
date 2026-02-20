// ====================================
// lib/services/web_voice_service.dart
// WebRTC Voice Chat Service (WEB)
// ====================================
//
// Web-specific implementation of the WebRTC voice chat service.
//
// This file should only be used on Flutter Web targets. For native mobile
// (Android/iOS), see mobile_voice_service.dart.
//
// Key differences from the mobile implementation:
//   - On web, the browser does NOT automatically route audio from RTCPeerConnection
//     tracks to the speakers. An HTML <audio> element must be created for each
//     remote participant and assigned their MediaStream.
//   - The flutter_webrtc package wraps browser MediaStreams in a Dart wrapper
//     (MediaStreamWeb). The underlying JS MediaStream must be extracted using
//     the `.jsStream` dynamic property before assigning to an AudioElement's
//     `srcObject`. A fallback via dynamic cast is also attempted.
//   - Audio elements are tracked in [_audioElements] and explicitly cleaned up
//     when participants leave or the session ends.
//
// Architecture:
//   - Singleton pattern ensures only one voice session exists at a time.
//   - One RTCPeerConnection per remote participant.
//   - Signalling routed via SocketService (Socket.IO).
//   - Offer/answer WebRTC handshake:
//       Joining user → creates offer → sends to each existing participant
//       Existing participant → receives offer → sends answer back
//       ICE candidates exchanged → optimal path selected

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

// ====================================
// VOICE PARTICIPANT MODEL
// ====================================

/// Represents a participant currently in the voice chat channel.
///
/// Immutable snapshot. New instances are created when state (e.g. mute) changes.
class VoiceParticipant {
  final String userId;
  final String username;
  final bool muted;

  VoiceParticipant({
    required this.userId,
    required this.username,
    this.muted = false,
  });

  /// Deserialises a [VoiceParticipant] from server JSON.
  ///
  /// Handles null or malformed input defensively, returning a participant
  /// with empty fields rather than throwing an exception.
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
// VOICE CHAT SERVICE (WEB)
// ====================================

class VoiceChatService {
  /// Singleton instance — prevents duplicate WebRTC sessions being created.
  static VoiceChatService? _instance;

  /// Reference to the shared socket service for signalling.
  final SocketService _socketService;

  // ---- WebRTC State ----

  /// Active peer connections keyed by remote user ID.
  final Map<String, RTCPeerConnection> _peerConnections = {};

  /// Remote media streams keyed by remote user ID.
  final Map<String, MediaStream> _remoteStreams = {};

  /// HTML audio elements used to play remote streams in the browser.
  /// Each participant requires their own <audio> element.
  final Map<String, html.AudioElement> _audioElements = {};

  /// Current list of voice channel participants.
  final List<VoiceParticipant> _participants = [];

  /// The local microphone stream from this device.
  MediaStream? _localStream;

  // ---- Session State ----

  bool _inVoiceChat = false;
  bool _isMuted = false;
  String? _currentRoomId;
  String? _currentUserId;

  // ---- Stream Controllers (UI bindings) ----

  /// Emits an updated participant list whenever the voice channel changes.
  final _participantsController =
      StreamController<List<VoiceParticipant>>.broadcast();

  /// Emits user-facing error messages.
  final _errorController = StreamController<String>.broadcast();

  // ---- ICE Server Configuration ----

  /// STUN servers for NAT traversal. Multiple Google servers for resilience.
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  // ---- Public Getters ----

  /// Stream that emits the full participant list on each change.
  Stream<List<VoiceParticipant>> get participantsStream =>
      _participantsController.stream;

  /// Stream that emits user-facing error messages.
  Stream<String> get errorStream => _errorController.stream;

  bool get inVoiceChat => _inVoiceChat;
  bool get isMuted => _isMuted;

  /// Read-only snapshot of the current participant list.
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
    print('🌐 VoiceChatService (WEB) initialised (singleton)');
  }

  // ================= JOIN / LEAVE =================

  /// Joins the voice channel for the specified room.
  ///
  /// Requests microphone access from the browser, then notifies the signalling
  /// server so other participants are prompted to initiate WebRTC connections.
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
      _currentRoomId = roomId;
      _currentUserId = userId;

      print('🎤 Requesting microphone access...');

      // Request microphone with audio quality constraints.
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      print('🎤 Microphone access granted');

      // Notify the server so it can inform other participants to connect.
      _socketService.voiceJoin(
        roomId: roomId,
        userId: userId,
        username: username,
      );

      _inVoiceChat = true;
    } catch (e) {
      // Microphone was denied or an error occurred.
      print('❌ Microphone access error: $e');
      _errorController.add('Microphone access denied');
      await _cleanup();
    }
  }

  /// Leaves the voice channel and releases all resources.
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
  /// Disables/enables local audio tracks and notifies the server so other
  /// participants see the correct mute indicator.
  Future<void> toggleMute() async {
    if (_localStream == null) return;

    _isMuted = !_isMuted;

    // Toggle each audio track in the local stream.
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }

    print('🔇 Mute toggled: $_isMuted');

    _socketService.voiceMuteToggle(
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      muted: _isMuted,
    );
  }

  // ================= REPORT =================

  /// Reports a voice chat participant for inappropriate behaviour.
  ///
  /// Only available during an active voice session. The report is forwarded
  /// to platform moderators via the signalling server.
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

  /// Creates and configures a WebRTC peer connection for [userId].
  ///
  /// Attaches local audio tracks and registers callbacks for:
  ///   - [onTrack]: Sets up HTML audio playback for remote audio streams.
  ///   - [onIceCandidate]: Forwards ICE candidates via signalling.
  ///   - [onConnectionState]: Cleans up failed/closed connections.
  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    print('🔗 Creating peer connection with $userId');

    final pc = await createPeerConnection(_iceServers);

    // Attach local microphone tracks to the connection.
    _localStream?.getTracks().forEach((t) {
      pc.addTrack(t, _localStream!);
    });

    // Handle incoming remote audio tracks from the peer.
    pc.onTrack = (event) {
      print('🎵 Received remote track from $userId');

      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        _remoteStreams[userId] = stream;

        // On web, audio must be explicitly played via an HTML audio element.
        _playRemoteAudio(userId, stream);
      }
    };

    // Forward ICE candidates to the remote peer via the signalling server.
    pc.onIceCandidate = (c) {
      if (c != null) {
        print('🧊 Sending ICE candidate to $userId');
        _socketService.sendWebRTCIceCandidate(
          roomId: _currentRoomId!,
          targetUserId: userId,
          fromUserId: _currentUserId!,
          candidate: {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        );
      }
    };

    // Monitor the connection lifecycle and clean up on failure or closure.
    pc.onConnectionState = (state) {
      print('🔌 Connection state with $userId: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ Connected to $userId');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print('❌ Connection failed/closed with $userId');
        _peerConnections.remove(userId);
        _remoteStreams.remove(userId);

        // Also remove and stop the corresponding audio element.
        final audio = _audioElements.remove(userId);
        if (audio != null) {
          audio.pause();
          audio.srcObject = null;
          audio.remove();
        }
      }
    };

    // Log ICE connection state transitions for debugging.
    pc.onIceConnectionState = (state) {
      print('🧊 ICE connection state with $userId: $state');
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  // ================= WEB AUDIO PLAYBACK =================

  /// Sets up an HTML <audio> element to play a remote participant's audio stream.
  ///
  /// This is required on web because browsers do not automatically route
  /// WebRTC audio tracks to speakers — an AudioElement must be created and
  /// assigned the stream's srcObject.
  ///
  /// The flutter_webrtc package wraps the native browser MediaStream in a
  /// Dart object (MediaStreamWeb). To assign it to an HTMLAudioElement's
  /// `srcObject`, the underlying JS MediaStream is extracted via the
  /// `.jsStream` dynamic property. A fallback via dynamic cast is attempted
  /// if the primary extraction fails.
  void _playRemoteAudio(String userId, MediaStream stream) {
    print('🔊 Setting up audio playback for $userId');

    // Remove any existing audio element for this user before creating a new one.
    final existingAudio = _audioElements[userId];
    if (existingAudio != null) {
      existingAudio.pause();
      existingAudio.srcObject = null;
      existingAudio.remove();
    }

    // Create a new hidden audio element for this participant's stream.
    final audio = html.AudioElement()
      ..autoplay = true  // Start playback immediately when a stream is assigned.
      ..controls = false; // Hidden — UI controls are provided by the app.

    // Attempt to extract the underlying JS MediaStream from the flutter_webrtc
    // wrapper and assign it to the audio element's srcObject.
    try {
      // MediaStreamWeb (the flutter_webrtc web wrapper) exposes the native
      // JS stream via the `jsStream` property.
      final jsStream = (stream as dynamic).jsStream;
      audio.srcObject = jsStream;

      audio.play().then((_) {
        print('✅ Audio playback started for $userId');
      }).catchError((e) {
        print('❌ Error playing audio: $e');
      });
    } catch (e) {
      print('❌ Error setting up audio playback: $e');
      print('   Stream type: ${stream.runtimeType}');

      // Fallback: attempt a direct dynamic cast assignment.
      // Some environments may expose the stream differently.
      try {
        audio.srcObject = stream as dynamic;
        audio.play().then((_) {
          print('✅ Audio playback started (fallback) for $userId');
        });
      } catch (e2) {
        print('❌ Fallback also failed: $e2');
      }
    }

    _audioElements[userId] = audio;
  }

  // ================= SOCKET LISTENERS =================

  /// Registers all Socket.IO event listeners for voice chat signalling.
  void _setupSocketListeners() {
    // ---- Participants Updated ----
    // Full participant list sync from the server. Replaces the existing list.
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
    // This client initiates the WebRTC offer to establish the connection.
    _socketService.onVoiceJoined.listen((data) async {
      final peerId = data['userId'];
      print('👤 User joined voice: $peerId');

      // Ignore the event fired for this user's own join.
      if (peerId == _currentUserId) {
        print('↩️ Ignoring self-join');
        return;
      }

      // Prevent duplicate connections to the same peer.
      if (_peerConnections.containsKey(peerId)) {
        print('⚠️ Already have connection with $peerId');
        return;
      }

      print('📞 Initiating call to $peerId');
      final pc = await _createPeerConnection(peerId);

      // Create the SDP offer and send it to the newly joined peer.
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
    // Received when a remote peer wants to connect to this user.
    // Respond with a WebRTC answer to complete the handshake.
    _socketService.onWebRTCOfferReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final offer = data['offer'];

      print('📥 Received offer from $peerId');

      if (peerId == null || peerId is! String) {
        print('⚠️ Invalid peer ID, ignoring');
        return;
      }

      if (offer == null) {
        print('⚠️ Null offer data');
        return;
      }

      if (peerId == _currentUserId) {
        print('↩️ Ignoring offer from self');
        return;
      }

      final pc = await _createPeerConnection(peerId);

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
    // Received in response to an offer this client sent.
    // Sets the remote description to complete the WebRTC handshake.
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
    // ICE candidates are exchanged after the offer/answer to determine
    // the best network path between peers (NAT traversal).
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
    // Received when a user leaves the voice channel.
    // Cleans up their peer connection, remote stream, and audio element.
    _socketService.onVoiceParticipantLeft.listen((data) async {
      final peerId = data['userId'];
      print('👋 User left voice: $peerId');

      if (peerId != null) {
        final pc = _peerConnections.remove(peerId);
        await pc?.close();
        _remoteStreams.remove(peerId);

        // Stop and remove the HTML audio element for this participant.
        final audio = _audioElements.remove(peerId);
        if (audio != null) {
          audio.pause();
          audio.srcObject = null;
          audio.remove();
        }

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
  /// Closes all peer connections, removes all HTML audio elements,
  /// stops the local microphone stream, and resets session flags.
  Future<void> _cleanup() async {
    print('🧹 Cleaning up voice chat');

    // Close all peer connections.
    for (final pc in _peerConnections.values) {
      await pc.close();
    }

    // Pause and remove all HTML audio elements.
    for (final audio in _audioElements.values) {
      audio.pause();
      audio.srcObject = null;
      audio.remove();
    }

    _peerConnections.clear();
    _audioElements.clear();
    _remoteStreams.clear();
    _participants.clear();

    // Notify UI listeners that the channel is now empty.
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

  /// Disposes the service.
  ///
  /// Stream controllers are intentionally not closed here as they are
  /// broadcast streams that may still have active UI listeners at disposal time.
  void dispose() {
    leaveVoiceChat();
  }
}