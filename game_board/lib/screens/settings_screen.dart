// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Application settings screen.
///
/// Covers three sections: Theme (placeholder), Volume (placeholder), and
/// Account (profile navigation, password change, logout, and account deletion).
/// Theme and volume settings are stubbed with a "coming soon" dialog while
/// they await implementation.
///
/// Account deletion and logout both navigate to [LoginScreen] via
/// [pushAndRemoveUntil] to fully clear the navigation stack so the user
/// cannot swipe back to authenticated content.
class SettingsScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const SettingsScreen({Key? key, required this.user, required this.onLogout}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Fresh server-side user data fetched on init; used to show live values for
  /// username, email, and bankroll rather than potentially stale widget props.
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
        if (result['success']) _userData = result['user'];
        _isLoading = false;
      });
    }
  }

  /// Confirms intent then signs out, clearing the nav stack back to [LoginScreen].
  Future<void> _handleLogout() async {
    final confirm = await _showConfirmDialog(
      title: 'Logout',
      content: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      confirmColor: AppColors.secondaryAmber,
      confirmTextColor: AppColors.textOnAmber,
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) _pushToLogin();
    }
  }

  /// Confirms intent (with stronger warning about permanence) then deletes
  /// the account and clears the navigation stack.
  Future<void> _handleDeleteAccount() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Account',
      content: 'This action cannot be undone. All your data will be permanently deleted.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.error,
      confirmTextColor: AppColors.textPrimary,
      titleColor: AppColors.error,
    );

    if (confirm == true) {
      final result = await AuthService.deleteAccount();
      if (mounted) {
        if (result['success']) {
          _pushToLogin();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error']), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  /// Navigates to [LoginScreen] and removes all existing routes from the stack
  /// so the user cannot navigate back to authenticated screens.
  void _pushToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: (user) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  user: user,
                  onLogout: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => LoginScreen(onLoginSuccess: (_) {})),
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

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Coming Soon', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
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

  /// Generic confirmation dialog shared by logout and delete-account flows.
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    required Color confirmTextColor,
    Color? titleColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: TextStyle(fontFamily: 'Montserrat', color: titleColor ?? AppColors.textPrimary),
        ),
        content: Text(content, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel, style: TextStyle(color: confirmTextColor)),
          ),
        ],
      ),
    );
  }

  /// Password change dialog with inline client-side validation.
  ///
  /// Validation runs entirely within a [StatefulBuilder] so error messages
  /// can update without rebuilding the whole screen. The API call is made
  /// only if the dialog returns `true`.
  Future<void> _handleChangePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController     = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool  obscureCurrent  = true;
    bool  obscureNew      = true;
    bool  obscureConfirm  = true;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Change Password', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(errorMessage!, style: const TextStyle(fontFamily: 'Inter', color: Colors.red, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildPasswordField('Current Password',    currentPasswordController, obscureCurrent,  () => setDialogState(() => obscureCurrent  = !obscureCurrent)),
                const SizedBox(height: 16),
                _buildPasswordField('New Password',        newPasswordController,     obscureNew,      () => setDialogState(() => obscureNew      = !obscureNew),      hint: 'Enter new password (min. 6 characters)'),
                const SizedBox(height: 16),
                _buildPasswordField('Confirm New Password', confirmPasswordController, obscureConfirm, () => setDialogState(() => obscureConfirm  = !obscureConfirm),  hint: 'Re-enter new password'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final current = currentPasswordController.text;
                final newPass = newPasswordController.text;
                final confirm = confirmPasswordController.text;

                if (current.isEmpty)          { setDialogState(() => errorMessage = 'Please enter your current password'); return; }
                if (newPass.isEmpty)           { setDialogState(() => errorMessage = 'Please enter a new password'); return; }
                if (newPass.length < 6)        { setDialogState(() => errorMessage = 'Password must be at least 6 characters'); return; }
                if (newPass != confirm)        { setDialogState(() => errorMessage = 'Passwords do not match'); return; }
                if (current == newPass)        { setDialogState(() => errorMessage = 'New password must be different from current password'); return; }

                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryAmber),
              child: Text('Change Password', style: TextStyle(color: AppColors.textOnAmber)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      final changeResult = await AuthService.changePassword(
        currentPassword: currentPasswordController.text,
        newPassword:     newPasswordController.text,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changeResult['success'] ? 'Password changed successfully!' : changeResult['error'] ?? 'Failed to change password'),
            backgroundColor: changeResult['success'] ? Colors.green : AppColors.error,
          ),
        );
      }
    }
  }

  /// Helper to build a consistent password [TextField] with visibility toggle.
  Widget _buildPasswordField(String label, TextEditingController controller, bool obscure, VoidCallback onToggle, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.primaryNavyDark,
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.secondaryAmber)),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
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
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(fontFamily: 'Montserrat', fontSize: size.height * 0.028, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.secondaryAmber))
          : SingleChildScrollView(
              padding: EdgeInsets.all(size.width * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSection(
                    title: 'Theme',
                    icon: Icons.palette_outlined,
                    children: [
                      _SettingsTile(title: 'Appearance',   subtitle: 'Choose your theme',      icon: Icons.brightness_6,      trailing: _chevron(), onTap: () => _showComingSoonDialog('Theme')),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Colour Scheme', subtitle: 'Customise your colours', icon: Icons.color_lens_outlined, trailing: _chevron(), onTap: () => _showComingSoonDialog('Colour scheme')),
                    ],
                  ),
                  SizedBox(height: size.height * 0.03),

                  _SettingsSection(
                    title: 'Volume',
                    icon: Icons.volume_up_outlined,
                    children: [
                      _SettingsTile(title: 'Master Volume',      subtitle: 'Adjust overall volume',        icon: Icons.volume_up,             trailing: _chevron(), onTap: () => _showComingSoonDialog('Master volume')),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Sound Effects',      subtitle: 'Game sound effects volume',    icon: Icons.music_note_outlined,    trailing: _chevron(), onTap: () => _showComingSoonDialog('Sound effects')),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Chat Notifications', subtitle: 'Message notification sounds',  icon: Icons.notifications_outlined, trailing: _chevron(), onTap: () => _showComingSoonDialog('Chat notifications')),
                    ],
                  ),
                  SizedBox(height: size.height * 0.03),

                  _SettingsSection(
                    title: 'Account',
                    icon: Icons.person_outline,
                    children: [
                      _SettingsTile(
                        title: 'Profile',
                        subtitle: _userData?['username'] ?? widget.user.username,
                        icon: Icons.account_circle_outlined,
                        trailing: _chevron(),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.user, onLogout: widget.onLogout))),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Email',    subtitle: _userData?['email'] ?? widget.user.email, icon: Icons.email_outlined, trailing: _chevron(), onTap: () => _showComingSoonDialog('Email change')),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Password', subtitle: 'Change your password',     icon: Icons.lock_outline,                    trailing: _chevron(), onTap: _handleChangePassword),
                      Divider(color: AppColors.border, height: 1),
                      // Shows current bankroll from server-verified data rather than
                      // widget.user which may be stale if the user has played since login.
                      _SettingsTile(
                        title: 'Bankroll',
                        subtitle: 'View your current balance',
                        icon: Icons.account_balance_wallet_outlined,
                        trailing: Icon(Icons.chevron_right, color: AppColors.accentGold),
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            title: Text('Your Bankroll', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
                            content: Text(
                              'Current balance: £${_userData?['bankroll'] ?? widget.user.bankroll ?? 0}. Win games to increase it!',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: AppColors.secondaryAmber)))],
                          ),
                        ),
                      ),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Logout',         subtitle: 'Sign out of your account',          icon: Icons.logout,         trailing: Icon(Icons.chevron_right, color: AppColors.secondaryAmber), onTap: _handleLogout,         titleColor: AppColors.secondaryAmber),
                      Divider(color: AppColors.border, height: 1),
                      _SettingsTile(title: 'Delete Account', subtitle: 'Permanently delete your account',   icon: Icons.delete_forever, trailing: Icon(Icons.chevron_right, color: AppColors.error),          onTap: _handleDeleteAccount,   titleColor: AppColors.error),
                    ],
                  ),

                  SizedBox(height: size.height * 0.03),
                  Center(
                    child: Column(
                      children: [
                        Text('Microvark Gaming Platform', style: TextStyle(fontFamily: 'Montserrat', fontSize: size.height * 0.02, color: AppColors.textSecondary)),
                        SizedBox(height: size.height * 0.01),
                        Text('Version 1.0.0', style: TextStyle(fontFamily: 'Inter', fontSize: size.height * 0.018, color: AppColors.textSecondary.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                ],
              ),
            ),
    );
  }

  Icon _chevron() => Icon(Icons.chevron_right, color: AppColors.textSecondary);
}

/// A labelled group of [_SettingsTile]s with a section header and card background.
class _SettingsSection extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: size.width * 0.02, bottom: size.height * 0.015),
          child: Row(
            children: [
              Icon(icon, color: AppColors.secondaryAmber, size: size.height * 0.028),
              SizedBox(width: size.width * 0.02),
              Text(title, style: TextStyle(fontFamily: 'Montserrat', fontSize: size.height * 0.024, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// Individual tappable row inside a [_SettingsSection].
class _SettingsTile extends StatelessWidget {
  final String       title;
  final String       subtitle;
  final IconData     icon;
  final Widget?      trailing;
  final VoidCallback onTap;
  final Color?       titleColor;

  const _SettingsTile({required this.title, required this.subtitle, required this.icon, this.trailing, required this.onTap, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.018),
          child: Row(
            children: [
              Icon(icon, color: titleColor ?? AppColors.textPrimary, size: size.height * 0.03),
              SizedBox(width: size.width * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,    style: TextStyle(fontFamily: 'Inter', fontSize: size.height * 0.022, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary)),
                    SizedBox(height: size.height * 0.004),
                    Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: size.height * 0.018, color: AppColors.textSecondary)),
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