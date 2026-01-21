// lib/components/friends_panel.dart
import 'package:flutter/material.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class FriendsPanel extends StatefulWidget {
  final VoidCallback? onUpdate;
  
  const FriendsPanel({
    super.key,
    this.onUpdate,
  });

  @override
  State<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<FriendsPanel> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  List<Map<String, dynamic>> _blockedUsers = []; // NEW
  bool _isLoading = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final friendsResult = await FriendsService.getFriends();
      final requestsResult = await FriendsService.getRequests();
      final blockedResult = await FriendsService.getBlocked(); // NEW
      
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
          _blockedUsers = blockedResult['success'] // NEW
              ? List<Map<String, dynamic>>.from(blockedResult['blocked'])
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading friends data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Remove Friend',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Remove $username from your friends list?',
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
              backgroundColor: Colors.red.shade700,
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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

  // NEW: Block user handler
  Future<void> _handleBlockUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Block User',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Block $username? This will remove them from your friends list and prevent all interactions.',
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
              backgroundColor: Colors.red.shade900,
            ),
            child: Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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

  // NEW: Unblock user handler
  Future<void> _handleUnblockUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Unblock User',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Unblock $username?',
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
              backgroundColor: AppColors.accentElectricBlue,
            ),
            child: Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
        onBlock: _handleBlockUser, // NEW: Pass block handler
      );
    }
    
    return Column(
      children: [
        // Header
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
              Icon(
                Icons.people,
                color: AppColors.textPrimary,
                size: size.height * 0.04,
              ),
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
              
              // Add Friend Button
              IconButton(
                onPressed: () => setState(() => _showSearch = true),
                icon: Icon(
                  Icons.person_add,
                  color: AppColors.textPrimary,
                  size: size.height * 0.035,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
              SizedBox(width: size.width * 0.01),
              
              // Close button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: AppColors.textPrimary,
                  size: size.height * 0.035,
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.secondaryAmber,
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.secondaryAmber,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: EdgeInsets.all(size.width * 0.03),
                    children: [
                      // Pending Requests Section
                      if (_receivedRequests.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Friend Requests',
                          count: _receivedRequests.length,
                        ),
                        ..._receivedRequests.map((request) => _RequestCard(
                          userId: request['id'],
                          username: request['username'],
                          profileImage: request['profileImage'],
                          onAccept: () => _handleAccept(request['id']),
                          onReject: () => _handleReject(request['id']),
                          onBlock: () => _handleBlockUser(request['id'], request['username']), // NEW
                        )),
                        SizedBox(height: size.height * 0.02),
                      ],
                      
                      // Sent Requests Section
                      if (_sentRequests.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Sent Requests',
                          count: _sentRequests.length,
                        ),
                        ..._sentRequests.map((request) => _SentRequestCard(
                          userId: request['id'],
                          username: request['username'],
                          profileImage: request['profileImage'],
                          onCancel: () => _handleCancelRequest(request['id']),
                        )),
                        SizedBox(height: size.height * 0.02),
                      ],
                      
                      // Friends List Section
                      _SectionHeader(
                        title: 'Friends',
                        count: _friends.length,
                      ),
                      if (_friends.isEmpty)
                        _EmptyState(
                          icon: Icons.people_outline,
                          message: 'No friends yet',
                          subtitle: 'Tap the + button to add friends',
                        )
                      else
                        ..._friends.map((friend) => _FriendCard(
                          userId: friend['id'],
                          username: friend['username'],
                          profileImage: friend['profileImage'],
                          onRemove: () => _handleRemoveFriend(
                            friend['id'],
                            friend['username'],
                          ),
                          onBlock: () => _handleBlockUser(friend['id'], friend['username']), // NEW
                        )),
                      
                      // NEW: Blocked Users Section
                      if (_blockedUsers.isNotEmpty) ...[
                        SizedBox(height: size.height * 0.02),
                        _SectionHeader(
                          title: 'Blocked Users',
                          count: _blockedUsers.length,
                          color: Colors.red.shade700,
                        ),
                        ..._blockedUsers.map((blocked) => _BlockedUserCard(
                          userId: blocked['id'],
                          username: blocked['username'],
                          profileImage: blocked['profileImage'],
                          onUnblock: () => _handleUnblockUser(
                            blocked['id'],
                            blocked['username'],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _FriendSearchPanel extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String, String) onBlock; // NEW
  
  const _FriendSearchPanel({
    required this.onBack,
    required this.onBlock, // NEW
  });

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

      if (!result['success']) {
        _showSnackBar(result['error'], AppColors.error);
      }
    }
  }

  Future<void> _sendRequest(String userId, String username) async {
    final result = await FriendsService.sendRequest(userId);

    if (result['success']) {
      _showSnackBar('Friend request sent to $username', Colors.green);
      _search(); // Refresh results
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
        // Header
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
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: size.height * 0.035,
                ),
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
        
        // Search Bar
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
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSearching
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnAmber,
                        ),
                      )
                    : Icon(
                        Icons.search,
                        color: AppColors.textOnAmber,
                      ),
              ),
            ],
          ),
        ),
        
        // Results
        Expanded(
          child: _hasSearched
              ? _searchResults.isEmpty
                  ? _EmptyState(
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
                          isBlocked: user['isBlocked'] ?? false, // NEW
                          onSendRequest: () => _sendRequest(
                            user['id'],
                            user['username'],
                          ),
                          onBlock: () => widget.onBlock(user['id'], user['username']), // NEW
                        );
                      },
                    )
              : _EmptyState(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;
  
  const _SectionHeader({
    required this.title,
    required this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: size.height * 0.01,
        top: size.height * 0.01,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: size.height * 0.025,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.secondaryAmber,
            ),
          ),
          SizedBox(width: size.width * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.02,
              vertical: size.height * 0.005,
            ),
            decoration: BoxDecoration(
              color: color ?? AppColors.secondaryAmber,
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

class _FriendCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final VoidCallback onRemove;
  final VoidCallback onBlock; // NEW
  
  const _FriendCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onRemove,
    required this.onBlock, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: CircleAvatar(
          radius: size.height * 0.03,
          backgroundImage: profileImage != null 
              ? NetworkImage(profileImage!)
              : null,
          backgroundColor: AppColors.secondaryAmber,
          child: profileImage == null
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textOnAmber,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          username,
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NEW: Block button
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

class _RequestCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onBlock; // NEW
  
  const _RequestCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onAccept,
    required this.onReject,
    required this.onBlock, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: size.height * 0.01),
      child: ListTile(
        leading: CircleAvatar(
          radius: size.height * 0.03,
          backgroundImage: profileImage != null 
              ? NetworkImage(profileImage!)
              : null,
          backgroundColor: AppColors.secondaryAmber,
          child: profileImage == null
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textOnAmber,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          username,
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NEW: Block button
            IconButton(
              icon: Icon(Icons.block, color: Colors.red.shade900),
              onPressed: onBlock,
            ),
            IconButton(
              icon: Icon(Icons.check, color: Colors.green),
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
        leading: CircleAvatar(
          radius: size.height * 0.03,
          backgroundImage: profileImage != null 
              ? NetworkImage(profileImage!)
              : null,
          backgroundColor: AppColors.secondaryAmber,
          child: profileImage == null
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textOnAmber,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          username,
          style: TextStyle(
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
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.orange),
          ),
        ),
      ),
    );
  }
}

