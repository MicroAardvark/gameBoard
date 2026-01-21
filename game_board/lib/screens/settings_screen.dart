import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const SettingsScreen({
    Key? key,
    required this.user,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    final result = await AuthService.verifyToken();
    
    if (mounted) {
      setState(() {
        if (result['valid']) {
          _userData = result['user'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryAmber,
            ),
            child: Text('Logout', style: TextStyle(color: AppColors.textOnAmber)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              onLoginSuccess: (user) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      user: user,
                      onLogout: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(
                              onLoginSuccess: (newUser) {},
                            ),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.error,
          ),
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Delete', style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await AuthService.deleteAccount();
      
      if (mounted) {
        if (result['success']) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => LoginScreen(
                onLoginSuccess: (user) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        user: user,
                        onLogout: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(
                                onLoginSuccess: (newUser) {},
                              ),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Coming Soon',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          '$feature settings will be available in a future update.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.secondaryAmber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: size.height * 0.028,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.secondaryAmber,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(size.width * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theme Section
                  _SettingsSection(
                    title: 'Theme',
                    icon: Icons.palette_outlined,
                    children: [
                      _SettingsTile(
                        title: 'Appearance',
                        subtitle: 'Choose your theme',
                        icon: Icons.brightness_6,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Theme'),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Colour Scheme',
                        subtitle: 'Customise your colours',
                        icon: Icons.color_lens_outlined,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Colour scheme'),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.03),

                  // Volume Section
                  _SettingsSection(
                    title: 'Volume',
                    icon: Icons.volume_up_outlined,
                    children: [
                      _SettingsTile(
                        title: 'Master Volume',
                        subtitle: 'Adjust overall volume',
                        icon: Icons.volume_up,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Master volume'),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Sound Effects',
                        subtitle: 'Game sound effects volume',
                        icon: Icons.music_note_outlined,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Sound effects'),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Chat Notifications',
                        subtitle: 'Message notification sounds',
                        icon: Icons.notifications_outlined,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Chat notifications'),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.03),

                  // Account Section
                  _SettingsSection(
                    title: 'Account',
                    icon: Icons.person_outline,
                    children: [
                      _SettingsTile(
                        title: 'Profile',
                        subtitle: _userData?['username'] ?? widget.user.username,
                        icon: Icons.account_circle_outlined,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Profile editing available in Profile screen'),
                              backgroundColor: AppColors.secondaryAmber,
                            ),
                          );
                        },
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Email',
                        subtitle: _userData?['email'] ?? widget.user.email,
                        icon: Icons.email_outlined,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Email change'),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Password',
                        subtitle: 'Change your password',
                        icon: Icons.lock_outline,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _showComingSoonDialog('Password change'),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Bankroll',
                        subtitle: 'View your current balance',
                        icon: Icons.account_balance_wallet_outlined,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.accentGold,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: Text(
                                'Your Bankroll',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              content: Text(
                                'Current balance: £${_userData?['bankroll'] ?? widget.user.bankroll ?? 0}. Win games to increase it!',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('OK', style: TextStyle(color: AppColors.secondaryAmber)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Logout',
                        subtitle: 'Sign out of your account',
                        icon: Icons.logout,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.secondaryAmber,
                        ),
                        onTap: _handleLogout,
                        titleColor: AppColors.secondaryAmber,
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        icon: Icons.delete_forever,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.error,
                        ),
                        onTap: _handleDeleteAccount,
                        titleColor: AppColors.error,
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.03),

                  // App Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Microvark Gaming Platform',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: size.height * 0.02,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: size.height * 0.01),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: size.height * 0.018,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: size.height * 0.02),
                ],
              ),
            ),
    );
  }
}

// Section Header Widget
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: size.width * 0.02,
            bottom: size.height * 0.015,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.secondaryAmber,
                size: size.height * 0.028,
              ),
              SizedBox(width: size.width * 0.02),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: size.height * 0.024,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// Settings Tile Widget
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.height * 0.018,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: titleColor ?? AppColors.textPrimary,
                size: size.height * 0.03,
              ),
              SizedBox(width: size.width * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: size.height * 0.022,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: size.height * 0.004),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: size.height * 0.018,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}