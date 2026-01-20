// lib/components/profile_button.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

/// Reusable profile button component that navigates to the profile screen
/// Can be used across multiple screens in the application
class ProfileButton extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;
  final double? size;
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
    final screenSize = MediaQuery.of(context).size;
    final buttonSize = size ?? screenSize.height * 0.06;
    
    if (showUsername) {
      // Extended button with username
      return _buildExtendedButton(context, buttonSize);
    } else {
      // Compact circular button
      return _buildCompactButton(context, buttonSize);
    }
  }

  Widget _buildCompactButton(BuildContext context, double buttonSize) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(0),
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
                colors: [
                  AppColors.secondaryAmber,
                  AppColors.secondaryAmberDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.accentGold,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
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

  Widget _buildExtendedButton(BuildContext context, double buttonSize) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(0),
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(buttonSize / 2),
              gradient: LinearGradient(
                colors: [
                  AppColors.secondaryAmber,
                  AppColors.secondaryAmberDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.accentGold,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User Initial Circle
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
                // Username
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
                // Arrow icon
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

  String _getUserInitial() {
    return user.username.isNotEmpty 
        ? user.username[0].toUpperCase() 
        : '?';
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          user: user,
          onLogout: onLogout,
        ),
      ),
    );
  }
}

/// Alternative profile button with icon instead of initial
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
    final screenSize = MediaQuery.of(context).size;
    final buttonSize = size ?? screenSize.height * 0.06;
    
    return Padding(
      padding: padding ?? const EdgeInsets.all(0),
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
                colors: [
                  AppColors.secondaryAmber,
                  AppColors.secondaryAmberDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.accentGold,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
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
        builder: (context) => ProfileScreen(
          user: user,
          onLogout: onLogout,
        ),
      ),
    );
  }
}