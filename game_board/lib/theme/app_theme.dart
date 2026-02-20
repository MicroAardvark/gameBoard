// lib/theme/app_theme.dart
//
// AppColors & AppTheme — the centralised design system for the Microvark platform.
//
// Design Philosophy:
//   The colour scheme follows the 60-30-10 rule, a principle from interior design
//   and UX colour theory that divides colours into three proportional roles:
//     - 60% Dominant: Dark navy blue — the canvas; conveys trust and professionalism.
//     - 30% Secondary: Amber — adds warmth and visual interest.
//     - 10% Accent: Electric blue or gold — draws attention to key interactive elements.
//
//   This approach creates visual cohesion across all screens and game modes while
//   still allowing game-specific colour personalities (casino green for Blackjack,
//   bright primaries for Crazy Eights, warm wood tones for the legacy Checkers palette).
//
// Typography:
//   - Montserrat: Used for all headings and display text. Bold geometric proportions
//     give the platform a modern, premium feel.
//   - Inter: Used for all body text, labels, and UI controls. Designed for screen
//     readability at small sizes (12–16px range as recommended by Nielsen & Norman).
//
// Academic References:
//   - Su, Cui & Walsh (2019): Dark navy promotes trust and reduces eye strain in
//     low-light environments, supporting the dark-mode-first design approach.
//   - Tubik Studio (2019): High-contrast electric blue on dark backgrounds increases
//     interactive element visibility and perceived tap affordance.

import 'package:flutter/material.dart';

// ============================================================================
// APP COLORS
// ============================================================================

/// The centralised colour palette for the entire Microvark platform.
///
/// All colours in the application should be drawn from this class rather than
/// using hardcoded hex values elsewhere. This ensures consistency and makes
/// future theme changes a single-location edit.
///
/// Organised following the 60-30-10 colour design rule.
/// (Su, Cui & Walsh, 2019; Figma, 2025)
class AppColors {

  // ============================================================================
  // PRIMARY COLOURS — 60% (Dark Navy Blue)
  // ============================================================================
  // The dominant colour covers backgrounds, scaffolds, and the majority of
  // UI surface area. Dark navy is chosen for its association with trust,
  // professionalism, and reduced eye strain in extended play sessions.

  /// The main background colour used across all screens.
  static const Color primaryNavy = Color(0xFF0D1B2A);

  /// A slightly lightened variant used for surfaces that sit above the background
  /// (e.g., cards, panels, drawers) to create a subtle depth hierarchy.
  static const Color primaryNavyLight = Color(0xFF1B2A3A);

  /// A deeper variant used for elements that need to recede or appear behind
  /// the main surface (e.g., AppBar, bottom navigation).
  static const Color primaryNavyDark = Color(0xFF060D14);

  // ============================================================================
  // SECONDARY COLOURS — 30% (Amber)
  // ============================================================================
  // The secondary colour appears on highlights, interactive elements, and UI
  // components that need to stand out from the navy background without
  // being as bold as an accent. Amber provides warmth and a welcoming feel.

  /// The primary amber colour for secondary UI elements, active states, and highlights.
  static const Color secondaryAmber = Color(0xFFFFB300);

  /// A lighter amber variant for hover states, lighter badges, or subtle highlights.
  static const Color secondaryAmberLight = Color(0xFFFFCA28);

  /// A deeper amber for pressed states, borders, or elements needing more contrast.
  static const Color secondaryAmberDark = Color(0xFFFF8F00);

  // ============================================================================
  // ACCENT COLOURS — 10%
  // ============================================================================
  // Accent colours are used sparingly for the most important interactive elements.
  // Two accent families are available: gold (for betting/casino contexts) and
  // electric blue (for primary CTAs and interactive affordances).

  // ---- Betting Accent: Gold ----
  // Gold reinforces the high-end casino atmosphere on Blackjack betting UI.
  // Used on chip values, bankroll displays, and FABs related to wagering.

