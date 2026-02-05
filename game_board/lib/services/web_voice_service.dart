// ====================================
// lib/services/web_voice_service.dart
// WebRTC Voice Chat Service (WEB) - FIXED
// ====================================

import 'dart:async';
import 'dart:html' as html;

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

class VoiceChatService {
  static VoiceChatService? _instance;
  final SocketService _socketService;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, html.AudioElement> _audioElements = {};
  final List<VoiceParticipant> _participants = [];

  MediaStream? _localStream;

  bool _inVoiceChat = false;
  bool _isMuted = false;
  String? _currentRoomId;
  String? _currentUserId;

  final _participantsController =
      StreamController<List<VoiceParticipant>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

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

  Stream<List<VoiceParticipant>> get participantsStream =>
      _participantsController.stream;

  Stream<String> get errorStream => _errorController.stream;

  bool get inVoiceChat => _inVoiceChat;
  bool get isMuted => _isMuted;

  List<VoiceParticipant> get participants =>
      List.unmodifiable(_participants);

  // ================= CONSTRUCTOR =================

  factory VoiceChatService(SocketService socketService) {
    return _instance ??= VoiceChatService._internal(socketService);
  }

  VoiceChatService._internal(this._socketService) {
    _setupSocketListeners();
    print('🌐 VoiceChatService (WEB) initialised (singleton)');
  }

  // ================= JOIN / LEAVE =================

  Future<void> joinVoiceChat({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    try {
      _currentRoomId = roomId;
      _currentUserId = userId;

      print('🎤 Requesting microphone access...');

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      print('🎤 Microphone access granted');

      _socketService.voiceJoin(
        roomId: roomId,
        userId: userId,
        username: username,
      );

      _inVoiceChat = true;
    } catch (e) {
      print('❌ Microphone access error: $e');
      _errorController.add('Microphone access denied');
      await _cleanup();
    }
  }

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

  Future<void> toggleMute() async {
    if (_localStream == null) return;

    _isMuted = !_isMuted;

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

  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    print('🔗 Creating peer connection with $userId');

    final pc = await createPeerConnection(_iceServers);

    // Add local stream tracks
    _localStream?.getTracks().forEach((t) {
      pc.addTrack(t, _localStream!);
    });

    // Handle incoming tracks
    pc.onTrack = (event) {
      print('🎵 Received remote track from $userId');
      
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        _remoteStreams[userId] = stream;
        _playRemoteAudio(userId, stream);
      }
    };

    // Handle ICE candidates
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

    // Handle connection state changes
    pc.onConnectionState = (state) {
      print('🔌 Connection state with $userId: $state');
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ Connected to $userId');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print('❌ Connection failed/closed with $userId');
        _peerConnections.remove(userId);
        _remoteStreams.remove(userId);
        
        // Clean up audio element
        final audio = _audioElements.remove(userId);
        if (audio != null) {
          audio.pause();
          audio.srcObject = null;
          audio.remove();
        }
      }
    };

    // Handle ICE connection state
    pc.onIceConnectionState = (state) {
      print('🧊 ICE connection state with $userId: $state');
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  // ================= WEB AUDIO PLAYBACK - FIXED =================

  void _playRemoteAudio(String userId, MediaStream stream) {
    print('🔊 Setting up audio playback for $userId');
    
    // Remove existing audio element if present
    final existingAudio = _audioElements[userId];
    if (existingAudio != null) {
      existingAudio.pause();
      existingAudio.srcObject = null;
      existingAudio.remove();
    }

    // Create new audio element
    final audio = html.AudioElement()
      ..autoplay = true
      ..controls = false;

    // ✅ FIX: Extract the underlying JS MediaStream from the flutter_webrtc wrapper
    try {
      // The MediaStreamWeb wrapper has an internal jsStream property
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
      
      // Fallback: Try direct assignment as dynamic
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

  void _setupSocketListeners() {
    // 👥 Participants list update
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

    // 👤 Someone joined voice → I initiate offer
    _socketService.onVoiceJoined.listen((data) async {
      final peerId = data['userId'];
      print('👤 User joined voice: $peerId');
      
      if (peerId == _currentUserId) {
        print('↩️ Ignoring self-join');
        return;
      }
      
      if (_peerConnections.containsKey(peerId)) {
        print('⚠️ Already have connection with $peerId');
        return;
      }

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

    // 📥 OFFER received
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

    // 📥 ANSWER received
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

    // 🧊 ICE candidate received
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

    // 👋 Participant left
    _socketService.onVoiceParticipantLeft.listen((data) async {
      final peerId = data['userId'];
      print('👋 User left voice: $peerId');

      if (peerId != null) {
        final pc = _peerConnections.remove(peerId);
        await pc?.close();
        _remoteStreams.remove(peerId);

        // Clean up audio element
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

  Future<void> _cleanup() async {
    print('🧹 Cleaning up voice chat');

    // Close all peer connections
    for (final pc in _peerConnections.values) {
      await pc.close();
    }

    // Clean up audio elements
    for (final audio in _audioElements.values) {
      audio.pause();
      audio.srcObject = null;
      audio.remove();
    }

    _peerConnections.clear();
    _audioElements.clear();
    _remoteStreams.clear();
    _participants.clear();

    if (!_participantsController.isClosed) {
      _participantsController.add([]);
    }

    // Stop local stream
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();

    _localStream = null;
    _inVoiceChat = false;
    _isMuted = false;
  }

  void dispose() {
    leaveVoiceChat();
    // Don't close controllers as they're broadcast and may have listeners
  }
}