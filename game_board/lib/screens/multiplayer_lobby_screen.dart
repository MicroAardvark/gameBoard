// ====================================
// lib/screens/multiplayer_lobby_screen.dart
// Universal multiplayer lobby - select game type
// ====================================
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'multiplayer_blackjack_screen.dart';

class MultiplayerLobbyScreen extends StatelessWidget {
  final User user;

  const MultiplayerLobbyScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    final titleSize = isLandscape ? size.height * 0.10 : size.width * 0.08;
    final cardWidth = isLandscape ? size.width * 0.28 : size.width * 0.85;
    final cardHeight = isLandscape ? size.height * 0.65 : size.height * 0.30;
    final spacing = size.height * 0.02;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A6B3A),
              Color(0xFF124B2A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: (0.3)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multiplayer Games',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize.clamp(20.0, 32.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select a game to play online',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: titleSize.clamp(12.0, 16.0) * 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // User Info Card
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: (0.3)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: (0.3)),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.amber,
                      child: Text(
                        user.username[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Bankroll: £${user.bankroll.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.amber[300],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.people,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing),

              // Game Selection
              Expanded(
                child: isLandscape
                    ? _buildLandscapeLayout(context, cardWidth, cardHeight, spacing)
                    : _buildPortraitLayout(context, cardWidth, cardHeight, spacing),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, double cardWidth, double cardHeight, double spacing) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGameCard(
            context: context,
            title: 'Blackjack',
            description: 'Classic card game - Beat the dealer to 21',
            icon: Icons.casino,
            color: Colors.red,
            isAvailable: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MultiplayerBlackjackScreen(user: user),
                ),
              );
            },
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(height: spacing),
          _buildGameCard(
            context: context,
            title: 'UNO',
            description: 'Fast-paced matching card game',
            icon: Icons.style,
            color: Colors.orange,
            isAvailable: false,
            onTap: null,
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(height: spacing),
          _buildGameCard(
            context: context,
            title: 'Checkers',
            description: 'Strategic board game classic',
            icon: Icons.grid_on,
            color: Colors.blue,
            isAvailable: false,
            onTap: null,
            width: cardWidth,
            height: cardHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, double cardWidth, double cardHeight, double spacing) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MultiplayerBlackjackScreen(user: user),
                ),
              );
            },
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(width: spacing),
          _buildGameCard(
            context: context,
            title: 'UNO',
            description: 'Fast-paced matching card game',
            icon: Icons.style,
            color: Colors.orange,
            isAvailable: false,
            onTap: null,
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(width: spacing),
          _buildGameCard(
            context: context,
            title: 'Checkers',
            description: 'Strategic board game classic',
            icon: Icons.grid_on,
            color: Colors.blue,
            isAvailable: false,
            onTap: null,
            width: cardWidth,
            height: cardHeight,
          ),
        ],
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
    return Container(
      width: width,
      height: height,
      child: Card(
        elevation: isAvailable ? 12 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isAvailable ? color.withValues(alpha: (0.5)) : Colors.grey.withValues(alpha: (0.3)),
            width: 3,
          ),
        ),
        color: isAvailable ? Color(0xFF2F5233) : Colors.grey.shade800,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Pattern
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: _CardPatternPainter(
                      color: color.withValues(alpha: (isAvailable ? 0.1 : 0.05)),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAvailable 
                            ? color.withValues(alpha: (0.2))
                            : Colors.grey.withValues(alpha: (0.2)),
                        border: Border.all(
                          color: isAvailable ? color : Colors.grey,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 40,
                        color: isAvailable ? color : Colors.grey,
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: isAvailable ? Colors.white : Colors.grey,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Description
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isAvailable ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    
                    Spacer(),
                    
                    // Status/Button
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? color.withValues(alpha: (0.3))
                            : Colors.grey.withValues(alpha: (0.3)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAvailable ? color : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAvailable ? Icons.play_arrow : Icons.lock,
                            color: isAvailable ? Colors.white : Colors.grey,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            isAvailable ? 'Play Now' : 'Coming Soon',
                            style: TextStyle(
                              color: isAvailable ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Online Indicator (for available games)
              if (isAvailable)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
}

// Custom painter for card background pattern
class _CardPatternPainter extends CustomPainter {
  final Color color;

  _CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Create diamond pattern
    for (double x = -50; x < size.width + 50; x += 80) {
      for (double y = -50; y < size.height + 50; y += 80) {
        path.moveTo(x, y - 20);
        path.lineTo(x + 20, y);
        path.lineTo(x, y + 20);
        path.lineTo(x - 20, y);
        path.close();
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CardPatternPainter oldDelegate) => false;
}