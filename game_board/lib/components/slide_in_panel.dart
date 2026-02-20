// lib/components/slide_in_panel.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../screens/settings_screen.dart';

/// A panel that slides in from the right edge of the screen over a dimmed backdrop.
///
/// Can be displayed via the static [show] helper, which handles routing, or
/// instantiated directly when more control over the host route is needed.
/// The backdrop and the panel itself both dismiss on tap.
class SlideInPanel extends StatefulWidget {
  final Widget child;

  /// Panel width in logical pixels. Defaults to 35% of screen width.
  final double? width;

  /// Called after the panel has fully animated out.
  final VoidCallback? onClose;

  const SlideInPanel({
    super.key,
    required this.child,
    this.width,
    this.onClose,
  });

  @override
  State<SlideInPanel> createState() => _SlideInPanelState();

  /// Pushes the panel onto the navigation stack with a right-to-left slide.
  ///
  /// Uses a transparent [PageRouteBuilder] so the underlying screen remains
  /// visible through the dimmed backdrop. Returns the value passed to
  /// [Navigator.pop] when the panel closes, following standard Flutter route
  /// conventions.
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
          return SlideInPanel(width: width, child: child);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOut));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _SlideInPanelState extends State<SlideInPanel>
    with SingleTickerProviderStateMixin {
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

    // Slide and fade run in parallel so the panel and backdrop appear together.
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reverses the animation before popping so the panel slides back out
  /// rather than disappearing abruptly.
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
        // Fading backdrop — tapping it closes the panel the same way the
        // close button does, so the slide-out animation always plays.
        GestureDetector(
          onTap: _close,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(color: Colors.black54),
          ),
        ),

        // Panel slides in from the right edge and sits on top of the backdrop.
        Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: panelWidth,
              height: size.height,
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 20,
                    offset: Offset(-5, 0),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(child: widget.child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A ready-made navigation menu rendered inside a [SlideInPanel].
///
/// Provides profile, settings, help, and logout items. Settings and help are
/// optional — omitting their callbacks removes those items from the list entirely.
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
        _buildHeader(context, size),
        Expanded(child: _buildMenuItems(context, size)),
        _buildFooter(size),
      ],
    );
  }

  /// Amber gradient header with the user's avatar initial, username, and a
  /// close button that dismisses the panel without animation.
  Widget _buildHeader(BuildContext context, Size size) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondaryAmber, AppColors.secondaryAmberDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: size.height * 0.08,
            height: size.height * 0.08,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryNavyDark,
              border: Border.all(color: AppColors.accentGold, width: 2),
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
    );
  }

  /// Builds the scrollable list of menu items, conditionally including
  /// settings and help only when their callbacks have been provided.
  Widget _buildMenuItems(BuildContext context, Size size) {
    return ListView(
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
              // Settings is pushed as a full route rather than calling the
              // callback directly so it gets its own navigation back button.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(user: user, onLogout: onLogout),
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

        // Logout is styled red to visually distinguish it as a destructive action.
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
    );
  }

  Widget _buildFooter(Size size) {
    return Container(
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
    );
  }
}

/// A single tappable row in the [MenuPanel] list, with a leading icon,
/// title, and trailing chevron.
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// Defaults to [AppColors.secondaryAmber] when not provided.
  final Color? iconColor;

  /// Defaults to [AppColors.textPrimary] when not provided.
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