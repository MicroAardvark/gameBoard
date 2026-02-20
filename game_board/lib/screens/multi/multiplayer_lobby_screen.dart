// lib/screens/multiplayer_lobby_screen.dart
import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'multiplayer_blackjack_lobby_screen.dart';
import '../../theme/app_theme.dart';
import 'multiplayer_crazy_eights_lobby_screen.dart';
// TODO: Remove this import once the Checkers game and its lobby have been
// deleted from the project. The Checkers card should also be removed below.
import 'multiplayer_checkers_lobby_screen.dart';

/// Game-type selection screen for multiplayer.
///
/// Shows one [_buildGameCard] per available game. Each card navigates to the
/// corresponding game-specific lobby (Blackjack → [MultiplayerBlackjackScreen],
/// Crazy Eights → [MultiplayerCrazyEightsLobbyScreen], etc.).
///
/// The card layout is horizontal-scroll only — the app is landscape-locked so
/// a single row fits all three cards without scrolling on most devices.
class MultiplayerLobbyScreen extends StatelessWidget {
  final User user;

  const MultiplayerLobbyScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final size       = MediaQuery.of(context).size;
    final titleSize  = size.height * 0.10;
    final cardWidth  = size.width  * 0.28;
    final cardHeight = size.height * 0.65;
    final spacing    = size.height * 0.02;

    return Scaffold(
      body: Container(
        color: AppColors.primaryNavyDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: AppColors.primaryNavyDark.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Multiplayer Games', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: titleSize.clamp(20.0, 32.0), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Select a game to play online', style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: titleSize.clamp(12.0, 16.0) * 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Player summary card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavyDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.amber,
                      child: Text(user.username[0].toUpperCase(), style: TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryNavyDark)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.username, style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Bankroll: £${user.bankroll.toStringAsFixed(0)}', style: TextStyle(fontFamily: 'Inter', color: Colors.amber[300], fontSize: 16)),
                        ],
                      ),
                    ),
                    const Icon(Icons.people, color: Colors.amber, size: 32),
                  ],
                ),
              ),

              SizedBox(height: spacing),

              // Game card row — horizontal scroll handles narrow screens.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGameCard(
                        context: context,
                        title: 'Blackjack',
                        description: 'Classic card game - Beat the dealer to 21',
                        icon: Icons.casino,
                        color: Colors.red,
                        isAvailable: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiplayerBlackjackScreen(user: user))),
                        width: cardWidth, height: cardHeight,
                      ),
                      SizedBox(width: spacing),
                      _buildGameCard(
                        context: context,
                        title: 'Crazy Eights',
                        description: 'Fast-paced matching card game',
                        icon: Icons.style,
                        color: Colors.orange,
                        isAvailable: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiplayerCrazyEightsLobbyScreen(user: user))),
                        width: cardWidth, height: cardHeight,
                      ),
                      SizedBox(width: spacing),
                      // TODO: Remove once Checkers multiplayer is removed from the project.
                      _buildGameCard(
                        context: context,
                        title: 'Checkers',
                        description: 'Strategic board game classic',
                        icon: Icons.grid_on,
                        color: Colors.blue,
                        isAvailable: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiplayerCheckersLobbyScreen(user: user))),
                        width: cardWidth, height: cardHeight,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isAvailable,
    required VoidCallback? onTap,
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width, height: height,
      child: Card(
        elevation: isAvailable ? 12 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isAvailable ? color.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3), width: 3),
        ),
        color: isAvailable ? AppColors.primaryNavyDark : Colors.grey.shade800,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle diamond tile pattern on the card background.
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(painter: _CardPatternPainter(color: color.withValues(alpha: isAvailable ? 0.1 : 0.05))),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAvailable ? color.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                        border: Border.all(color: isAvailable ? color : Colors.grey, width: 3),
                      ),
                      child: Icon(icon, size: 40, color: isAvailable ? color : Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(title, style: TextStyle(fontFamily: 'Montserrat', color: isAvailable ? AppColors.textPrimary : Colors.grey, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(description, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', color: isAvailable ? AppColors.textPrimary : Colors.grey.shade600, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isAvailable ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isAvailable ? color : Colors.grey, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isAvailable ? Icons.play_arrow : Icons.lock, color: isAvailable ? AppColors.textPrimary : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(isAvailable ? 'Play Now' : 'Coming Soon', style: TextStyle(fontFamily: 'Inter', color: isAvailable ? AppColors.textPrimary : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isAvailable)
                Positioned(
                  top: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primaryNavyLight, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textPrimary)),
                        const SizedBox(width: 6),
                        const Text('Online', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diamond tile pattern painter used as a decorative card background.
class _CardPatternPainter extends CustomPainter {
  final Color color;
  const _CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path  = Path();
    for (double x = -50; x < size.width + 50; x += 80) {
      for (double y = -50; y < size.height + 50; y += 80) {
        path.moveTo(x,      y - 20);
        path.lineTo(x + 20, y);
        path.lineTo(x,      y + 20);
        path.lineTo(x - 20, y);
        path.close();
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CardPatternPainter old) => false;
}