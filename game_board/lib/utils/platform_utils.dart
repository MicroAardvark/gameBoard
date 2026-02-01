// lib/utils/platform_utils.dart

import '../services/socket_service.dart';

// Conditional import (compile-time)
import '../services/mobile_voice_service.dart'
    if (dart.library.html) '../services/web_voice_service.dart';

// 🔥 EXPORT the selected implementation’s public API
export '../services/mobile_voice_service.dart'
    if (dart.library.html) '../services/web_voice_service.dart';

class PlatformUtils {
  static VoiceChatService createVoiceChatService(
    SocketService socketService,
  ) {
    return VoiceChatService(socketService);
  }
}
