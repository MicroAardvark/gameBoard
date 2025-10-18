import 'package:flutter/material.dart';
import 'blackjack_screen.dart';
import '../models/user.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const HomeScreen({
    Key? key,
    required this.user,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    // Responsive sizing
    final titleSize = isLandscape 
        ? size.height * 0.12 
        : size.width * 0.10;
    final buttonWidth = isLandscape 
        ? size.width * 0.35 
        : size.width * 0.80;
    final buttonHeight = isLandscape 
        ? size.height * 0.15 
        : size.height * 0.10;
    final spacing = size.height * 0.03;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
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
          child: Stack(
            children: [
              // Main content
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: size.height * 0.05,
                      horizontal: size.width * 0.05,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title
                        Text(
                          'Game Collection',
                          style: TextStyle(
                            fontSize: titleSize.clamp(24.0, 56.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black54,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing),
                        
                        // User info
                        Text(
                          'Welcome, ${user.username}!',
                          style: TextStyle(
                            fontSize: (titleSize * 0.4).clamp(16.0, 24.0),
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'Bankroll: £${user.bankroll.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: (titleSize * 0.35).clamp(14.0, 20.0),
                            color: Colors.white60,
                          ),
                        ),
                        SizedBox(height: spacing * 2),
                        
                        // Game Buttons
                        _GameButton(
                          title: 'Blackjack',
                          icon: Icons.casino,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BlackjackScreen(user: user),
                              ),
                            );
                          },
                          enabled: true,
                          width: buttonWidth,
                          height: buttonHeight,
                        ),
                        SizedBox(height: spacing),
                        
                        _GameButton(
                          title: 'UNO',
                          icon: Icons.style,
                          onPressed: null,
                          enabled: false,
                          width: buttonWidth,
                          height: buttonHeight,
                        ),
                        SizedBox(height: spacing),
                        
                        _GameButton(
                          title: 'Checkers',
                          icon: Icons.grid_on,
                          onPressed: null,
                          enabled: false,
                          width: buttonWidth,
                          height: buttonHeight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Logout button
              Positioned(
                top: 16,
                right: 16,
                child: ElevatedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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

class _GameButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final double width;
  final double height;

  const _GameButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    required this.enabled,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = (height * 0.4).clamp(20.0, 40.0);
    final fontSize = (height * 0.3).clamp(16.0, 28.0);
    
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF2F5233) : Colors.grey.shade700,
          disabledBackgroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: enabled ? 8 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: enabled ? Colors.white : Colors.grey.shade500,
            ),
            SizedBox(width: width * 0.04),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.white : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!enabled) ...[
              SizedBox(width: width * 0.02),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.02,
                  vertical: height * 0.08,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: (fontSize * 0.5).clamp(10.0, 14.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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