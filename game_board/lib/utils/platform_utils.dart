// ====================================
// lib/utils/platform_utils.dart
// Platform detection and capability utilities
// ✅ Works on Android, Web, and other platforms
// ====================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class PlatformUtils {
  // ===================================
  // PLATFORM DETECTION
  // ===================================
  
  /// Check if running on web
  static bool get isWeb => kIsWeb;
  
  /// Check if running on mobile (Android or iOS)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /// Check if running on Android
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }
  
  /// Check if running on iOS
  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }
  
  /// Check if running on desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  // ===================================
  // FEATURE CAPABILITIES
  // ===================================
  
  /// Check if voice chat is supported on this platform
  static bool get supportsVoiceChat {
    // Voice chat works on both Android and Web (with HTTPS)
    // iOS would work but we're not building for it
    return isAndroid || isWeb;
  }
  
  /// Check if camera is available (for profile pictures)
  static bool get supportsCamera {
    // Android has native camera
    // Web can access camera via getUserMedia
    // iOS would work but we're not building for it
    return isAndroid || isWeb;
  }
  
  /// Check if platform requires HTTPS for WebRTC
  static bool get requiresHTTPS {
    // Web requires HTTPS for WebRTC (except localhost)
    // Android doesn't have this restriction
    return isWeb;
  }
  
  /// Check if platform supports file downloads
  static bool get supportsFileDownloads {
    // All platforms support some form of file saving
    return true;
  }
  
  /// Check if platform supports local notifications
  static bool get supportsNotifications {
    // Android supports push notifications
    // Web supports service worker notifications
    return isAndroid || isWeb;
  }

  // ===================================
  // PLATFORM-SPECIFIC CONFIGURATIONS
  // ===================================
  
  /// Get appropriate WebRTC media constraints for platform
  static Map<String, dynamic> getMediaConstraints() {
    if (isWeb) {
      // Web browsers need simpler constraints
      return {
        'audio': true,
        'video': false,
      };
    } else {
      // Android can use advanced audio processing
      return {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };
    }
  }
  
  /// Get platform-specific error messages
  static String getMicrophonePermissionError() {
    if (isWeb) {
      return 'Microphone access denied. Please allow microphone access in your browser settings and reload the page.';
    } else if (isAndroid) {
      return 'Microphone access denied. Please enable microphone permission in your device settings.';
    } else {
      return 'Microphone access denied. Please check your device permissions.';
    }
  }
  
  /// Get platform-specific camera permission error
  static String getCameraPermissionError() {
    if (isWeb) {
      return 'Camera access denied. Please allow camera access in your browser settings and reload the page.';
    } else if (isAndroid) {
      return 'Camera access denied. Please enable camera permission in your device settings.';
    } else {
      return 'Camera access denied. Please check your device permissions.';
    }
  }
  
  /// Get platform name for display
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
  
  /// Get user agent for logging/analytics
  static String getUserAgent() {
    if (isWeb) {
      // On web, you might want to detect browser type
      return 'Web Browser';
    } else if (isAndroid) {
      return 'Android ${Platform.operatingSystemVersion}';
    } else if (isIOS) {
      return 'iOS ${Platform.operatingSystemVersion}';
    }
    return platformName;
  }

  // ===================================
  // FEATURE WARNINGS
  // ===================================
  
  /// Get warning message for HTTPS requirement on web
  static String? getHTTPSWarning() {
    if (isWeb && requiresHTTPS) {
      return 'Voice chat requires HTTPS. If you\'re experiencing issues, please ensure you\'re accessing the site via https://';
    }
    return null;
  }
  
  /// Check if running on localhost (for development)
  static bool isLocalhost() {
    if (!isWeb) return false;
    
    // In web, check if running on localhost
    // This is a simplified check - in production you might want to use
    // window.location.hostname from dart:html
    return false; // Simplified - always return false for now
  }

  // ===================================
  // PERFORMANCE HINTS
  // ===================================
  
  /// Get recommended maximum players based on platform
  static int getRecommendedMaxPlayers() {
    if (isWeb) {
      // Web might have more limitations due to browser restrictions
      return 4;
    } else if (isMobile) {
      // Mobile devices can handle more with native performance
      return 6;
    }
    return 8; // Desktop can handle more
  }
  
  /// Get recommended graphics quality
  static String getRecommendedGraphicsQuality() {
    if (isWeb) {
      return 'medium'; // Web canvas might have performance limitations
    } else if (isMobile) {
      return 'high'; // Mobile has good GPU support
    }
    return 'high'; // Desktop can handle high quality
  }
  
  /// Check if platform should use optimized rendering
  static bool get shouldOptimizeRendering {
    // Web might benefit from optimizations
    return isWeb;
  }

  // ===================================
  // DEBUG INFORMATION
  // ===================================
  
  /// Get comprehensive platform information for debugging
  static Map<String, dynamic> getDebugInfo() {
    return {
      'platform': platformName,
      'isWeb': isWeb,
      'isMobile': isMobile,
      'isAndroid': isAndroid,
      'isIOS': isIOS,
      'isDesktop': isDesktop,
      'supportsVoiceChat': supportsVoiceChat,
      'supportsCamera': supportsCamera,
      'requiresHTTPS': requiresHTTPS,
      'userAgent': getUserAgent(),
      'recommendedMaxPlayers': getRecommendedMaxPlayers(),
      'recommendedGraphicsQuality': getRecommendedGraphicsQuality(),
    };
  }
  
  /// Print platform information to console
  static void printPlatformInfo() {
    print('🎮 ================================');
    print('🎮 MICROVARK PLATFORM INFO');
    print('🎮 ================================');
    print('Platform: $platformName');
    print('Is Web: $isWeb');
    print('Is Mobile: $isMobile');
    print('Is Android: $isAndroid');
    print('Voice Chat: ${supportsVoiceChat ? "✅ Supported" : "❌ Not Supported"}');
    print('Camera: ${supportsCamera ? "✅ Supported" : "❌ Not Supported"}');
    if (requiresHTTPS) {
      print('⚠️  HTTPS required for WebRTC');
    }
    print('🎮 ================================');
  }
}

// ===================================
// PLATFORM-SPECIFIC EXTENSIONS
// ===================================

/// Extension on String for platform-specific formatting
extension PlatformString on String {
  /// Get platform-appropriate file path separator
  String get platformPath {
    if (kIsWeb) {
      return replaceAll('\\', '/'); // Web always uses forward slashes
    }
    return this; // Native platforms handle this automatically
  }
}