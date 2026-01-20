// lib/components/friends_panel.dart
import 'package:flutter/material.dart';
import '../services/friends_service.dart';
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
                        )),
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
  
  const _FriendSearchPanel({required this.onBack});

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
                          onSendRequest: () => _sendRequest(
                            user['id'],
                            user['username'],
                          ),
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
  
  const _SectionHeader({
    required this.title,
    required this.count,
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
              color: AppColors.secondaryAmber,
            ),
          ),
          SizedBox(width: size.width * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.02,
              vertical: size.height * 0.005,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondaryAmber,
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
  
  const _FriendCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onRemove,
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
        trailing: IconButton(
          icon: Icon(Icons.person_remove, color: Colors.red.shade400),
          onPressed: onRemove,
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
  
  const _RequestCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.onAccept,
    required this.onReject,
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

class _SearchResultCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? profileImage;
  final bool isFriend;
  final bool hasRequestFrom;
  final bool hasSentRequestTo;
  final VoidCallback onSendRequest;
  
  const _SearchResultCard({
    required this.userId,
    required this.username,
    this.profileImage,
    required this.isFriend,
    required this.hasRequestFrom,
    required this.hasSentRequestTo,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    String statusText = '';
    Color? statusColor;
    bool canSendRequest = true;
    
    if (isFriend) {
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
        trailing: canSendRequest
            ? IconButton(
                icon: Icon(Icons.person_add, color: AppColors.accentElectricBlue),
                onPressed: onSendRequest,
              )
            : null,
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