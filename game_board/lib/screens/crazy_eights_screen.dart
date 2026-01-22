// lib/screens/CrazyEights_screen.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../widgets/game_rules_popup.dart';
import '../models/user.dart';
import '../games/crazy_eights_game.dart';
import '../theme/app_theme.dart';

class CrazyEightsScreen extends StatefulWidget {
  final User user;

  const CrazyEightsScreen({
    super.key,
    required this.user,
  });

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
            // The Flame game
            GameWidget(game: _game),
            
            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 32),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            
            // Info button (optional)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.textPrimary, size: 28),
                onPressed: () {
                  GameRulesPopup.show(
                    context: context,
                    gameType: 'crazyEights',
                    isMultiplayer: false,
                  );
                },
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