  /// Primary gold accent for casino-themed UI elements.
  static const Color accentGold = Color(0xFFFFD700);

  /// Lighter gold for hover states or secondary decorative elements.
  static const Color accentGoldLight = Color(0xFFFFE57F);

  /// Deeper gold for pressed states or stronger contrast on dark backgrounds.
  static const Color accentGoldDark = Color(0xFFFFC107);

  // ---- Primary Action Accent: Electric Blue ----
  // Electric blue is the primary call-to-action colour. Its high contrast against
  // navy makes interactive elements immediately identifiable, supporting WCAG 2.2
  // Level AA contrast requirements for accessibility.

  /// The primary action colour for buttons, links, and focus states.
  static const Color accentElectricBlue = Color(0xFF00E5FF);

  /// Lighter variant for loading indicators or subtle hover/focus effects.
  static const Color accentElectricBlueLight = Color(0xFF6EFFFF);

  /// Deeper variant for pressed states or elements requiring stronger contrast.
  static const Color accentElectricBlueDark = Color(0xFF00B8D4);

  // ============================================================================
  // SEMANTIC COLOURS (Universal across the platform)
  // ============================================================================
  // These colours carry universal meaning and are used consistently across all
  // screens for feedback states (success, error, warning, info).

  /// Used for success states: round wins, successful actions, form validation passes.
  static const Color success = Color(0xFF4CAF50);

  /// Darker success variant for pressed states or stronger contrast requirements.
  static const Color successDark = Color(0xFF388E3C);

  /// Used for error states: invalid inputs, failed operations, losing outcomes.
  static const Color error = Color(0xFFE53935);

  /// Darker error variant for error borders or pressed error buttons.
  static const Color errorDark = Color(0xFFC62828);

  /// Used for warnings: low bankroll notifications, session expiry notices.
  static const Color warning = Color(0xFFFFA726);

  /// Used for informational states: tooltips, helper text, non-critical notices.
  static const Color info = Color(0xFF29B6F6);

  // ============================================================================
  // GAME-SPECIFIC COLOUR SCHEMES
  // ============================================================================
  // Each game has its own colour personality that complements the platform
  // palette whilst reinforcing the aesthetic of that game type.

  // ---- Blackjack: Classic Casino ----
  // Deep reds, casino greens, and golds evoke traditional casino card table
  // aesthetics, reinforcing the game's identity and immersive experience.

  /// Deep casino-felt red used for card suit symbols and game result highlights.
  static const Color blackjackRed = Color(0xFF8B0000);

  /// Traditional casino table green used for the game surface background.
  static const Color blackjackGreen = Color(0xFF0B5D1E);

  /// Gold accent used for chip values, win notifications, and premium UI elements.
  static const Color blackjackGold = Color(0xFFFFD700);

  /// Dark background used on the reverse face of playing cards.
  static const Color blackjackCardBack = Color(0xFF1A0F0F);

  // ---- Crazy Eights: Bright & Playful ----
  // Bold, saturated primaries match the energetic, fast-paced nature of the game.
  // The colour-per-suit system mirrors traditional Uno card colour conventions.

  /// Red suit colour (hearts/diamonds equivalent).
  static const Color unoRed = Color(0xFFE53935);

  /// Blue suit colour.
  static const Color unoBlue = Color(0xFF1E88E5);

  /// Yellow suit colour.
  static const Color unoYellow = Color(0xFFFDD835);

  /// Green suit colour.
  static const Color unoGreen = Color(0xFF43A047);

  /// Dark slate background for the Crazy Eights game screen, providing
  /// contrast against the bright card colours.
  static const Color unoBackground = Color(0xFF263238);

  // ---- Checkers: Traditional Board Game (Legacy Palette) ----
  // Warm browns and cream tones reference the physical aesthetic of a classic
  // wooden draughts board. Retained in the palette for potential future use.

