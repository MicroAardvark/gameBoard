// lib/screens/blackjack_screen.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../games/blackjack_game.dart';
import '../../models/user.dart';
import '../../models/enums.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_rules_popup.dart';
import '../../widgets/betting_side_menu.dart';

/// Hosts the single-player Blackjack [FlameGame] with a Flutter betting side
/// menu and AppBar showing live bankroll and win/loss record.
///
/// The betting menu is deliberately shown only once the game has fully loaded
/// (after a 500 ms delay) to avoid the menu animating in before the canvas is
/// ready, which would look jarring.
class BlackjackScreen extends StatefulWidget {
  final User user;

  const BlackjackScreen({super.key, required this.user});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  late final BlackjackGame _game;
  bool      _showBettingMenu = false;
  bool      _gameLoaded      = false;
  GameState _gameState       = GameState.betting;

  @override
  void initState() {
    super.initState();
    _game = BlackjackGame(
      user: widget.user,
      onGameStateChanged: _handleGameStateChanged,
    );

    // Show the betting menu only after the Flame canvas has had time to render;
    // otherwise the slide-in animation fires against a black background.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _gameLoaded = true;
          if (_gameState == GameState.betting) _showBettingMenu = true;
        });
      }
    });
  }

  /// Called by [BlackjackGame] whenever the round phase changes.
  ///
  /// The betting menu visibility is driven by game state rather than manual
  /// toggles so the menu always reflects the true phase — it cannot get out
  /// of sync with the game engine.
  void _handleGameStateChanged(GameState newState) {
    if (mounted) {
      setState(() {
        _gameState      = newState;
        _showBettingMenu = _gameLoaded && newState == GameState.betting;
      });
    }
  }

  void _handleBetConfirmed(double betAmount) {
    // Passing the bet to the game triggers an onGameStateChanged(playing)
    // callback, which will hide the menu automatically via _handleGameStateChanged.
    _game.confirmBetAndStart(betAmount);
  }

  // Called when the user closes the menu without placing a bet; currently a
  // no-op because the menu should remain visible during the betting phase.
  void _handleBettingMenuClosed() {}

  @override
  Widget build(BuildContext context) {
    final size        = MediaQuery.of(context).size;
    final buttonSize  = (size.height * 0.06).clamp(32.0, 48.0);
    final topPadding  = size.height * 0.02;
    final leftPadding = size.width  * 0.02;

    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      appBar: AppBar(
        toolbarHeight: 35,
        backgroundColor: AppColors.primaryNavyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Blackjack',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 20, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(width: 8),

            // Live bankroll display.
            const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 13),
            const SizedBox(width: 4),
            Text(
              '£${_game.bankroll.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: 'Inter', color: Colors.amber[300], fontSize: 13, fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),

            // Active/staged bet badges — only shown when relevant.
            if (_game.currentBet > 0 || _game.stagedBet > 0) ...[
              _BetBadge(label: 'Bet: £${_game.currentBet.toStringAsFixed(0)}', color: Colors.blue),
              const SizedBox(width: 4),
            ],
            if (_game.stagedBet > 0)
              _BetBadge(label: 'Staged: £${_game.stagedBet.toStringAsFixed(0)}', color: Colors.purple),
          ],
        ),
        actions: [
          // Win / loss record.
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryNavyDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryNavyLight.withValues(alpha: 0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_game.playerWins}W', style: TextStyle(fontFamily: 'Inter', color: Colors.green[300], fontSize: 12, fontWeight: FontWeight.bold)),
                Text(' / ',                 style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 11)),
                Text('${_game.dealerWins}L', style: TextStyle(fontFamily: 'Inter', color: Colors.red[300], fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.textPrimary, size: 19),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => GameRulesPopup.show(
              context: context, gameType: 'blackjack', isMultiplayer: false,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          GameWidget(game: _game),

          // Betting menu slides in from the left edge when it is the player's
          // turn to bet. Width is capped at 35% of screen width to avoid
          // covering too much of the game canvas on large displays.
          if (_showBettingMenu)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -1.0, end: 0.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(value * (size.width * 0.35), 0),
                  child: child,
                ),
                child: BettingSideMenu(
                  currentBankroll: _game.bankroll,
                  minimumBet:  10.0,
                  maximumBet:  500.0,
                  onConfirm: _handleBetConfirmed,
                  onClose:   _handleBettingMenuClosed,
                ),
              ),
            ),

          // TODO: The back button and info button are duplicated here and in
          // the AppBar above. The AppBar versions should be removed — the
          // overlay versions were added for full-screen mode and take precedence
          // visually, but both sets respond to taps which is confusing.
          Positioned(
            top: topPadding, left: leftPadding,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: buttonSize * 0.7),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryNavyDark.withValues(alpha: 0.5),
                  padding: EdgeInsets.all(buttonSize * 0.25),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16, right: 16,
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.textPrimary, size: 28),
              onPressed: () => GameRulesPopup.show(
                context: context, gameType: 'blackjack', isMultiplayer: false,
              ),
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

/// Small coloured badge used in the AppBar to show the current or staged bet.
class _BetBadge extends StatelessWidget {
  final String label;
  final MaterialColor color;

  const _BetBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Inter', color: color[200], fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}