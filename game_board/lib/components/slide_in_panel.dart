// lib/components/slide_in_panel.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../screens/settings_screen.dart';

/// Reusable slide-in panel that animates from the right side of the screen
/// Used for menus, settings, notifications, etc.
class SlideInPanel extends StatefulWidget {
  final Widget child;
  final double? width;
  final VoidCallback? onClose;
  
  const SlideInPanel({
    super.key,
    required this.child,
    this.width,
    this.onClose,
  });

  @override
  State<SlideInPanel> createState() => _SlideInPanelState();
  
  /// Show the slide-in panel with animation
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double? width,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return SlideInPanel(
            width: width,
            child: child,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          
          final tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          
          final offsetAnimation = animation.drive(tween);
          
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }
}

class _SlideInPanelState extends State<SlideInPanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelWidth = widget.width ?? size.width * 0.35;
    
    return Stack(
      children: [
        // Semi-transparent backdrop
        GestureDetector(
          onTap: _close,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black54,
            ),
          ),
        ),
        
        // Slide-in panel
        Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: panelWidth,
              height: size.height,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 20,
                    offset: Offset(-5, 0),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pre-built menu panel with common options
class MenuPanel extends StatelessWidget {
  final User user;
  final String username;
  final VoidCallback onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  final VoidCallback onLogout;
  
  const MenuPanel({
    super.key,
    required this.user,
    required this.username,
    required this.onProfile,
    required this.onLogout,
    this.onSettings,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(size.width * 0.04),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondaryAmber,
                AppColors.secondaryAmberDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              // User Avatar
              Container(
                width: size.height * 0.08,
                height: size.height * 0.08,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryNavyDark,
                  border: Border.all(
                    color: AppColors.accentGold,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: size.height * 0.04,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: size.width * 0.02),
              
              // Username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: size.height * 0.03,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnAmber,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Player',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: size.height * 0.02,
                        color: AppColors.textOnAmber.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Close button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: AppColors.textOnAmber,
                  size: size.height * 0.035,
                ),
              ),
            ],
          ),
        ),
        
        // Menu Items
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
            children: [
              _MenuItem(
                icon: Icons.person,
                title: 'Profile',
                onTap: () {
                  Navigator.of(context).pop();
                  onProfile();
                },
              ),
              
              if (onSettings != null)
                _MenuItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(
                          user: user,
                          onLogout: onLogout,
                        ),
                      ),
                    );
                  },
                ),
              
              if (onHelp != null)
                _MenuItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.of(context).pop();
                    onHelp!();
                  },
                ),
              
              Divider(
                color: AppColors.border,
                thickness: 1,
                height: size.height * 0.04,
              ),
              
              _MenuItem(
                icon: Icons.logout,
                title: 'Logout',
                textColor: Colors.red.shade400,
                iconColor: Colors.red.shade400,
                onTap: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
              ),
            ],
          ),
        ),
        
        // Footer
        Container(
          padding: EdgeInsets.all(size.width * 0.04),
          child: Text(
            'Microvark Gaming Platform',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: size.height * 0.018,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;
  
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.height * 0.02,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? AppColors.secondaryAmber,
                size: size.height * 0.035,
              ),
              SizedBox(width: size.width * 0.03),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size.height * 0.025,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: size.height * 0.03,
              ),
            ],
          ),
        ),
      ),
    );
  }
}