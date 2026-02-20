// lib/components/friends_panel.dart
import 'package:flutter/material.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

/// Slide-in panel displaying a user's friends list, pending requests,
/// sent requests, and blocked users.
///
/// Switches to [_FriendSearchPanel] when the add-friend button is tapped,
/// then reloads data and notifies [onUpdate] on return.
class FriendsPanel extends StatefulWidget {
  /// Called after any action that changes the friends list so parent widgets
  /// (e.g. a lobby screen showing online friends) can refresh their state.
  final VoidCallback? onUpdate;

  const FriendsPanel({super.key, this.onUpdate});

  @override
  State<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<FriendsPanel> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Fetches friends, pending requests, and blocked users in parallel,
  /// then rebuilds the list. Silently degrades to empty lists on failure
  /// so the panel remains usable even if one endpoint is unavailable.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final friendsResult  = await FriendsService.getFriends();
      final requestsResult = await FriendsService.getRequests();
      final blockedResult  = await FriendsService.getBlocked();

      if (mounted) {
        setState(() {
          _friends = friendsResult['success']
              ? List<Map<String, dynamic>>.from(friendsResult['friends'])
              : [];
          _receivedRequests = requestsResult['success']
              ? List<Map<String, dynamic>>.from(requestsResult['received'])
              : [];
          _sentRequests = requestsResult['success']
              ? List<Map<String, dynamic>>.from(requestsResult['sent'])
              : [];
          _blockedUsers = blockedResult['success']
              ? List<Map<String, dynamic>>.from(blockedResult['blocked'])
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccept(String userId) async {
    final result = await FriendsService.acceptRequest(userId);
    if (result['success']) {
      _showSnackBar('Friend request accepted', Colors.green);
      _loadData();
      widget.onUpdate?.call();
    } else {
      _showSnackBar(result['error'], AppColors.error);
    }
  }

  Future<void> _handleReject(String userId) async {
    final result = await FriendsService.rejectRequest(userId);
    if (result['success']) {
      _showSnackBar('Friend request rejected', Colors.orange);
      _loadData();
    } else {
      _showSnackBar(result['error'], AppColors.error);
    }
  }

  Future<void> _handleRemoveFriend(String userId, String username) async {
    final confirmed = await _showConfirmDialog(
      title: 'Remove Friend',
      content: 'Remove $username from your friends list?',
      confirmLabel: 'Remove',
      confirmColor: Colors.red.shade700,
    );

    if (confirmed) {
      final result = await FriendsService.removeFriend(userId);
      if (result['success']) {
        _showSnackBar('Friend removed', Colors.orange);
        _loadData();
        widget.onUpdate?.call();
      } else {
        _showSnackBar(result['error'], AppColors.error);
      }
    }
  }

  Future<void> _handleCancelRequest(String userId) async {
    final result = await FriendsService.cancelRequest(userId);
    if (result['success']) {
      _showSnackBar('Request cancelled', Colors.orange);
      _loadData();
    } else {
      _showSnackBar(result['error'], AppColors.error);
    }
  }

  /// Blocking also removes the user from the friends list server-side,
  /// so [onUpdate] is called to let the parent refresh any friend-dependent UI.
  Future<void> _handleBlockUser(String userId, String username) async {
    final confirmed = await _showConfirmDialog(
      title: 'Block User',
      content:
          'Block $username? This will remove them from your friends list and prevent all interactions.',
      confirmLabel: 'Block',
      confirmColor: Colors.red.shade900,
    );

    if (confirmed) {
      final result = await FriendsService.blockUser(userId);
      if (result['success']) {
        _showSnackBar('User blocked', Colors.red.shade700);
        _loadData();
        widget.onUpdate?.call();
      } else {
        _showSnackBar(result['error'], AppColors.error);
      }
    }
  }

  Future<void> _handleUnblockUser(String userId, String username) async {
    final confirmed = await _showConfirmDialog(
      title: 'Unblock User',
      content: 'Unblock $username?',
      confirmLabel: 'Unblock',
      confirmColor: AppColors.accentElectricBlue,
    );

    if (confirmed) {
      final result = await FriendsService.unblockUser(userId);
      if (result['success']) {
        _showSnackBar('User unblocked', Colors.green);
        _loadData();
        widget.onUpdate?.call();
      } else {
        _showSnackBar(result['error'], AppColors.error);
      }
    }
  }

  /// Shared confirmation dialog for destructive actions (remove, block, unblock).
  ///
  /// Extracted to avoid duplicating the same [AlertDialog] structure across
  /// every handler — only the title, content, and button styling differ.
  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: AppColors.textPrimary,
              ),
            ),
            content: Text(
              content,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_showSearch) {
      return _FriendSearchPanel(
        onBack: () {
          setState(() => _showSearch = false);
          _loadData();
          widget.onUpdate?.call();
        },
        onBlock: _handleBlockUser,
      );
    }

    return Column(
      children: [
        _buildHeader(context, size),
        Expanded(child: _buildContent(context, size)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Size size) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentElectricBlue,
            AppColors.accentElectricBlueDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.people, color: AppColors.textPrimary, size: size.height * 0.04),
          SizedBox(width: size.width * 0.02),
          Expanded(
            child: Text(
              'Friends',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: size.height * 0.03,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showSearch = true),
            icon: Icon(Icons.person_add,
                color: AppColors.textPrimary, size: size.height * 0.035),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
          SizedBox(width: size.width * 0.01),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close,
                color: AppColors.textPrimary, size: size.height * 0.035),
          ),
        ],
      ),
    );
  }

  /// Builds the scrollable list, showing a spinner while data loads and a
  /// pull-to-refresh indicator once loaded.
  Widget _buildContent(BuildContext context, Size size) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.secondaryAmber));
    }

    return RefreshIndicator(
      color: AppColors.secondaryAmber,
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.all(size.width * 0.03),
        children: [
          if (_receivedRequests.isNotEmpty) ...[
            _SectionHeader(title: 'Friend Requests', count: _receivedRequests.length),
            ..._receivedRequests.map((r) => _RequestCard(
                  userId: r['id'],
                  username: r['username'],
                  profileImage: r['profileImage'],
                  onAccept: () => _handleAccept(r['id']),
                  onReject: () => _handleReject(r['id']),
                  onBlock: () => _handleBlockUser(r['id'], r['username']),
                )),
            SizedBox(height: size.height * 0.02),
          ],

          if (_sentRequests.isNotEmpty) ...[
            _SectionHeader(title: 'Sent Requests', count: _sentRequests.length),
            ..._sentRequests.map((r) => _SentRequestCard(
                  userId: r['id'],
                  username: r['username'],
                  profileImage: r['profileImage'],
                  onCancel: () => _handleCancelRequest(r['id']),
                )),
            SizedBox(height: size.height * 0.02),
          ],

          _SectionHeader(title: 'Friends', count: _friends.length),
          if (_friends.isEmpty)
            const _EmptyState(
              icon: Icons.people_outline,
              message: 'No friends yet',
              subtitle: 'Tap the + button to add friends',
            )
          else
            ..._friends.map((f) => _FriendCard(
                  userId: f['id'],
                  username: f['username'],
                  profileImage: f['profileImage'],
                  onRemove: () => _handleRemoveFriend(f['id'], f['username']),
                  onBlock: () => _handleBlockUser(f['id'], f['username']),
                )),

          if (_blockedUsers.isNotEmpty) ...[
            SizedBox(height: size.height * 0.02),
            _SectionHeader(
              title: 'Blocked Users',
              count: _blockedUsers.length,
              color: Colors.red.shade700,
            ),
            ..._blockedUsers.map((b) => _BlockedUserCard(
                  userId: b['id'],
                  username: b['username'],
                  profileImage: b['profileImage'],
                  onUnblock: () => _handleUnblockUser(b['id'], b['username']),
                )),
          ],
        ],
      ),
    );
  }
}

