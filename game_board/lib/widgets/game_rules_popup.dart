// ====================================
// lib/widgets/game_rules_popup.dart
// Reusable popup for displaying game rules
//
// PURPOSE:
//   A modal dialog that loads and renders a game's rule text for the player
//   to read without leaving the current screen.  Rules are stored as
//   plain-text asset files under assets/rules/ and parsed at runtime into
//   formatted widgets (section headers, bullet points, numbered lists, and
//   regular paragraphs).
//
// FEATURES:
//   - Loads rules from bundled asset files (assets/rules/<gameType>.txt)
//   - Parses plain text into styled widgets with distinct heading, bullet,
//     and body styles
//   - Shows a loading spinner whilst the asset is being read
//   - Displays a friendly error state if the file cannot be found
//   - Static [show] factory method for convenient one-line invocation
//   - Responsive sizing adapts to portrait / landscape orientation
//   - Scrollable content with a visible scroll thumb for accessibility
//
// SUPPORTED GAME TYPES:
//   'blackjack'   → Blackjack
//   'crazyeights' → Crazy Eights Enhanced
//   'crazy_eights'→ Crazy Eights Enhanced (alias)
//
// ASSET FILE FORMAT:
//   Rules files are plain text.  The parser recognises:
//     - All-caps lines (≥ 3 chars) or lines ending with ':' → section headers
//     - Lines starting with '- ', '• ', or '* '             → bullet points
//     - Lines matching /^\d+\./                              → numbered items
//     - Everything else                                      → body paragraph
//
// USAGE:
//   // From anywhere with a BuildContext:
//   await GameRulesPopup.show(
//     context: context,
//     gameType: 'blackjack',
//   );
// ====================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Modal dialog that displays formatted game rules loaded from a bundled asset.
class GameRulesPopup extends StatelessWidget {
  /// The game identifier used to locate the rules asset file.
  /// Must match the filename under assets/rules/ (without the .txt extension).
  final String gameType;

  /// When `true`, a placeholder message is shown instead of loading an asset
  /// file.  Reserved for future multiplayer-specific rule variants.
  final bool isMultiplayer;

  const GameRulesPopup({
    super.key,
    required this.gameType,
    this.isMultiplayer = false,
  });

  // ─── Factory ──────────────────────────────────────────────────────────────

  /// Convenience method that shows the rules popup as a standard [Dialog].
  ///
  /// Returns a [Future] that completes when the dialog is dismissed.
  ///
  /// Example:
  /// ```dart
  /// await GameRulesPopup.show(context: context, gameType: 'blackjack');
  /// ```
  static Future<void> show({
    required BuildContext context,
    required String gameType,
    bool isMultiplayer = false,
  }) {
    return showDialog(
      context: context,
      builder: (context) => GameRulesPopup(
        gameType: gameType,
        isMultiplayer: isMultiplayer,
      ),
    );
  }

  // ─── Asset Loading ────────────────────────────────────────────────────────

  /// Reads the rules text from the bundled asset at
  /// `assets/rules/<gameType>.txt`.
  ///
  /// Returns the raw string content on success, or a user-friendly error
  /// message if the file does not exist or cannot be read.
  Future<String> _loadRulesFromAsset() async {
    try {
      final rulesText = await rootBundle.loadString(
        'assets/rules/$gameType.txt',
      );
      return rulesText;
    } catch (e) {
      print('❌ Error loading rules for $gameType: $e');
      return 'Rules file not found for $gameType.\n\nPlease contact support if this issue persists.';
    }
  }

  // ─── Display Name ─────────────────────────────────────────────────────────

