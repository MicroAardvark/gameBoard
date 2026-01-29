// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'blackjack_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'chat_test_screen.dart';
import 'crazy_eights_screen.dart';
import 'profile_screen.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../components/slide_in_panel.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  void _openMenu(BuildContext context) {
    SlideInPanel.show(
      context: context,
      child: MenuPanel(
        user: user,
        username: user.username,
        onProfile: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                user: user,
                onLogout: onLogout,
              ),
            ),
          );
        },
        onSettings: () {
          // TODO: Navigate to settings screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Settings coming soon'),
              backgroundColor: AppColors.secondaryAmber,
            ),
          );
        },
        onHelp: () {
          // TODO: Navigate to help screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Help & Support coming soon'),
              backgroundColor: AppColors.secondaryAmber,
            ),
          );
        },
        onLogout: onLogout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Landscape-only sizing
    final titleSize = size.height * 0.12;
    final buttonWidth = size.width * 0.35;
    final buttonHeight = size.height * 0.15;
    final spacing = size.height * 0.03;
    
    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      body: Container(
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
                            fontFamily: 'Montserrat',
                            fontSize: titleSize.clamp(24.0, 56.0),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            shadows: const [
                              Shadow(
                                blurRadius: 10,
                                color: AppColors.primaryNavyDark,
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
                            fontFamily: 'Inter',
                            fontSize: (titleSize * 0.4).clamp(14.0, 24.0),
                            color: AppColors.secondaryAmber,
                          ),
                        ),
                        SizedBox(height: spacing * 2),
                        
                        // Single Player Section
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
                          title: '🎴 Crazy Eights',
                          icon: Icons.style,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CrazyEightsScreen(user: user),
                              ),
                            );
                          },
                          enabled: true,
                          width: buttonWidth,
                          height: buttonHeight,
                        ),
                        SizedBox(height: spacing),
                        
                        _GameButton(
                          title: '🎲 Checkers',
                          icon: Icons.grid_on,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CrazyEightsScreen(user: user),
                              ),
                            );
                          },
                          enabled: true,
                          width: buttonWidth,
                          height: buttonHeight,
                        ),
                        SizedBox(height: spacing * 2),
                        
                        // Multiplayer Section
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people, color: Colors.amber, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Multiplayer',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: (titleSize * 0.5).clamp(18.0, 28.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MultiplayerLobbyScreen(user: user),
                              ),
                            );
                          },
                          enabled: true,
                          width: buttonWidth,
                          height: buttonHeight,
                          isMultiplayer: true,
                        ),
                        
                        // ==========================================
                        // TEMPORARY: CHAT TEST BUTTON (REMOVE AFTER TESTING)
                        // ==========================================
                        SizedBox(height: spacing * 2),
                        
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bug_report, color: Colors.red, size: 24),
                              SizedBox(width: 8),
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatTestScreen(user: user),
                              ),
                            );
                          },
                          enabled: true,
                          width: buttonWidth,
                          height: buttonHeight,
                          isDebug: true,
                        ),
                        // ==========================================
                        // END TEMPORARY SECTION
                        // ==========================================
                      ],
                    ),
                  ),
                ),
              ),
              
              // Menu button (top-right corner)
              Positioned(
                top: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openMenu(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondaryAmber,
                            AppColors.secondaryAmberDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentGold,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.menu,
                        color: AppColors.textOnAmber,
                        size: 28,
                      ),
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
  final bool isMultiplayer;
  final bool isDebug;

  const _GameButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    required this.enabled,
    required this.width,
    required this.height,
    this.isMultiplayer = false,
    this.isDebug = false,
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
          backgroundColor: enabled 
              ? (isDebug 
                  ? AppColors.secondaryAmber
                  : AppColors.accentElectricBlue)
              : const Color.fromARGB(255, 0, 126, 146),
          disabledBackgroundColor: Color.fromARGB(183, 1, 86, 99),
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
              color: enabled ? AppColors.textPrimary : Colors.grey.shade500,
            ),
            SizedBox(width: width * 0.04),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: enabled ? AppColors.textPrimary : Colors.grey.shade500,
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
                  color: AppColors.secondaryAmber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: (fontSize * 0.5).clamp(10.0, 14.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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