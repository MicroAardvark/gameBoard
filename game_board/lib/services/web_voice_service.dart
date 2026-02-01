// ====================================
// lib/services/web_voice_service.dart
// WebRTC Voice Chat Service (WEB)
// ====================================

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js;

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

  VoiceChatService(this._socketService) {
    _setupSocketListeners();
    print('🌐 VoiceChatService (WEB) initialized');
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

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      _socketService.voiceJoin(
        roomId: roomId,
        userId: userId,
        username: username,
      );

      _inVoiceChat = true;
    } catch (e) {
      _errorController.add('Microphone access denied');
      await _cleanup();
    }
  }

  Future<void> leaveVoiceChat() async {
    if (!_inVoiceChat) return;

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
    final pc = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((t) {
      pc.addTrack(t, _localStream!);
    });

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        _remoteStreams[userId] = stream;
        _playRemoteAudio(userId, stream);
      }
    };

    pc.onIceCandidate = (c) {
      if (c != null) {
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

    _peerConnections[userId] = pc;
    return pc;
  }

  void _playRemoteAudio(String userId, MediaStream stream) {
    final audio = html.AudioElement()
      ..autoplay = true
      ..controls = false;

    js.setProperty(audio, 'srcObject', stream);
    audio.play();

    _audioElements[userId] = audio;
  }

  // ================= SOCKETS =================

  void _setupSocketListeners() {
    _socketService.onVoiceParticipantsUpdated.listen((data) {
      final list = data['participants'] as List?;
      if (list == null) return;

      _participants
        ..clear()
        ..addAll(list.map((e) => VoiceParticipant.fromJson(e)));

      _participantsController.add(_participants);
    });
  }

  // ================= CLEANUP =================

  Future<void> _cleanup() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }

    for (final audio in _audioElements.values) {
      audio.pause();
      js.setProperty(audio, 'srcObject', null);
      audio.remove();
    }

    _peerConnections.clear();
    _audioElements.clear();
    _remoteStreams.clear();
    _participants.clear();

    _participantsController.add([]);

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();

    _localStream = null;
    _inVoiceChat = false;
    _isMuted = false;
  }

  void dispose() {
    leaveVoiceChat();
    _participantsController.close();
    _errorController.close();
  }
}
