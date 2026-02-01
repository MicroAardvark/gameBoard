// ====================================
// lib/services/platform_util.dart
// Platform-aware VoiceChatService factory
// ====================================

import '../services/socket_service.dart';

// IMPORTANT:
// Conditional import ensures dart:html is never compiled on mobile
import '../services/mobile_voice_service.dart'
    if (dart.library.html) '../services/web_voice_service.dart';

class PlatformUtil {
  static VoiceChatService createVoiceChatService(
    SocketService socketService,
  ) {
    return VoiceChatService(socketService);
  }
}
