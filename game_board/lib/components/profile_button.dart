// lib/components/profile_button.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

/// A circular or pill-shaped button that navigates to [ProfileScreen].
///
/// [showUsername] toggles between a compact circular avatar and an extended
/// pill layout that includes the username and a forward arrow. Both variants
/// share the same amber gradient and gold border styling.
class ProfileButton extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  /// Overrides the default size, which scales relative to screen height.
  final double? size;

  /// When true, renders the extended pill variant with username text.
  final bool showUsername;
  final EdgeInsetsGeometry? padding;

  const ProfileButton({
    super.key,
    required this.user,
    required this.onLogout,
    this.size,
    this.showUsername = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? MediaQuery.of(context).size.height * 0.06;
    return showUsername
        ? _buildExtendedButton(context, buttonSize)
        : _buildCompactButton(context, buttonSize);
  }

  /// Circular button showing only the user's initial.
  Widget _buildCompactButton(BuildContext context, double buttonSize) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProfile(context),
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: _sharedDecoration(circular: true, buttonSize: buttonSize),
            child: Center(
              child: Text(
                _getUserInitial(),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: buttonSize * 0.4,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnAmber,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pill-shaped button showing a navy initial circle, the username, and a
  /// forward arrow. [Flexible] on the username prevents overflow on narrow screens.
  Widget _buildExtendedButton(BuildContext context, double buttonSize) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProfile(context),
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            height: buttonSize,
            padding: EdgeInsets.symmetric(
              horizontal: buttonSize * 0.4,
              vertical: buttonSize * 0.15,
            ),
            decoration: _sharedDecoration(circular: false, buttonSize: buttonSize),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Navy circle with the user's initial, inset within the amber pill.
                Container(
                  width: buttonSize * 0.6,
                  height: buttonSize * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryNavyDark,
                  ),
                  child: Center(
                    child: Text(
                      _getUserInitial(),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: buttonSize * 0.3,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: buttonSize * 0.2),
                Flexible(
                  child: Text(
                    user.username,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: buttonSize * 0.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnAmber,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: buttonSize * 0.2),
                Icon(
                  Icons.arrow_forward_ios,
                  size: buttonSize * 0.3,
                  color: AppColors.textOnAmber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shared amber gradient decoration used by both button variants.
  ///
  /// [circular] switches between a full circle and a pill-shaped border radius.
  BoxDecoration _sharedDecoration({required bool circular, required double buttonSize}) {
    return BoxDecoration(
      shape: circular ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circular ? null : BorderRadius.circular(buttonSize / 2),
      gradient: LinearGradient(
        colors: [AppColors.secondaryAmber, AppColors.secondaryAmberDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: AppColors.accentGold, width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
      ],
    );
  }

  /// Returns the first character of the username, uppercased, or '?' if empty.
  String _getUserInitial() {
    return user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(user: user, onLogout: onLogout),
      ),
    );
  }
}

/// A variant of [ProfileButton] that shows a person icon instead of the
/// user's initial. Useful where a generic avatar is preferred over a
/// personalised one, such as in compact navigation bars.
class ProfileIconButton extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;
  final double? size;
  final EdgeInsetsGeometry? padding;

  const ProfileIconButton({
    super.key,
    required this.user,
    required this.onLogout,
    this.size,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? MediaQuery.of(context).size.height * 0.06;
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProfile(context),
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.secondaryAmber, AppColors.secondaryAmberDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.accentGold, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(
              Icons.person,
              size: buttonSize * 0.5,
              color: AppColors.textOnAmber,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(user: user, onLogout: onLogout),
      ),
    );
  }
}