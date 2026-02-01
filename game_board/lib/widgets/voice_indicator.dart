// lib/widgets/voice_indicator.dart
// Minimal voice chat indicator - shows when chat overlay is closed
import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';
import '../theme/app_theme.dart';

class VoiceIndicator extends StatelessWidget {
  final VoiceChatService voiceService;
  final VoidCallback onTap;

  const VoiceIndicator({
    super.key,
    required this.voiceService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if in voice chat
    if (!voiceService.inVoiceChat) {
      return const SizedBox.shrink();
    }

    final participantCount = voiceService.participants.length;
    
    return Positioned(
      top: 60, // Below typical app bar
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
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
              Icon(
                voiceService.isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
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