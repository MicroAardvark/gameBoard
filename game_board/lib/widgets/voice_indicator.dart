// ====================================
// lib/widgets/voice_indicator.dart
// Minimal persistent voice-chat status indicator
//
// PURPOSE:
//   A small floating badge displayed in the top-right corner of the game
//   screen whenever the local player is in an active voice-chat session.
//   It provides a persistent, low-footprint reminder that the microphone is
//   live and shows how many players are currently in voice – without the
//   full VoiceChatWidget being open.
//
// FEATURES:
//   - Returns an empty widget (SizedBox.shrink) when not in voice, so it
//     takes up no space and has no visual impact when inactive
//   - Displays a microphone icon (with mic_off variant when muted) plus a
//     participant count
//   - Tappable: invokes [onTap] so the parent can re-open the chat overlay
//     or VoiceChatWidget to access full controls
//   - Downward arrow icon hints to the user that tapping will expand controls
//
// RELATIONSHIP TO OTHER WIDGETS:
//   This widget is intended as a companion to [VoiceChatWidget] and
//   [ChatOverlay].  It is shown when those panels are closed so the player
//   still has a visual cue that voice is active.
//
// USAGE:
//   Mount inside a Stack, typically below the game canvas layer:
//     Stack(children: [
//       GameCanvas(),
//       VoiceIndicator(
//         voiceService: _voiceService,
//         onTap: () => setState(() => _showChat = true),
//       ),
//     ])
// ====================================

import 'package:flutter/material.dart';
import '../services/voice_chat_service.dart';

/// Compact floating badge that signals an active voice-chat session.
///
/// Returns [SizedBox.shrink] when [voiceService.inVoiceChat] is false, so it
/// is completely invisible and non-interactive when voice is not active.
class VoiceIndicator extends StatelessWidget {
  /// The voice chat service instance.  The indicator reads [inVoiceChat],
  /// [isMuted], and [participants] from this service to determine its
  /// visibility and content.
  final VoiceChatService voiceService;

  /// Called when the player taps the indicator.  The parent should use this
  /// to re-open the chat overlay or voice widget so the player can manage
  /// their voice session.
  final VoidCallback onTap;

  const VoiceIndicator({
    super.key,
    required this.voiceService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Render nothing when not in voice – no wasted layout space.
    if (!voiceService.inVoiceChat) {
      return const SizedBox.shrink();
    }

    final participantCount = voiceService.participants.length;

    // Positioned below the status bar / app bar area to avoid overlap.
    return Positioned(
      top: 60,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Green background reinforces the "live microphone" metaphor
            // familiar from video-call applications.
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mic icon: mic_off variant shown in red when muted, to make
              // the muted state obvious even at a glance.
              Icon(
                voiceService.isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),

              // Number of active participants in voice.
              Text(
                '$participantCount',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),

              // Downward chevron hints the badge is tappable to expand.
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}