// NEW: Blocked user card
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
        leading: CircleAvatar(
          radius: size.height * 0.03,
          backgroundImage: profileImage != null 
              ? NetworkImage(profileImage!)
              : null,
          backgroundColor: Colors.red.shade700,
          child: profileImage == null
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          username,
          style: TextStyle(
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
          child: Text('Unblock'),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final bool isFriend;
  final bool hasRequestFrom;
  final bool hasSentRequestTo;
  final bool isBlocked; // NEW
  final VoidCallback onSendRequest;
  final VoidCallback onBlock; // NEW
  
  const _SearchResultCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.isFriend,
    required this.hasRequestFrom,
    required this.hasSentRequestTo,
    required this.isBlocked, // NEW
    required this.onSendRequest,
    required this.onBlock, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    String statusText = '';
    Color? statusColor;
    bool canSendRequest = true;
    bool showBlockButton = true; // NEW
    
    if (isBlocked) { // NEW
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
        leading: CircleAvatar(
          radius: size.height * 0.03,
          backgroundImage: profileImage != null 
              ? NetworkImage(profileImage!)
              : null,
          backgroundColor: isBlocked ? Colors.red.shade700 : AppColors.secondaryAmber,
          child: profileImage == null
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: isBlocked ? AppColors.textPrimary : AppColors.textOnAmber,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          username,
          style: TextStyle(
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
            // NEW: Block button (show for non-blocked users)
            if (showBlockButton)
              IconButton(
                icon: Icon(Icons.block, color: Colors.red.shade700),
                onPressed: onBlock,
              ),
            // Add friend button (show if can send request)
            if (canSendRequest)
              IconButton(
                icon: Icon(Icons.person_add, color: AppColors.accentElectricBlue),
                onPressed: onSendRequest,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  
  const _EmptyState({
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: size.height * 0.1,
              color: AppColors.textSecondary,
            ),
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