/// Search panel for finding and adding new friends.
///
/// Requires at least two characters before searching to reduce noise from
/// partial-name queries returning large result sets.
class _FriendSearchPanel extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String userId, String username) onBlock;

  const _FriendSearchPanel({required this.onBack, required this.onBlock});

  @override
  State<_FriendSearchPanel> createState() => _FriendSearchPanelState();
}

class _FriendSearchPanelState extends State<_FriendSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      _showSnackBar('Enter at least 2 characters', AppColors.error);
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final result = await FriendsService.searchUsers(query);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchResults = result['success']
            ? List<Map<String, dynamic>>.from(result['users'])
            : [];
      });
      if (!result['success']) _showSnackBar(result['error'], AppColors.error);
    }
  }

  Future<void> _sendRequest(String userId, String username) async {
    final result = await FriendsService.sendRequest(userId);
    if (result['success']) {
      _showSnackBar('Friend request sent to $username', Colors.green);
      _search(); // Refresh so the card status updates immediately.
    } else {
      _showSnackBar(result['error'], AppColors.error);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // Header with back navigation.
        Container(
          padding: EdgeInsets.all(size.width * 0.04),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentElectricBlue,
                AppColors.accentElectricBlueDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back,
                    color: AppColors.textPrimary, size: size.height * 0.035),
              ),
              Expanded(
                child: Text(
                  'Add Friend',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: size.height * 0.03,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search input. Submitting via keyboard triggers the same search as the button.
        Container(
          padding: EdgeInsets.all(size.width * 0.04),
          color: AppColors.primaryNavy,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search username...',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              SizedBox(width: size.width * 0.02),
              ElevatedButton(
                onPressed: _isSearching ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryAmber,
                  padding: EdgeInsets.all(size.width * 0.03),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                // Spinner replaces the icon while a request is in flight.
                child: _isSearching
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textOnAmber),
                      )
                    : Icon(Icons.search, color: AppColors.textOnAmber),
              ),
            ],
          ),
        ),

        Expanded(
          child: _hasSearched
              ? _searchResults.isEmpty
                  ? const _EmptyState(
                      icon: Icons.person_search,
                      message: 'No users found',
                      subtitle: 'Try a different username',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(size.width * 0.03),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return _SearchResultCard(
                          userId: user['id'],
                          username: user['username'],
                          profileImage: user['profileImage'],
                          isFriend: user['isFriend'] ?? false,
                          hasRequestFrom: user['hasRequestFrom'] ?? false,
                          hasSentRequestTo: user['hasSentRequestTo'] ?? false,
                          isBlocked: user['isBlocked'] ?? false,
                          onSendRequest: () =>
                              _sendRequest(user['id'], user['username']),
                          onBlock: () =>
                              widget.onBlock(user['id'], user['username']),
                        );
                      },
                    )
              : const _EmptyState(
                  icon: Icons.person_add,
                  message: 'Search for friends',
                  subtitle: 'Enter a username to get started',
                ),
        ),
      ],
    );
  }
}

