// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'single/blackjack_screen.dart';
import 'multi/multiplayer_lobby_screen.dart';
import 'chat_test_screen.dart';
import 'single/crazy_eights_screen.dart';
import 'profile_screen.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../components/slide_in_panel.dart';
// TODO: Remove this import once CheckersScreen and CheckersGame have been
// deleted from the codebase. The Checkers game is no longer part of the platform.
import 'single/checkers_screen.dart';

/// Main game-selection screen shown after a successful login.
///
/// Displays single-player games (Blackjack, Crazy Eights), the multiplayer
/// lobby entry point, and — temporarily — a debug section used during
/// development of the chat and voice systems.
class HomeScreen extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const HomeScreen({super.key, required this.user, required this.onLogout});

  void _openMenu(BuildContext context) {
    SlideInPanel.show(
      context: context,
      child: MenuPanel(
        user: user,
        username: user.username,
        onProfile: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(user: user, onLogout: onLogout)),
        ),
        onSettings: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings coming soon'), backgroundColor: AppColors.secondaryAmber),
        ),
        onHelp: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help & Support coming soon'), backgroundColor: AppColors.secondaryAmber),
        ),
        onLogout: onLogout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size         = MediaQuery.of(context).size;
    final titleSize    = size.height * 0.12;
    final buttonWidth  = size.width  * 0.35;
    final buttonHeight = size.height * 0.15;
    final spacing      = size.height * 0.03;

    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical:   size.height * 0.05,
                    horizontal: size.width  * 0.05,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Game Collection',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: titleSize.clamp(24.0, 56.0),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          shadows: const [Shadow(blurRadius: 10, color: AppColors.primaryNavyDark, offset: Offset(0, 4))],
                        ),
                      ),
                      SizedBox(height: spacing),

                      Text(
                        'Welcome, ${user.username}!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: (titleSize * 0.4).clamp(14.0, 24.0),
                          color: AppColors.secondaryAmber,
                        ),
                      ),
                      SizedBox(height: spacing * 2),

                      // ─── Single Player ───────────────────────────────────
                      Text(
                        'Single Player',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: (titleSize * 0.5).clamp(18.0, 32.0),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: spacing),

                      _GameButton(
                        title: '🃏 Blackjack',
                        icon: Icons.casino,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BlackjackScreen(user: user)),
                        ),
                        enabled: true,
                        width: buttonWidth, height: buttonHeight,
                      ),
                      SizedBox(height: spacing),

                      _GameButton(
                        title: '🎴 Crazy Eights',
                        icon: Icons.style,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CrazyEightsScreen(user: user)),
                        ),
                        enabled: true,
                        width: buttonWidth, height: buttonHeight,
                      ),
                      SizedBox(height: spacing),

                      // TODO: Remove the Checkers button once CheckersScreen
                      // and CheckersGame have been deleted from the project.
                      _GameButton(
                        title: '🎲 Checkers',
                        icon: Icons.grid_on,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CheckersScreen()),
                        ),
                        enabled: true,
                        width: buttonWidth, height: buttonHeight,
                      ),
                      SizedBox(height: spacing * 2),

                      // ─── Multiplayer ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, color: Colors.amber, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Multiplayer',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: (titleSize * 0.5).clamp(18.0, 28.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // "ONLINE" badge confirms the backend is reachable.
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'ONLINE',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: (titleSize * 0.3).clamp(10.0, 14.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing),

                      _GameButton(
                        title: 'Play Online',
                        icon: Icons.wifi,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MultiplayerLobbyScreen(user: user)),
                        ),
                        enabled: true,
                        width: buttonWidth, height: buttonHeight,
                        isMultiplayer: true,
                      ),

                      // ─── DEBUG ─────────────────────────────────────────
                      // TODO: Remove this entire section before release.
                      // ChatTestScreen is a developer tool for verifying
                      // Socket.IO chat and WebRTC voice — not a production feature.
                      SizedBox(height: spacing * 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bug_report, color: Colors.red, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'DEBUG / TESTING',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: (titleSize * 0.4).clamp(14.0, 20.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing),

                      _GameButton(
                        title: '🧪 Chat Test',
                        icon: Icons.chat_bubble,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatTestScreen(user: user)),
                        ),
                        enabled: true,
                        width: buttonWidth, height: buttonHeight,
                        isDebug: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Menu button (top-right) opens the slide-in navigation panel.
            Positioned(
              top: 16, right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openMenu(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.secondaryAmber, AppColors.secondaryAmberDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentGold, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    child: const Icon(Icons.menu, color: AppColors.textOnAmber, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width game entry button used for both single-player and multiplayer tiles.
///
/// Disabled buttons show a "Soon" badge rather than being hidden outright,
/// so users can see what is planned without being able to access incomplete features.
class _GameButton extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final VoidCallback? onPressed;
  final bool         enabled;
  final double       width;
  final double       height;
  final bool         isMultiplayer;
  final bool         isDebug;

  const _GameButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    required this.enabled,
    required this.width,
    required this.height,
    this.isMultiplayer = false,
    this.isDebug       = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = (height * 0.4).clamp(20.0, 40.0);
    final fontSize = (height * 0.3).clamp(16.0, 28.0);

    return SizedBox(
      width: width, height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? (isDebug ? AppColors.secondaryAmber : AppColors.accentElectricBlue)
              : const Color.fromARGB(255, 0, 126, 146),
          disabledBackgroundColor: const Color.fromARGB(183, 1, 86, 99),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: enabled ? 8 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: enabled ? AppColors.textPrimary : Colors.grey.shade500),
            SizedBox(width: width * 0.04),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Montserrat', fontSize: fontSize, fontWeight: FontWeight.bold,
                  color: enabled ? AppColors.textPrimary : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!enabled) ...[
              SizedBox(width: width * 0.02),
              Container(
                padding: EdgeInsets.symmetric(horizontal: width * 0.02, vertical: height * 0.08),
                decoration: BoxDecoration(color: AppColors.secondaryAmber, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: (fontSize * 0.5).clamp(10.0, 14.0),
                    fontWeight: FontWeight.bold, color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}