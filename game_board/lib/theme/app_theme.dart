// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Color scheme based on the 60-30-10 rule for visual harmony
/// Following academic research on color psychology and UX design principles
class AppColors {
  // ============================================================================
  // PLATFORM-LEVEL CONSISTENCY (60-30-10 Rule)
  // ============================================================================
  
  /// Dominant Color (60%) - Dark Navy Blue
  /// Promotes trust and readability in dark mode (Su, Cui & Walsh, 2019)
  /// Background and main UI elements
  static const Color primaryNavy = Color(0xFF0D1B2A);  // Dark navy blue
  static const Color primaryNavyLight = Color(0xFF1B2A3A);  // Slightly lighter navy
  static const Color primaryNavyDark = Color(0xFF060D14);  // Deeper navy
  
  /// Secondary Color (30%) - Amber
  /// Warm and inviting, adds cheerful vibe (Figma, 2025)
  /// Used for secondary UI elements and highlights
  static const Color secondaryAmber = Color(0xFFFFB300);  // Amber
  static const Color secondaryAmberLight = Color(0xFFFFCA28);  // Light amber
  static const Color secondaryAmberDark = Color(0xFFFF8F00);  // Deep amber
  
  /// Accent Colors (10%) - Context-specific accents
  
  // BETTING ACCENT - Gold
  // Creates prosperous, high-end casino atmosphere (Opplehouse, 2025)
  static const Color accentGold = Color(0xFFFFD700);  // Gold
  static const Color accentGoldLight = Color(0xFFFFE57F);  // Light gold
  static const Color accentGoldDark = Color(0xFFFFC107);  // Deep gold
  
  // PRIMARY ACTION ACCENT - Electric Blue
  // High contrast for visibility, promotes trust (Tubik Studio, 2019)
  static const Color accentElectricBlue = Color(0xFF00E5FF);  // Electric blue
  static const Color accentElectricBlueLight = Color(0xFF6EFFFF);  // Light electric blue
  static const Color accentElectricBlueDark = Color(0xFF00B8D4);  // Deep electric blue
  
  // ============================================================================
  // SEMANTIC COLORS (Universal across platform)
  // ============================================================================
  
  static const Color success = Color(0xFF4CAF50);  // Green for success states
  static const Color successDark = Color(0xFF388E3C);
  static const Color error = Color(0xFFE53935);  // Red for error states
  static const Color errorDark = Color(0xFFC62828);
  static const Color warning = Color(0xFFFFA726);  // Orange for warnings
  static const Color info = Color(0xFF29B6F6);  // Light blue for info
  
  // ============================================================================
  // GAME-SPECIFIC COLOR SCHEMES
  // ============================================================================
  
  /// BLACKJACK - Classic Casino Aesthetic
  /// Deep reds, golds, and greens for traditional casino feel
  static const Color blackjackRed = Color(0xFF8B0000);  // Deep red (casino felt)
  static const Color blackjackGreen = Color(0xFF0B5D1E);  // Casino green
  static const Color blackjackGold = Color(0xFFFFD700);  // Gold accents
  static const Color blackjackCardBack = Color(0xFF1A0F0F);  // Dark card back
  
  /// UNO/CRAZY EIGHTS - Bright, Playful
  /// Bright primary colors for fun, energetic gameplay
  static const Color unoRed = Color(0xFFE53935);
  static const Color unoBlue = Color(0xFF1E88E5);
  static const Color unoYellow = Color(0xFFFDD835);
  static const Color unoGreen = Color(0xFF43A047);
  static const Color unoBackground = Color(0xFF263238);  // Dark slate background
  
  /// CHECKERS - Traditional Board Game
  /// Warm browns and creams for classic aesthetic
  static const Color checkersLight = Color(0xFFFFE4C4);  // Cream/bisque
  static const Color checkersDark = Color(0xFF8B4513);  // Saddle brown
  static const Color checkersBoard = Color(0xFF4A3428);  // Dark wood
  static const Color checkersHighlight = Color(0xFFFFD700);  // Gold for valid moves
  
  // ============================================================================
  // TEXT & UI ELEMENTS
  // ============================================================================
  