// Helper Widgets

// ─── Section header ───────────────────────────────────────────────────────────

/// Bold section label with a pill-shaped count badge.
///
/// [color] defaults to amber; pass a custom colour for sections like
/// "Blocked Users" that warrant a distinct visual treatment.
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;

  const _SectionHeader({required this.title, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tint = color ?? AppColors.secondaryAmber;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: size.height * 0.025,
              fontWeight: FontWeight.bold,
              color: tint,
            ),
          ),
          SizedBox(width: size.width * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.02,
              vertical: size.height * 0.005,
            ),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: size.height * 0.02,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar helper ────────────────────────────────────────────────────────────

/// Shared avatar used by every card variant.
///
/// Shows the profile image when available, or falls back to the first letter
/// of [username] on a coloured background.
class _UserAvatar extends StatelessWidget {
  final String username;
  final String? profileImage;
  final Color backgroundColor;
  final Color textColor;

  const _UserAvatar({
    required this.username,
    this.profileImage,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return CircleAvatar(
      radius: size.height * 0.03,
      backgroundImage:
          profileImage != null ? NetworkImage(profileImage!) : null,
      backgroundColor: backgroundColor,
      child: profileImage == null
          ? Text(
              username[0].toUpperCase(),
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

// ─── Card widgets ─────────────────────────────────────────────────────────────

/// Displays a confirmed friend with remove and block actions.
class _FriendCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  const _FriendCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onRemove,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: _UserAvatar(
          username: username,
          profileImage: profileImage,
          backgroundColor: AppColors.secondaryAmber,
          textColor: AppColors.textOnAmber,
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Block is darker red than remove to signal a more severe action.
            IconButton(
              icon: Icon(Icons.block, color: Colors.red.shade700),
              onPressed: onBlock,
            ),
            IconButton(
              icon: Icon(Icons.person_remove, color: Colors.red.shade400),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays an incoming friend request with accept, reject, and block actions.
class _RequestCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onBlock;

  const _RequestCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onAccept,
    required this.onReject,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: _UserAvatar(
          username: username,
          profileImage: profileImage,
          backgroundColor: AppColors.secondaryAmber,
          textColor: AppColors.textOnAmber,
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.block, color: Colors.red.shade900),
              onPressed: onBlock,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: onAccept,
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade400),
              onPressed: onReject,
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays an outgoing friend request that is awaiting a response.
class _SentRequestCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final VoidCallback onCancel;

  const _SentRequestCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: _UserAvatar(
          username: username,
          profileImage: profileImage,
          backgroundColor: AppColors.secondaryAmber,
          textColor: AppColors.textOnAmber,
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Pending',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textSecondary,
            fontSize: size.height * 0.018,
          ),
        ),
        trailing: TextButton(
          onPressed: onCancel,
          child: const Text('Cancel', style: TextStyle(color: Colors.orange)),
        ),
      ),
    );
  }
}

/// Displays a blocked user with an unblock action.
///
/// The red avatar background visually distinguishes blocked entries from
/// the rest of the list without relying solely on the "Blocked" label.
class _BlockedUserCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final VoidCallback onUnblock;