  /// Light square colour (cream/bisque).
  static const Color checkersLight = Color(0xFFFFE4C4);

  /// Dark square colour (saddle brown).
  static const Color checkersDark = Color(0xFF8B4513);

  /// Board surround colour (dark wood tone).
  static const Color checkersBoard = Color(0xFF4A3428);

  /// Highlight colour shown on valid move squares.
  static const Color checkersHighlight = Color(0xFFFFD700);

  // ============================================================================
  // TEXT & UI ELEMENT COLOURS
  // ============================================================================

  // ---- Text ----

  /// Primary text colour. White on dark backgrounds meets WCAG AA contrast ratios.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text used for hints, subtitles, and less important labels.
  static const Color textSecondary = Color(0xFFB0BEC5);

  /// Disabled or placeholder text colour; visually de-emphasised.
  static const Color textDisabled = Color(0xFF607D8B);

  /// Text colour for use on amber-coloured backgrounds (black for contrast).
  static const Color textOnAmber = Color(0xFF000000);

  /// Text colour for use on gold-coloured backgrounds (black for contrast).
  static const Color textOnGold = Color(0xFF000000);

  // ---- Surfaces ----

  /// The default raised surface colour (e.g., cards, bottom sheets, side drawers).
  static const Color surface = Color(0xFF1B2A3A);

  /// A lighter surface variant for elements layered above [surface].
  static const Color surfaceLight = Color(0xFF2D3E50);

  /// A darker surface variant for elements that sit below [surface] in the
  /// visual hierarchy.
  static const Color surfaceDark = Color(0xFF0A1520);

  // ---- Borders & Dividers ----

  /// Default border colour for containers, inputs, and outlined components.
  static const Color border = Color(0xFF37474F);

  /// Lighter border variant for subtle separations or focus ring alternatives.
  static const Color borderLight = Color(0xFF546E7A);

  /// Divider line colour between list items or sections.
  static const Color divider = Color(0xFF263238);

  // ---- Overlays ----

  /// 80% opaque black used for modal barriers and full-screen overlays.
  static const Color overlay = Color(0xCC000000);

  /// 60% opaque black used for lighter scrims behind bottom sheets or drawers.
  static const Color scrim = Color(0x99000000);

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Returns the appropriate text colour (white or black) for a given background.
  ///
  /// Uses Flutter's built-in brightness estimation, ensuring readable text
  /// contrast on dynamically coloured surfaces.
  static Color getTextColorForBackground(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? textPrimary : const Color(0xFF000000);
  }