  // Text colors optimized for dark navy background
  static const Color textPrimary = Color(0xFFFFFFFF);  // White
  static const Color textSecondary = Color(0xFFB0BEC5);  // Light grey-blue
  static const Color textDisabled = Color(0xFF607D8B);  // Medium grey-blue
  static const Color textOnAmber = Color(0xFF000000);  // Black text on amber
  static const Color textOnGold = Color(0xFF000000);  // Black text on gold
  
  // Surface and background variants
  static const Color surface = Color(0xFF1B2A3A);  // Slightly lighter than primary
  static const Color surfaceLight = Color(0xFF2D3E50);  // Even lighter surface
  static const Color surfaceDark = Color(0xFF0A1520);  // Darker surface
  
  // Border and divider colors
  static const Color border = Color(0xFF37474F);
  static const Color borderLight = Color(0xFF546E7A);
  static const Color divider = Color(0xFF263238);
  
  // Overlay colors (for modals, dialogs, etc.)
  static const Color overlay = Color(0xCC000000);  // 80% black
  static const Color scrim = Color(0x99000000);  // 60% black
  
  // ============================================================================
  // UTILITY METHODS
  // ============================================================================
  
  /// Get appropriate text color based on background
  static Color getTextColorForBackground(Color background) {
    // Calculate relative luminance
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? textPrimary : Color(0xFF000000);
  }
  
  /// Get game-specific primary color
  static Color getGamePrimaryColor(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'blackjack':
        return blackjackGreen;
      case 'uno':
      case 'crazy_eights':
        return unoBlue;
      case 'checkers':
        return checkersDark;
      default:
        return primaryNavy;
    }
  }
}

/// Complete theme configuration following the color scheme
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      // Use Material 3 design system
      useMaterial3: true,
      
      // Overall brightness
      brightness: Brightness.dark,
      
      // Color scheme following 60-30-10 rule
      colorScheme: ColorScheme.dark(
        // Primary colors (Navy blue - 60%)
        primary: AppColors.primaryNavy,
        primaryContainer: AppColors.primaryNavyLight,
        onPrimary: AppColors.textPrimary,
        onPrimaryContainer: AppColors.textPrimary,
        
        // Secondary colors (Amber - 30%)
        secondary: AppColors.secondaryAmber,
        secondaryContainer: AppColors.secondaryAmberDark,
        onSecondary: AppColors.textOnAmber,
        onSecondaryContainer: AppColors.textOnAmber,
        
        // Tertiary colors (Electric Blue - accents)
        tertiary: AppColors.accentElectricBlue,
        tertiaryContainer: AppColors.accentElectricBlueDark,
        onTertiary: AppColors.primaryNavyDark,
        onTertiaryContainer: AppColors.textPrimary,
        
        // Error colors
        error: AppColors.error,
        errorContainer: AppColors.errorDark,
        onError: AppColors.textPrimary,
        onErrorContainer: AppColors.textPrimary,
        
        // Surface colors
        surface: AppColors.primaryNavy,
        surfaceContainerHighest: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        
        // Outline colors
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      ),
      
      // Scaffold background
      scaffoldBackgroundColor: AppColors.primaryNavy,
      
      // Card theme
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryNavyDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',  // Heading font from report
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentElectricBlue,
          foregroundColor: AppColors.primaryNavyDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          textStyle: TextStyle(
            fontFamily: 'Inter',  // Primary font from report
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryAmber,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.secondaryAmber, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accentElectricBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textDisabled,
        ),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentGold,
        foregroundColor: AppColors.textOnGold,
        elevation: 8,
      ),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 16,
      ),
      
      // Icon theme
      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),
      
      // Text theme with Inter (primary) and Montserrat (headings)
      textTheme: TextTheme(
        // Display styles (Montserrat - for major headings)
        displayLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 57,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        
        // Headline styles (Montserrat - for headings)
        headlineLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        
        // Title styles (Montserrat - for card titles, etc.)
        titleLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        
        // Body styles (Inter - for body text, 12-14px as recommended)
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        
        // Label styles (Inter - for buttons, labels)
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}