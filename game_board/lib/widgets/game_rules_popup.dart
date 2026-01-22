// ====================================
// lib/widgets/game_rules_popup.dart
// Reusable popup for displaying game rules
// ====================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class GameRulesPopup extends StatelessWidget {
  final String gameType;
  final bool isMultiplayer;

  const GameRulesPopup({
    super.key,
    required this.gameType,
    this.isMultiplayer = false,
  });

  /// Show the rules popup as a dialog
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

  /// Load rules from asset file for single player games
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

  /// Get game display name from game type
  String _getGameDisplayName() {
    switch (gameType.toLowerCase()) {
      case 'blackjack':
        return 'Blackjack';
      case 'crazyeights':
      case 'crazy_eights':
        return 'Crazy Eights Enhanced';
      case 'checkers':
        return 'Checkers';
      default:
        return gameType.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    // Responsive sizing
    final dialogWidth = isLandscape ? size.width * 0.6 : size.width * 0.85;
    final dialogHeight = isLandscape ? size.height * 0.75 : size.height * 0.7;
    final titleSize = isLandscape ? 22.0 : 20.0;  // Reduced from 28/24
    final bodySize = isLandscape ? 16.0 : 14.0;
    final padding = isLandscape ? 24.0 : 16.0;
    final headerPadding = isLandscape ? 16.0 : 12.0;  // Smaller header padding

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
            // Header
            Container(
              padding: EdgeInsets.all(headerPadding),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.secondaryAmber,
                    size: titleSize + 2,  // Slightly larger than text
                  ),
                  SizedBox(width: 8),  // Reduced from 12
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

            // Content
            Expanded(
              child: FutureBuilder<String>(
                future: isMultiplayer 
                    ? Future.value('Multiplayer rules coming soon!')
                    : _loadRulesFromAsset(),
                builder: (context, snapshot) {
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

                  final rulesText = snapshot.data ?? 'No rules available.';

                  return Scrollbar(
                    thumbVisibility: true,
                    thickness: 8,
                    radius: Radius.circular(4),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Parse and display the rules text
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

  /// Parse rules text and convert to widgets with formatting
  List<Widget> _parseRulesText(String text, double baseSize) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    for (var line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) {
        // Empty line - add spacing
        widgets.add(SizedBox(height: 8));
        continue;
      }

      // Check if line is a section header (all caps or ends with ':')
      if (_isSectionHeader(trimmedLine)) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
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
      // Check if line is a bullet point
      else if (_isBulletPoint(trimmedLine)) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
      // Check if line is a numbered point
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
      // Regular text
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

  /// Check if a line is a section header
  bool _isSectionHeader(String line) {
    // All caps (at least 3 chars) or ends with colon
    return (line.length >= 3 && line == line.toUpperCase()) || 
           line.endsWith(':');
  }

  /// Check if a line is a bullet point
  bool _isBulletPoint(String line) {
    return line.startsWith('- ') || 
           line.startsWith('• ') || 
           line.startsWith('* ');
  }

  /// Clean bullet point markers
  String _cleanBulletPoint(String line) {
    if (line.startsWith('- ')) return line.substring(2);
    if (line.startsWith('• ')) return line.substring(2);
    if (line.startsWith('* ')) return line.substring(2);
    return line;
  }

  /// Check if a line is a numbered point
  bool _isNumberedPoint(String line) {
    final numberPattern = RegExp(r'^\d+\.');
    return numberPattern.hasMatch(line);
  }
}