  /// Maps the internal [gameType] string to a human-readable title for the
  /// dialog header.
  ///
  /// Falls back to the game type with underscores replaced by spaces and
  /// converted to upper case for any unrecognised type.
  String _getGameDisplayName() {
    switch (gameType.toLowerCase()) {
      case 'blackjack':
        return 'Blackjack';
      case 'crazyeights':
      case 'crazy_eights':
        return 'Crazy Eights Enhanced';
      default:
        // Generic fallback: "some_game" → "SOME GAME"
        return gameType.replaceAll('_', ' ').toUpperCase();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Responsive dimensions – landscape dialogs are wider but shorter to avoid
    // covering too much of the game UI.
    final dialogWidth  = isLandscape ? size.width * 0.6  : size.width * 0.85;
    final dialogHeight = isLandscape ? size.height * 0.75 : size.height * 0.7;
    final titleSize    = isLandscape ? 22.0 : 20.0;
    final bodySize     = isLandscape ? 16.0 : 14.0;
    final padding      = isLandscape ? 24.0 : 16.0;
    final headerPadding = isLandscape ? 16.0 : 12.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.secondaryAmber.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            // Dark top bar with an info icon, the game title, and a close button.
            Container(
              padding: EdgeInsets.all(headerPadding),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark,
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.secondaryAmber,
                    // Slightly larger than the title text for visual balance.
                    size: titleSize + 2,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_getGameDisplayName()} Rules',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Content Area ─────────────────────────────────────────────────
            // Asynchronously loads the rules asset and renders the parsed result.
            Expanded(
              child: FutureBuilder<String>(
                // Use a placeholder for multiplayer mode (rules not yet authored).
                future: isMultiplayer
                    ? Future.value('Multiplayer rules coming soon!')
                    : _loadRulesFromAsset(),
                builder: (context, snapshot) {

                  // ── Loading State ─────────────────────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.secondaryAmber,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading rules...',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: bodySize,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ── Error State ───────────────────────────────────────
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading rules',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: titleSize - 4,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: bodySize,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // ── Success State ─────────────────────────────────────
                  final rulesText = snapshot.data ?? 'No rules available.';

                  return Scrollbar(
                    thumbVisibility: true, // Always-visible thumb aids discoverability.
                    thickness: 8,
                    radius: Radius.circular(4),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Delegate to the text parser for formatted output.
                          ..._parseRulesText(rulesText, bodySize),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Text Parsing ─────────────────────────────────────────────────────────

  /// Parses [text] line by line and converts each line into a suitably styled
  /// [Widget] based on its detected type (header, bullet, numbered, or body).
  ///
  /// Rules file format conventions:
  ///   - Empty lines are converted to vertical spacing widgets.
  ///   - All-caps lines (≥ 3 chars) or lines ending with ':' become section
  ///     headers rendered in amber with a larger font.
  ///   - Lines starting with '- ', '• ', or '* ' become amber bullet points.
  ///   - Lines beginning with a digit followed by '.' become numbered items.
  ///   - All other lines are rendered as body text.
  List<Widget> _parseRulesText(String text, double baseSize) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    for (var line in lines) {
      final trimmedLine = line.trim();

      // ── Empty Line → Spacing ────────────────────────────────────────────
      if (trimmedLine.isEmpty) {
        widgets.add(SizedBox(height: 8));
        continue;
      }

      // ── Section Header ──────────────────────────────────────────────────
      if (_isSectionHeader(trimmedLine)) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              // Strip trailing colon from "SECTION:" style headers.
              trimmedLine.replaceAll(':', ''),
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: baseSize + 4,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryAmber,
              ),
            ),
          ),
        );
      }

      // ── Bullet Point ────────────────────────────────────────────────────
      else if (_isBulletPoint(trimmedLine)) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amber bullet character aligned with the first line of text.
                Text(
                  '• ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: baseSize,
                    color: AppColors.secondaryAmber,
                    height: 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    // Remove the original bullet marker to avoid duplication.
                    _cleanBulletPoint(trimmedLine),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: baseSize,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // ── Numbered Point ──────────────────────────────────────────────────
      else if (_isNumberedPoint(trimmedLine)) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 6),
            child: Text(
              trimmedLine,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: baseSize,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        );
      }

      // ── Regular Body Text ───────────────────────────────────────────────
      else {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              trimmedLine,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: baseSize,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ─── Parser Helpers ───────────────────────────────────────────────────────

  /// Returns `true` if [line] should be treated as a section header.
  ///
  /// A line qualifies as a header if:
  ///   - It is at least 3 characters long and entirely upper case, OR
  ///   - It ends with a colon (e.g. "Objective:").
  bool _isSectionHeader(String line) {
    return (line.length >= 3 && line == line.toUpperCase()) ||
        line.endsWith(':');
  }

  /// Returns `true` if [line] starts with a recognised bullet-point marker
  /// ('- ', '• ', or '* ').
  bool _isBulletPoint(String line) {
    return line.startsWith('- ') ||
        line.startsWith('• ') ||
        line.startsWith('* ');
  }

  /// Strips the leading bullet marker from [line], returning the plain text.
  String _cleanBulletPoint(String line) {
    if (line.startsWith('- ')) return line.substring(2);
    if (line.startsWith('• ')) return line.substring(2);
    if (line.startsWith('* ')) return line.substring(2);
    return line;
  }

  /// Returns `true` if [line] begins with a digit followed by a period
  /// (e.g. "1. Deal the cards").
  bool _isNumberedPoint(String line) {
    final numberPattern = RegExp(r'^\d+\.');
    return numberPattern.hasMatch(line);
  }
}