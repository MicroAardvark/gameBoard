// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/image_upload_service.dart';
import '../theme/app_theme.dart';
import '../components/slide_in_panel.dart';
import '../components/social_panel.dart';

/// Player profile screen showing account info, bankroll, and per-game stats.
///
/// Data is refreshed from the server on init and again on pull-to-refresh so
/// the displayed bankroll and stats remain accurate after games have been
/// played. Profile image upload and deletion are handled via [ImageUploadService],
/// which stores images on the backend and returns an updated [User] model.
class ProfileScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.user, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  bool _isRefreshing    = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _refreshUserData();
  }

  void _openFriends() {
    SlideInPanel.show(
      context: context,
      child: FriendsPanel(onUpdate: _refreshUserData),
    );
  }

  Future<void> _refreshUserData() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await AuthService.getUserProfile();
      if (result['success'] && mounted) {
        setState(() => _currentUser = User.fromJson(result['user']));
      } else if (mounted) {
        _showErrorSnackBar(result['error'] ?? 'Failed to refresh profile');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Network error');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _currentUser.username);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit Username', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your new username (3-20 characters)', style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'New username',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.primaryNavyDark,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.secondaryAmber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) { Navigator.pop(context); return; }
              Navigator.pop(context, value);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryAmber),
            child: Text('Save', style: TextStyle(color: AppColors.textOnAmber)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _currentUser.username) {
      setState(() => _isRefreshing = true);
      final updateResult = await AuthService.updateUsername(result);
      if (mounted) {
        setState(() => _isRefreshing = false);
        if (updateResult['success']) {
          setState(() => _currentUser = User.fromJson(updateResult['user']));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated successfully!'), backgroundColor: Colors.green),
          );
        } else {
          _showErrorSnackBar(updateResult['error'] ?? 'Failed to update username');
        }
      }
    }
  }

  /// Asks the user to choose gallery or camera, picks the image, and uploads
  /// it to the backend. On success, updates [_currentUser] with the URL returned
  /// by the server so the avatar renders immediately without a manual refresh.
  Future<void> _uploadProfileImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Choose Image Source', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.photo_library, color: AppColors.secondaryAmber), title: Text('Gallery', style: TextStyle(color: AppColors.textPrimary)), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ListTile(leading: Icon(Icons.camera_alt,    color: AppColors.secondaryAmber), title: Text('Camera',  style: TextStyle(color: AppColors.textPrimary)), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ],
        ),
      ),
    );

    if (source == null) return;
    setState(() => _isUploadingImage = true);

    try {
      final imageFile = await ImageUploadService.pickImage(fromCamera: source == ImageSource.camera);
      if (imageFile == null) { setState(() => _isUploadingImage = false); return; }

      final result = await ImageUploadService.uploadProfileImage(imageFile);
      if (result['success'] && mounted) {
        setState(() => _currentUser = User.fromJson(result['user']));
        _showSuccessSnackBar('Profile image updated successfully');
      } else {
        _showErrorSnackBar(result['error'] ?? 'Upload failed');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload image');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _deleteProfileImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Profile Image', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
        content: Text('Are you sure you want to remove your profile image?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isUploadingImage = true);
    try {
      final result = await ImageUploadService.deleteProfileImage();
      if (result['success'] && mounted) {
        setState(() => _currentUser = User.fromJson(result['user']));
        _showSuccessSnackBar('Profile image removed');
      } else {
        _showErrorSnackBar(result['error'] ?? 'Delete failed');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete image');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error, duration: const Duration(seconds: 2)));

  void _showSuccessSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success, duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final size        = MediaQuery.of(context).size;
    final titleSize   = size.height * 0.08;
    final spacing     = size.height * 0.02;
    final cardPadding = size.height * 0.03;

    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      body: RefreshIndicator(
        color: AppColors.secondaryAmber,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshUserData,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: size.height * 0.04, horizontal: size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Player Profile',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: titleSize.clamp(24.0, 48.0),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            shadows: const [Shadow(blurRadius: 10, color: AppColors.primaryNavyDark, offset: Offset(0, 4))],
                          ),
                        ),
                      ),
                      SizedBox(height: spacing * 2),

                      _buildAccountCard(size, cardPadding),
                      SizedBox(height: spacing),

                      _buildBankrollCard(size, cardPadding),
                      SizedBox(height: spacing),

                      Text(
                        'Game Statistics',
                        style: TextStyle(fontFamily: 'Montserrat', fontSize: (titleSize * 0.6).clamp(18.0, 32.0), fontWeight: FontWeight.bold, color: AppColors.secondaryAmber),
                      ),
                      SizedBox(height: spacing),

                      Row(
                        children: [
                          Expanded(child: _buildGameStatsCard('Blackjack',    Icons.casino,  AppColors.blackjackGreen, _currentUser.stats['blackjack']   ?? {}, size, cardPadding)),
                          SizedBox(width: spacing),
                          Expanded(child: _buildGameStatsCard('Crazy Eights', Icons.style,   AppColors.unoBlue,        _currentUser.stats['CrazyEights'] ?? {}, size, cardPadding)),
                          SizedBox(width: spacing),
                          // TODO: Remove the Checkers stat card once the game and its schema entry have been deleted.
                          Expanded(child: _buildGameStatsCard('Checkers',     Icons.grid_on, AppColors.checkersDark,   _currentUser.stats['checkers']    ?? {}, size, cardPadding)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Full-screen loading overlay for refresh and image upload operations.
              if (_isRefreshing || _isUploadingImage)
                Container(
                  color: Colors.black38,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.secondaryAmber),
                          const SizedBox(height: 16),
                          Text(
                            _isUploadingImage ? 'Uploading image...' : 'Refreshing profile...',
                            style: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 16, left: 16,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 28),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primaryNavyLight, padding: const EdgeInsets.all(12)),
                ),
              ),

              Positioned(
                top: 16, right: 16,
                child: ElevatedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text('Logout', style: Theme.of(context).textTheme.bodyMedium),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: AppColors.textPrimary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
              ),

              // Friends button sits below the logout button; fixed offset rather
              // than a column so neither button's size affects the other.
              Positioned(
                top: 70, right: 16,
                child: ElevatedButton.icon(
                  onPressed: _openFriends,
                  icon: const Icon(Icons.people, size: 18),
                  label: Text('Friends', style: Theme.of(context).textTheme.bodyMedium),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentElectricBlue, foregroundColor: AppColors.textPrimary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(Size size, double padding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryAmber, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Profile image with an edit/upload overlay button.
          Stack(
            children: [
              Container(
                width: size.height * 0.12,
                height: size.height * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryAmber,
                  border: Border.all(color: AppColors.accentGold, width: 3),
                  image: _currentUser.hasProfileImage
                      ? DecorationImage(image: NetworkImage(_currentUser.profileImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: _currentUser.hasProfileImage
                    ? null
                    : Center(
                        child: Text(
                          _currentUser.username[0].toUpperCase(),
                          style: TextStyle(fontFamily: 'Montserrat', fontSize: size.height * 0.05, fontWeight: FontWeight.bold, color: AppColors.textOnAmber),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: () {
                    if (_currentUser.hasProfileImage) {
                      // Offer change or delete when an image already exists.
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text('Profile Image', style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(leading: Icon(Icons.edit, color: AppColors.secondaryAmber), title: Text('Change Image', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(context); _uploadProfileImage(); }),
                              ListTile(leading: const Icon(Icons.delete, color: Colors.red),        title: Text('Remove Image', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(context); _deleteProfileImage(); }),
                            ],
                          ),
                        ),
                      );
                    } else {
                      _uploadProfileImage();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(size.height * 0.01),
                    decoration: BoxDecoration(
                      color: AppColors.accentElectricBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryNavyDark, width: 2),
                    ),
                    child: Icon(_currentUser.hasProfileImage ? Icons.edit : Icons.add_a_photo, color: AppColors.textPrimary, size: size.height * 0.025),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: padding),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _currentUser.username,
                        style: TextStyle(fontFamily: 'Montserrat', fontSize: (size.height * 0.05).clamp(18.0, 32.0), fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: padding * 0.3),
                    InkWell(
                      onTap: _editUsername,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(padding * 0.2),
                        decoration: BoxDecoration(color: AppColors.secondaryAmber.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Icon(Icons.edit, size: (size.height * 0.025).clamp(16.0, 22.0), color: AppColors.secondaryAmber),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: padding * 0.3),
                Row(
                  children: [
                    Icon(Icons.email, size: (size.height * 0.03).clamp(14.0, 20.0), color: AppColors.textSecondary),
                    SizedBox(width: padding * 0.3),
                    Expanded(child: Text(_currentUser.email, style: TextStyle(fontFamily: 'Inter', fontSize: (size.height * 0.03).clamp(12.0, 18.0), color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                SizedBox(height: padding * 0.3),
                Row(
                  children: [
                    Icon(Icons.badge, size: (size.height * 0.03).clamp(14.0, 20.0), color: AppColors.textSecondary),
                    SizedBox(width: padding * 0.3),
                    // Truncated to 8 chars — enough to identify the account without exposing the full MongoDB ObjectId.
                    Text('Player ID: ${_currentUser.id.substring(0, 8)}...', style: TextStyle(fontFamily: 'Inter', fontSize: (size.height * 0.025).clamp(10.0, 16.0), color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankrollCard(Size size, double padding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Bankroll', style: TextStyle(fontFamily: 'Montserrat', fontSize: (size.height * 0.03).clamp(14.0, 22.0), fontWeight: FontWeight.w600, color: AppColors.textOnGold)),
              SizedBox(height: padding * 0.3),
              Text('£${_currentUser.bankroll.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Montserrat', fontSize: (size.height * 0.06).clamp(20.0, 36.0), fontWeight: FontWeight.bold, color: AppColors.primaryNavyDark)),
            ],
          ),
          Icon(Icons.account_balance_wallet, size: size.height * 0.1, color: AppColors.primaryNavyDark),
        ],
      ),
    );
  }

  Widget _buildGameStatsCard(String gameName, IconData icon, Color accentColor, Map<String, dynamic> stats, Size size, double padding) {
    final wins       = stats['wins']       ?? 0;
    final losses     = stats['losses']     ?? 0;
    final total      = stats['totalPlayed'] ?? 0;
    final winRate    = total > 0 ? ((wins / total) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(padding * 0.5),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, size: (size.height * 0.06).clamp(24.0, 40.0), color: accentColor),
          ),
          SizedBox(height: padding * 0.5),
          Text(gameName, style: TextStyle(fontFamily: 'Montserrat', fontSize: (size.height * 0.03).clamp(14.0, 20.0), fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
          SizedBox(height: padding * 0.3),
          Container(height: 2, width: double.infinity, color: accentColor.withOpacity(0.3)),
          SizedBox(height: padding * 0.5),
          _buildStatRow('Games Played', total.toString(),  size),
          SizedBox(height: padding * 0.3),
          _buildStatRow('Wins',         wins.toString(),   size, color: Colors.green),
          SizedBox(height: padding * 0.3),
          _buildStatRow('Losses',       losses.toString(), size, color: Colors.red),
          SizedBox(height: padding * 0.3),
          Container(
            padding: EdgeInsets.symmetric(horizontal: padding * 0.6, vertical: padding * 0.3),
            decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20)),
            child: Text(
              'Win Rate: $winRate%',
              style: TextStyle(fontFamily: 'Inter', fontSize: (size.height * 0.025).clamp(11.0, 16.0), fontWeight: FontWeight.bold, color: _textOnBackground(accentColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Size size, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: (size.height * 0.025).clamp(11.0, 16.0), color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontFamily: 'Montserrat', fontSize: (size.height * 0.03).clamp(12.0, 18.0), fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  /// Returns a contrasting text colour for a given background colour — used
  /// to ensure the win-rate badge remains legible across all accent colours.
  Color _textOnBackground(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? AppColors.textPrimary
        : AppColors.primaryNavyDark;
  }
}

enum ImageSource { gallery, camera }