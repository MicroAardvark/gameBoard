// ====================================
// lib/screens/blackjack_screen.dart
// Single-player Blackjack screen with betting side menu integration - FIXED
// ====================================
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../games/blackjack_game.dart';
import '../models/user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/game_rules_popup.dart';
import '../widgets/betting_side_menu.dart';

class BlackjackScreen extends StatefulWidget {
  final User user;

  const BlackjackScreen({super.key, required this.user});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  late final BlackjackGame _game;
  bool _showBettingMenu = false;  // CHANGED: Start false
  bool _gameLoaded = false;       // NEW: Track if game is loaded
  GameState _gameState = GameState.betting;

  @override
  void initState() {
    super.initState();
    _game = BlackjackGame(
      user: widget.user,
      onGameStateChanged: _handleGameStateChanged,
    );
    
    // NEW: Wait for game to load before showing betting menu
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _gameLoaded = true;
          // Only show betting menu if we're still in betting state
          if (_gameState == GameState.betting) {
            _showBettingMenu = true;
          }
        });
      }
    });
  }

  void _handleGameStateChanged(GameState newState) {
    if (mounted) {
      setState(() {
        _gameState = newState;
        // Show betting menu only during betting state AND if game is loaded
        _showBettingMenu = (_gameLoaded && newState == GameState.betting);
      });
    }
  }

  void _handleBetConfirmed(double betAmount) {
    // Confirm the bet in the game
    _game.confirmBetAndStart(betAmount);
    
    // REMOVED: Don't manually hide - let onGameStateChanged handle it via callback
    // The game state change will trigger _handleGameStateChanged which will hide the menu
  }

  void _handleBettingMenuClosed() {
    // Optional: Handle when user closes the menu without placing a bet
    // For now, we just keep the menu open during betting state
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonSize = (size.height * 0.06).clamp(32.0, 48.0);
    final topPadding = size.height * 0.02;
    final leftPadding = size.width * 0.02;
    
    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      body: Stack(
        children: [
          // Game widget
          GameWidget(game: _game),
          
          // Betting side menu (slides in from left)
          if (_showBettingMenu)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -1.0, end: 0.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(value * (size.width * 0.35), 0),
                    child: child,
                  );
                },
                child: BettingSideMenu(
                  currentBankroll: _game.bankroll,
                  minimumBet: 10.0,
                  maximumBet: 500.0,
                  onConfirm: _handleBetConfirmed,
                  onClose: _handleBettingMenuClosed,
                ),
              ),
            ),
          
          // Back button overlay
          Positioned(
            top: topPadding,
            left: leftPadding,
            child: SafeArea(
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: buttonSize * 0.7,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryNavyDark.withValues(alpha: 0.5),
                  padding: EdgeInsets.all(buttonSize * 0.25),
                ),
              ),
            ),
          ),
          
          // Info button (rules)
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.textPrimary, size: 28),
              onPressed: () {
                GameRulesPopup.show(
                  context: context,
                  gameType: 'blackjack',
                  isMultiplayer: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _game.onDispose();
    super.dispose();
  }
}