  /// Returns the primary game-specific colour for a given [gameType] string.
  ///
  /// Used when a screen or widget needs to adapt its accent colour to the
  /// currently active game (e.g., game lobby cards, room headers).
  ///
  /// Falls back to [primaryNavy] for unrecognised game types.
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

// ============================================================================
// APP THEME
// ============================================================================

/// Provides the Material 3 [ThemeData] for the entire application.
///
/// A single dark theme is defined, consistent with the platform's dark-mode-first
/// design approach. All widget themes (buttons, inputs, dialogs, etc.) are
/// configured here using [AppColors] to maintain a single source of truth.
///
/// Typography:
///   - Montserrat is used for all display/headline/title text styles.
///   - Inter is used for all body/label text styles.
///
/// Usage:
///   MaterialApp(
///     theme: AppTheme.darkTheme,
///     ...
///   )
class AppTheme {
  /// The application's single dark theme configuration.
  static ThemeData get darkTheme {
    return ThemeData(
      // Use Material 3's updated design tokens and component behaviour.
      useMaterial3: true,

      // Dark overall brightness — widgets adapt their default colours accordingly.
      brightness: Brightness.dark,

      // ---- Colour Scheme (60-30-10 mapped to Material 3 roles) ----
      colorScheme: ColorScheme.dark(
        // Primary (Navy — 60%): Used for surfaces, backgrounds, and containers.
        primary: AppColors.primaryNavy,
        primaryContainer: AppColors.primaryNavyLight,
        onPrimary: AppColors.textPrimary,
        onPrimaryContainer: AppColors.textPrimary,

        // Secondary (Amber — 30%): Used for secondary buttons, chips, and highlights.
        secondary: AppColors.secondaryAmber,
        secondaryContainer: AppColors.secondaryAmberDark,
        onSecondary: AppColors.textOnAmber,
        onSecondaryContainer: AppColors.textOnAmber,

        // Tertiary (Electric Blue — 10%): Used for primary CTAs and interactive accents.
        tertiary: AppColors.accentElectricBlue,
        tertiaryContainer: AppColors.accentElectricBlueDark,
        onTertiary: AppColors.primaryNavyDark,
        onTertiaryContainer: AppColors.textPrimary,

        // Error: Used for validation failures and destructive action states.
        error: AppColors.error,
        errorContainer: AppColors.errorDark,
        onError: AppColors.textPrimary,
        onErrorContainer: AppColors.textPrimary,

        // Surface: Defines the default surface and elevated surface colours.
        surface: AppColors.primaryNavy,
        surfaceContainerHighest: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,

        // Outline: Used for borders and dividers across components.
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      ),

      // Default scaffold background for all screens.
      scaffoldBackgroundColor: AppColors.primaryNavy,

      // ---- Card Theme ----
      // Cards use the slightly lighter surface colour to stand out from
      // the navy scaffold background, with a generous border radius.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ---- AppBar Theme ----
      // Slightly darker than the scaffold to create subtle depth separation.
      // Titles use Montserrat bold, consistent with the heading typography scale.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryNavyDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0, // Flat, consistent with Material 3 guidelines.
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),

      // ---- Elevated Button Theme ----
      // Primary CTA buttons use electric blue with dark text for maximum
      // contrast and interactive affordance.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentElectricBlue,
          foregroundColor: AppColors.primaryNavyDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ---- Text Button Theme ----
      // Used for less prominent actions (e.g., "Forgot password?", "Cancel").
      // Amber foreground ensures visibility without the weight of a filled button.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryAmber,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ---- Outlined Button Theme ----
      // Secondary actions that need more prominence than a text button.
      // Amber border on dark background provides clear affordance.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.secondaryAmber, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ---- Input Decoration Theme ----
      // Consistent styling for all TextFormField and TextField widgets.
      // Focus state uses electric blue to clearly indicate the active field.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        // Electric blue focus border provides clear visual feedback.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentElectricBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textDisabled,
        ),
      ),

      // ---- Floating Action Button Theme ----
      // FABs use gold to distinguish them as the most prominent on-screen action.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentGold,
        foregroundColor: AppColors.textOnGold,
        elevation: 8,
      ),

      // ---- Dialog Theme ----
      // Dialogs use the surface colour to float above the navy background.
      // Generous border radius maintains the rounded, modern aesthetic.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),

      // ---- Divider Theme ----
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 16,
      ),

      // ---- Icon Theme ----
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),

      // ---- Text Theme ----
      // Two-font system:
      //   Montserrat: Display, Headline, and Title styles (prominent text)
      //   Inter:      Body and Label styles (readable text at small sizes)
      textTheme: const TextTheme(

        // ---- Display Styles (Montserrat) ----
        // For hero text, splash screens, and major promotional headings.
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

        // ---- Headline Styles (Montserrat) ----
        // For screen headings, section titles, and game result banners.
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

        // ---- Title Styles (Montserrat) ----
        // For card titles, dialog headers, and list item primary text.
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

        // ---- Body Styles (Inter) ----
        // For paragraph text, descriptions, and general UI copy.
        // Sizes follow the 12–16px recommendation for screen legibility.
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
          color: AppColors.textSecondary, // Slightly muted for secondary body text.
        ),

        // ---- Label Styles (Inter) ----
        // For button text, form labels, badges, and compact UI elements.
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