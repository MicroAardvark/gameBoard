// ====================================
// lib/services/mobile_voice_service.dart
// WebRTC Voice Chat Service (MOBILE)
// ====================================

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
  final SocketService _socketService;
  static VoiceChatService? _instance;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
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

  factory VoiceChatService(SocketService socketService) {
    return _instance ??= VoiceChatService._internal(socketService);
  }

  VoiceChatService._internal(this._socketService) {
    _setupSocketListeners();
    print('🌐 VoiceChatService (WEB) initialized (singleton)');
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

  // ================= SOCKETS =================

  void _setupSocketListeners() {
    // 👥 participants list
    _socketService.onVoiceParticipantsUpdated.listen((data) {
      final list = data['participants'] as List?;
      if (list == null) return;

      _participants
        ..clear()
        ..addAll(list.map((e) => VoiceParticipant.fromJson(e)));

      if (!_participantsController.isClosed) {
        _participantsController.add(_participants);
      }
    });

    // 👤 someone joined voice → I initiate offer
    _socketService.onVoiceJoined.listen((data) async {
      final peerId = data['userId'];
      if (peerId == _currentUserId) return;
      if (_peerConnections.containsKey(peerId)) return;

      final pc = await _createPeerConnection(peerId);

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _socketService.sendWebRTCOffer(
        roomId: _currentRoomId!,
        targetUserId: peerId,
        fromUserId: _currentUserId!,
        offer: offer.toMap(),
      );
    });

    // 📥 OFFER
    _socketService.onWebRTCOfferReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final offer = data['offer'];

      if (peerId == null || offer == null) return;

      final pc = await _createPeerConnection(peerId);

      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socketService.sendWebRTCAnswer(
        roomId: _currentRoomId!,
        targetUserId: peerId,
        fromUserId: _currentUserId!,
        answer: answer.toMap(),
      );
    });

    // 📥 ANSWER
    _socketService.onWebRTCAnswerReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final answer = data['answer'];

      final pc = _peerConnections[peerId];
      if (pc == null) return;

      await pc.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    });

    // 🧊 ICE
    _socketService.onWebRTCIceCandidateReceived.listen((data) async {
      final peerId = data['fromUserId'];
      final candidate = data['candidate'];

      if (peerId == null || peerId is! String) {
        print('⚠️ ICE candidate without peerId, ignoring');
        return;
      }

      if (candidate == null) return;

      final pc = _peerConnections[peerId];
      if (pc == null) return;

      await pc.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
    });
  }

  // ================= CLEANUP =================

  Future<void> _cleanup() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }

    _peerConnections.clear();
    _remoteStreams.clear();
    _participants.clear();

    _participantsController.add([]);

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();

    _localStream = null;
    _inVoiceChat = false;
    _isMuted = false;
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    final pc = await createPeerConnection(_iceServers);

    // 🔊 RECEIVE REMOTE AUDIO
    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind != 'audio') return;

      print('🔊 Remote audio track received from $peerId');

      final stream = event.streams.first;
      _remoteStreams[peerId] = stream;

      // 🔥 THIS IS WHERE IT GOES
      Helper.setSpeakerphoneOn(true);
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;

      _socketService.sendWebRTCIceCandidate(
        roomId: _currentRoomId!,
        targetUserId: peerId,
        fromUserId: _currentUserId!,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };


    // 📤 SEND LOCAL AUDIO
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    _peerConnections[peerId] = pc;
    return pc;
  }


  void dispose() {
    leaveVoiceChat();
    _participantsController.close();
    _errorController.close();
  }
}
