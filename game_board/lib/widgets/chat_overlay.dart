// lib/widgets/chat_overlay.dart
// COMPLETE: Voice chat controls + Social features (block/report/friend)
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/voice_chat_service.dart';
import '../services/social_service.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatOverlay extends StatefulWidget {
  final String roomId;
  final String userId;
  final String username;
  final SocketService socketService;
  final VoiceChatService voiceService;  // NEW: Voice service
  final VoidCallback onClose;

  const ChatOverlay({
    super.key,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.socketService,
    required this.voiceService,  // NEW
    required this.onClose,
  });

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _typingUsers = {};
  
  Timer? _typingTimer;
  bool _isTyping = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  late StreamSubscription _chatMessageSub;
  late StreamSubscription _chatHistorySub;
  late StreamSubscription _typingSub;
  StreamSubscription? _voiceParticipantsSub;  // NEW

  @override
  void initState() {
    super.initState();
    
    // Slide animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _setupListeners();
    _loadChatHistory();
    _animationController.forward();
  }

  void _setupListeners() {
    _chatMessageSub = widget.socketService.onChatMessage.listen((data) {
      final message = ChatMessage.fromJson(data);
      setState(() {
        _messages.add(message);
        _typingUsers.remove(message.username);
      });
      _scrollToBottom();
    });

    _chatHistorySub = widget.socketService.onChatHistory.listen((data) {
      final List<dynamic> messagesJson = data['messages'] ?? [];
      setState(() {
        _messages.clear();
        _messages.addAll(
          messagesJson.map((json) => ChatMessage.fromJson(json)).toList()
        );
      });
      _scrollToBottom();
    });

    _typingSub = widget.socketService.onUserTyping.listen((data) {
      final username = data['username'];
      final isTyping = data['isTyping'] ?? false;
      
      if (username != widget.username) {
        setState(() {
          if (isTyping) {
            _typingUsers.add(username);
          } else {
            _typingUsers.remove(username);
          }
        });
      }
    });

    // NEW: Voice participants listener
    _voiceParticipantsSub = widget.voiceService.participantsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _loadChatHistory() {
    widget.socketService.getChatHistory(
      roomId: widget.roomId,
      limit: 50,
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    widget.socketService.sendMessage(
      roomId: widget.roomId,
      userId: widget.userId,
      message: message,
    );

    _messageController.clear();
    _onStoppedTyping();
  }

  void _onTyping() {
    if (!_isTyping) {
      _isTyping = true;
      widget.socketService.sendTypingStart(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _onStoppedTyping);
  }

  void _onStoppedTyping() {
    if (_isTyping) {
      _isTyping = false;
      widget.socketService.sendTypingStop(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );
    }
    _typingTimer?.cancel();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  // NEW: Voice chat controls
  Future<void> _toggleVoice() async {
    if (widget.voiceService.inVoiceChat) {
      await widget.voiceService.leaveVoiceChat();
    } else {
      await widget.voiceService.joinVoiceChat(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );
    }
    setState(() {});
  }

  Future<void> _toggleMute() async {
    if (!widget.voiceService.inVoiceChat) return;
    await widget.voiceService.toggleMute();
    setState(() {});
  }

  // Show user action modal
  void _showUserActionModal(String messageUserId, String messageUsername) {
    if (messageUserId == widget.userId) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UserActionModal(
        userId: messageUserId,
        username: messageUsername,
        currentUserId: widget.userId,
        onAction: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _chatMessageSub.cancel();
    _chatHistorySub.cancel();
    _typingSub.cancel();
    _voiceParticipantsSub?.cancel();  // NEW
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _animationController.dispose();
    _onStoppedTyping();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;
    
    return GestureDetector(
      onTap: _close,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: AppColors.primaryNavyDark.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                width: size.width * 0.9,
                height: size.height * 0.7,
                margin: EdgeInsets.only(bottom: size.height * 0.1),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavyDark.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with Voice Controls
                    Container(
                      padding: EdgeInsets.all(isSmall ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Title row
                          Row(
                            children: [
                              Icon(
                                Icons.chat,
                                color: Colors.blue,
                                size: isSmall ? 20 : 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Game Chat',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: AppColors.textPrimary,
                                    fontSize: isSmall ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${_messages.length}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.grey[400],
                                  fontSize: isSmall ? 12 : 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _close,
                                color: AppColors.textPrimary,
                                iconSize: isSmall ? 20 : 24,
                              ),
                            ],
                          ),
                          
                          // NEW: Voice controls row
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Voice join/leave button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleVoice,
                                  icon: Icon(
                                    widget.voiceService.inVoiceChat 
                                        ? Icons.mic 
                                        : Icons.mic_none,
                                    size: isSmall ? 14 : 16,
                                  ),
                                  label: Text(
                                    widget.voiceService.inVoiceChat 
                                        ? 'Leave Voice' 
                                        : 'Join Voice',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: isSmall ? 11 : 12,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.voiceService.inVoiceChat 
                                        ? Colors.green 
                                        : Colors.purple,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmall ? 8 : 10,
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Mute button (only when in voice)
                              if (widget.voiceService.inVoiceChat) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _toggleMute,
                                    icon: Icon(
                                      widget.voiceService.isMuted 
                                          ? Icons.mic_off 
                                          : Icons.volume_up,
                                      size: isSmall ? 14 : 16,
                                    ),
                                    label: Text(
                                      widget.voiceService.isMuted 
                                          ? 'Unmute' 
                                          : 'Mute',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: isSmall ? 11 : 12,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.voiceService.isMuted 
                                          ? Colors.red 
                                          : Colors.grey[700],
                                      padding: EdgeInsets.symmetric(
                                        vertical: isSmall ? 8 : 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          // NEW: Voice participants indicator
                          if (widget.voiceService.inVoiceChat && 
                              widget.voiceService.participants.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: Colors.green,
                                    size: isSmall ? 12 : 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.voiceService.participants.length} in voice',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.green,
                                      fontSize: isSmall ? 10 : 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Messages List
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.grey[700],
                                    size: isSmall ? 48 : 64,
                                  ),
                                  SizedBox(height: isSmall ? 8 : 12),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.grey[600],
                                      fontSize: isSmall ? 14 : 16,
                                    ),
                                  ),
                                  SizedBox(height: isSmall ? 4 : 6),
                                  Text(
                                    'Start the conversation!',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.grey[700],
                                      fontSize: isSmall ? 10 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.all(isSmall ? 8 : 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                return _buildMessageBubble(message, isSmall);
                              },
                            ),
                    ),

                    // Typing Indicator
                    if (_typingUsers.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 12 : 16,
                          vertical: isSmall ? 4 : 6,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _buildTypingText(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.grey[500],
                            fontSize: isSmall ? 10 : 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Message Input
                    Container(
                      padding: EdgeInsets.all(isSmall ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textPrimary,
                                fontSize: isSmall ? 12 : 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.grey[600],
                                  fontSize: isSmall ? 12 : 14,
                                ),
                                filled: true,
                                fillColor: AppColors.primaryNavyDark,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmall ? 12 : 16,
                                  vertical: isSmall ? 8 : 10,
                                ),
                              ),
                              maxLength: 500,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                                return null;
                              },
                              onChanged: (text) {
                                if (text.isNotEmpty) {
                                  _onTyping();
                                } else {
                                  _onStoppedTyping();
                                }
                              },
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          SizedBox(width: isSmall ? 6 : 8),
                          SizedBox(
                            width: isSmall ? 36 : 44,
                            height: isSmall ? 36 : 44,
                            child: IconButton(
                              onPressed: _sendMessage,
                              icon: Icon(
                                Icons.send,
                                size: isSmall ? 18 : 22,
                              ),
                              color: Colors.blue,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isSmall) {
    final isOwnMessage = message.userId == widget.userId;
    final isSystem = message.isSystemMessage;

    if (isSystem) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 3 : 4),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 10 : 12,
              vertical: isSmall ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.message,
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.grey[400],
                fontSize: isSmall ? 10 : 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmall ? 3 : 4),
      child: Row(
        mainAxisAlignment: isOwnMessage 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOwnMessage) ...[
            GestureDetector(
              onTap: () => _showUserActionModal(message.userId!, message.username),
              child: CircleAvatar(
                radius: isSmall ? 14 : 16,
                backgroundColor: Colors.blue,
                child: Text(
                  message.username[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textPrimary,
                    fontSize: isSmall ? 10 : 12,
                  ),
                ),
              ),
            ),
            SizedBox(width: isSmall ? 6 : 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwnMessage 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                if (!isOwnMessage)
                  GestureDetector(
                    onTap: () => _showUserActionModal(message.userId!, message.username),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: isSmall ? 2 : 4,
                        left: isSmall ? 3 : 4,
                      ),
                      child: Text(
                        message.username,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.blue[300],
                          fontSize: isSmall ? 10 : 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 10 : 12,
                    vertical: isSmall ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isOwnMessage 
                        ? Colors.blue[700] 
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.message,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textPrimary,
                          fontSize: isSmall ? 12 : 14,
                        ),
                      ),
                      SizedBox(height: isSmall ? 2 : 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isOwnMessage 
                              ? Colors.blue[200] 
                              : Colors.grey[500],
                          fontSize: isSmall ? 8 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isOwnMessage) ...[
            SizedBox(width: isSmall ? 6 : 8),
            CircleAvatar(
              radius: isSmall ? 14 : 16,
              backgroundColor: AppColors.primaryNavyLight,
              child: Text(
                widget.username[0].toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: AppColors.textPrimary,
                  fontSize: isSmall ? 10 : 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildTypingText() {
    final users = _typingUsers.toList();
    if (users.isEmpty) return '';
    if (users.length == 1) return '${users[0]} is typing...';
    if (users.length == 2) return '${users[0]} and ${users[1]} are typing...';
    return '${users[0]} and ${users.length - 1} others are typing...';
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

// User Action Modal with Friend Request, Block, and Report
class _UserActionModal extends StatefulWidget {
  final String userId;
  final String username;
  final String currentUserId;
  final VoidCallback onAction;

  const _UserActionModal({
    required this.userId,
    required this.username,
    required this.currentUserId,
    required this.onAction,
  });

  @override
  State<_UserActionModal> createState() => _UserActionModalState();
}

class _UserActionModalState extends State<_UserActionModal> {
  bool _isLoading = false;

  Future<void> _handleFriendRequest() async {
    setState(() => _isLoading = true);
    
    final result = await FriendsService.sendRequest(widget.userId);
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (result['success']) {
        _showSnackBar('Friend request sent to ${widget.username}', Colors.green);
        widget.onAction();
      } else {
        _showSnackBar(result['error'], Colors.red);
      }
    }
  }

  Future<void> _handleBlock() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Block ${widget.username}?',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Blocking ${widget.username} will prevent them from sending you messages or friend requests.',
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      final result = await FriendsService.blockUser(widget.userId);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success']) {
          _showSnackBar('${widget.username} has been blocked', Colors.orange);
          widget.onAction();
        } else {
          _showSnackBar(result['error'], Colors.red);
        }
      }
    }
  }

  Future<void> _handleReport() async {
    final reportData = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ReportReasonDialog(username: widget.username),
    );

    if (reportData != null && reportData['reason'] != null) {
      setState(() => _isLoading = true);
      
      final result = await FriendsService.reportUser(
        userId: widget.userId,
        reason: reportData['reason']!,
        message: reportData['message'],
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success']) {
          _showSnackBar(
            'Thank you for your report. Our moderation team will review it.',
            Colors.green,
          );
          widget.onAction();
        } else {
          _showSnackBar(result['error'], Colors.red);
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue,
                  child: Text(
                    widget.username[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.username,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(color: Colors.grey[800]),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Send Friend Request
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.green),
              title: const Text(
                'Send Friend Request',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: _handleFriendRequest,
            ),
            
            // Block User
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orange),
              title: const Text(
                'Block User',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: _handleBlock,
            ),
            
            // Report User
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: const Text(
                'Report User',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: _handleReport,
            ),
            
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// Report Reason Dialog
class _ReportReasonDialog extends StatefulWidget {
  final String username;

  const _ReportReasonDialog({required this.username});

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  String? _selectedReason;
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, String>> _reasons = [
    {'value': 'harassment', 'label': 'Harassment or Bullying'},
    {'value': 'inappropriate_content', 'label': 'Inappropriate Content'},
    {'value': 'offensive_language', 'label': 'Offensive Language'},
    {'value': 'spam', 'label': 'Spam'},
    {'value': 'cheating', 'label': 'Cheating'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Report ${widget.username}',
        style: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please select a reason for reporting this user:',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ..._reasons.map((reason) => RadioListTile<String>(
              value: reason['value']!,
              groupValue: _selectedReason,
              title: Text(
                reason['label']!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              activeColor: Colors.red,
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 16),
            const Text(
              'Additional details (optional):',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Provide additional context...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                filled: true,
                fillColor: AppColors.primaryNavyDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  final message = _messageController.text.trim();
                  Navigator.pop(context, {
                    'reason': _selectedReason!,
                    'message': message.isEmpty ? null : message,
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
          ),
          child: const Text(
            'Report',
            style: TextStyle(fontFamily: 'Inter'),
          ),
        ),
      ],
    );
  }
}