  const _BlockedUserCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: _UserAvatar(
          username: username,
          profileImage: profileImage,
          backgroundColor: Colors.red.shade700,
          textColor: AppColors.textPrimary,
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Blocked',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.red.shade700,
            fontSize: size.height * 0.018,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: onUnblock,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentElectricBlue,
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.03,
              vertical: size.height * 0.01,
            ),
          ),
          child: const Text('Unblock'),
        ),
      ),
    );
  }
}

/// Displays a user search result with contextual action buttons.
///
/// The available actions adapt to the current relationship state:
/// friends, pending requests, and blocked users each get a different
/// subset of buttons so users can't perform contradictory actions.
class _SearchResultCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final bool isFriend;
  final bool hasRequestFrom;
  final bool hasSentRequestTo;
  final bool isBlocked;
  final VoidCallback onSendRequest;
  final VoidCallback onBlock;

  const _SearchResultCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.isFriend,
    required this.hasRequestFrom,
    required this.hasSentRequestTo,
    required this.isBlocked,
    required this.onSendRequest,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Derive display state from relationship flags. Blocked takes priority
    // over all others since a blocked user shouldn't be interactable.
    String statusText = '';
    Color? statusColor;
    bool canSendRequest = true;
    bool showBlockButton = true;

    if (isBlocked) {
      statusText = 'Blocked';
      statusColor = Colors.red.shade700;
      canSendRequest = false;
      showBlockButton = false;
    } else if (isFriend) {
      statusText = 'Friends';
      statusColor = Colors.green;
      canSendRequest = false;
    } else if (hasRequestFrom) {
      statusText = 'Wants to be friends';
      statusColor = AppColors.secondaryAmber;
      canSendRequest = false;
    } else if (hasSentRequestTo) {
      statusText = 'Request sent';
      statusColor = Colors.orange;
      canSendRequest = false;
    }

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: _UserAvatar(
          username: username,
          profileImage: profileImage,
          backgroundColor:
              isBlocked ? Colors.red.shade700 : AppColors.secondaryAmber,
          textColor:
              isBlocked ? AppColors.textPrimary : AppColors.textOnAmber,
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: statusText.isNotEmpty
            ? Text(
                statusText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: statusColor,
                  fontSize: size.height * 0.018,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBlockButton)
              IconButton(
                icon: Icon(Icons.block, color: Colors.red.shade700),
                onPressed: onBlock,
              ),
            if (canSendRequest)
              IconButton(
                icon: Icon(Icons.person_add,
                    color: AppColors.accentElectricBlue),
                onPressed: onSendRequest,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

/// Generic empty state used across list sections when there is no data to show.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const _EmptyState({required this.icon, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: size.height * 0.1, color: AppColors.textSecondary),
            SizedBox(height: size.height * 0.02),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: size.height * 0.025,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: size.height * 0.01),
              Text(
                subtitle!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size.height * 0.02,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}