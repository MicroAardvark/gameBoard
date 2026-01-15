// lib/widgets/chat_overlay.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatOverlay extends StatefulWidget {
  final String roomId;
  final String userId;
  final String username;
  final SocketService socketService;
  final VoidCallback onClose;

  const ChatOverlay({
    Key? key,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.socketService,
    required this.onClose,
  }) : super(key: key);

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

  @override
  void dispose() {
    _chatMessageSub.cancel();
    _chatHistorySub.cancel();
    _typingSub.cancel();
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
        color: AppColors.primaryNavyDark.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap from closing when tapping inside
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
                    // Header
                    Container(
                      padding: EdgeInsets.all(isSmall ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
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
                                color: AppColors.textPrimary,
                                fontSize: isSmall ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${_messages.length}',
                            style: TextStyle(
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
                                      color: Colors.grey[600],
                                      fontSize: isSmall ? 14 : 16,
                                    ),
                                  ),
                                  SizedBox(height: isSmall ? 4 : 6),
                                  Text(
                                    'Start the conversation!',
                                    style: TextStyle(
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
                        child: Text(
                          _buildTypingText(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isSmall ? 10 : 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Input Field
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
                                color: AppColors.textPrimary,
                                fontSize: isSmall ? 12 : 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
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
            CircleAvatar(
              radius: isSmall ? 14 : 16,
              backgroundColor: Colors.blue,
              child: Text(
                message.username[0].toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: isSmall ? 10 : 12,
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
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: isSmall ? 2 : 4,
                      left: isSmall ? 3 : 4,
                    ),
                    child: Text(
                      message.username,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: isSmall ? 10 : 12,
                        fontWeight: FontWeight.w500,
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
                          color: AppColors.textPrimary,
                          fontSize: isSmall ? 12 : 14,
                        ),
                      ),
                      SizedBox(height: isSmall ? 2 : 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
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