// lib/screens/crazy_eights_screen.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../widgets/game_rules_popup.dart';
import '../../models/user.dart';
import '../../games/crazy_eights_game.dart';
import '../../theme/app_theme.dart';

/// Thin wrapper screen that hosts the [CrazyEightsGame] Flame widget.
///
/// Navigation chrome (back and info buttons) is placed as a Flutter overlay
/// rather than inside the Flame game so it benefits from standard Flutter
/// touch semantics and accessibility without needing to be reimplemented in
/// the Canvas layer.
class CrazyEightsScreen extends StatefulWidget {
  final User user;

  const CrazyEightsScreen({super.key, required this.user});

  @override
  State<CrazyEightsScreen> createState() => _CrazyEightsScreenState();
}

class _CrazyEightsScreenState extends State<CrazyEightsScreen> {
  late CrazyEightsGame _game;

  @override
  void initState() {
    super.initState();
    _game = CrazyEightsGame(user: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Stack(
          children: [
            GameWidget(game: _game),

            // Back button — positioned over the game canvas so it doesn't
            // consume the AppBar height that would otherwise shrink the game area.
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.textPrimary, size: 28),
                onPressed: () => GameRulesPopup.show(
                  context: context,
                  gameType: 'crazyEights',
                  isMultiplayer: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _game.onDispose();
    super.dispose();
  }
}