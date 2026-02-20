// ====================================
// lib/widgets/chat_overlay.dart
// Full-screen chat overlay with integrated voice controls and social features
//
// PURPOSE:
//   Provides an in-game chat panel that slides up from the bottom of the
//   screen.  In addition to text messaging, the overlay surfaces voice-chat
//   join/leave and mute controls so players can manage both communication
//   channels in one place.
//
// FEATURES:
//   - Real-time text chat via SocketService (send, receive, history load)
//   - Typing indicators with a 2-second debounce (stops broadcasting
//     "is typing" after the player pauses)
//   - Voice chat join/leave and mute toggle via VoiceChatService
//   - Live participant count badge shown when in voice
//   - Tap-on-avatar/username to open a social action sheet (friend request,
//     block, report)
//   - System messages rendered in a distinct centred style
//   - Slide-up/slide-down animation on open/close
//   - Responsive sizing for small handsets (< 360 px wide)
//
// COMPLIANCE:
//   Report reasons and user-blocking features are implemented in line with
//   the UK Online Safety Act 2023, which requires user-to-user services to
//   provide accessible reporting mechanisms.
//
// USAGE:
//   Mount as a full-screen overlay inside a Stack, revealing it on demand.
//   Example:
//     ChatOverlay(
//       roomId: _roomId,
//       userId: _userId,
//       username: _username,
//       socketService: _socketService,
//       voiceService: _voiceService,
//       onClose: () => setState(() => _showChat = false),
//     )
// ====================================

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/voice_chat_service.dart';
import '../services/social_service.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

/// Full-screen sliding chat overlay that combines text and voice communication
/// with social moderation tools.
class ChatOverlay extends StatefulWidget {
  /// The game room this chat belongs to.  All socket events are scoped to this
  /// room ID so messages from other rooms are never shown here.
  final String roomId;

  /// The authenticated user's ID, used to distinguish own messages from others
  /// and to prevent social actions being taken against oneself.
  final String userId;

  /// Display name of the authenticated user, used for typing events and the
  /// avatar initial.
  final String username;

  /// Socket service instance for text-chat events.
  final SocketService socketService;

  /// Voice chat service instance for join/leave/mute operations and the
  /// participants stream.
  final VoiceChatService voiceService;

  /// Called after the close animation finishes so the parent can unmount the
  /// overlay.
  final VoidCallback onClose;

  const ChatOverlay({
    super.key,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.socketService,
    required this.voiceService,
    required this.onClose,
  });

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay>
    with SingleTickerProviderStateMixin {
  // ─── Controllers ──────────────────────────────────────────────────────────

  /// Controls the text input field at the bottom of the overlay.
  final TextEditingController _messageController = TextEditingController();

  /// Keeps the message list scrolled to the most recent message.
  final ScrollController _scrollController = ScrollController();

  /// Drives the slide-up/slide-down entrance and exit animation.
  late AnimationController _animationController;

  /// The actual slide offset derived from [_animationController].
  /// Starts off-screen below (Offset(0, 1)) and animates to the visible
  /// position (Offset.zero).
  late Animation<Offset> _slideAnimation;

  // ─── State ────────────────────────────────────────────────────────────────

  /// Accumulated chat messages for this session, including history loaded
  /// on open and any new messages received whilst the overlay is visible.
  final List<ChatMessage> _messages = [];

  /// Usernames of players who are currently typing; shown as a typing
  /// indicator above the input bar.
  final Set<String> _typingUsers = {};

  /// Whether this user is currently broadcasting a "typing" event.
  bool _isTyping = false;

  /// Debounce timer: resets each keystroke and fires [_onStoppedTyping] after
  /// 2 seconds of inactivity.
  Timer? _typingTimer;

  // ─── Stream Subscriptions ─────────────────────────────────────────────────

  late StreamSubscription _chatMessageSub;
  late StreamSubscription _chatHistorySub;
  late StreamSubscription _typingSub;

  /// Subscription to the voice participants stream so the UI rebuilds when
  /// someone joins or leaves voice chat.
  StreamSubscription? _voiceParticipantsSub;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Slide animation: panel enters from below the visible area.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start fully below screen.
      end: Offset.zero,          // End at natural position.
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _setupListeners();
    _loadChatHistory();
    _animationController.forward(); // Trigger entry animation on mount.
  }

  /// Attaches all socket and service stream listeners.
  void _setupListeners() {
    // ── Incoming Chat Messages ────────────────────────────────────────────
    _chatMessageSub = widget.socketService.onChatMessage.listen((data) {
      final message = ChatMessage.fromJson(data);
      setState(() {
        _messages.add(message);
        // When a message arrives from a user, they are no longer "typing".
        _typingUsers.remove(message.username);
      });
      _scrollToBottom();
    });

    // ── Chat History ─────────────────────────────────────────────────────
    // Replaces the local messages list with the server-side history so the
    // player can read what was said before they opened the overlay.
    _chatHistorySub = widget.socketService.onChatHistory.listen((data) {
      final List<dynamic> messagesJson = data['messages'] ?? [];
      setState(() {
        _messages.clear();
        _messages.addAll(
          messagesJson.map((json) => ChatMessage.fromJson(json)).toList(),
        );
      });
      _scrollToBottom();
    });

    // ── Typing Indicators ─────────────────────────────────────────────────
    _typingSub = widget.socketService.onUserTyping.listen((data) {
      final username = data['username'];
      final isTyping = data['isTyping'] ?? false;

      // Never show the current player as "typing" to themselves.
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

    // ── Voice Participants ────────────────────────────────────────────────
    // Trigger a rebuild whenever the voice participant list changes so the
    // count badge and participant indicator stay up to date.
    _voiceParticipantsSub = widget.voiceService.participantsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  /// Requests the last 50 messages from the server for this room.
  void _loadChatHistory() {
    widget.socketService.getChatHistory(
      roomId: widget.roomId,
      limit: 50,
    );
  }

  // ─── Messaging ────────────────────────────────────────────────────────────

  /// Sends the current input text as a chat message and clears the field.
  /// Does nothing if the trimmed text is empty.
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    widget.socketService.sendMessage(
      roomId: widget.roomId,
      userId: widget.userId,
      message: message,
    );

    _messageController.clear();
    _onStoppedTyping(); // Stop broadcasting "typing" immediately after sending.
  }

  /// Called on every keystroke while the message field is non-empty.
  ///
  /// Emits a typing-start event the first time it is called after a pause,
  /// then resets the debounce timer so [_onStoppedTyping] is deferred
  /// another 2 seconds.
  void _onTyping() {
    if (!_isTyping) {
      _isTyping = true;
      widget.socketService.sendTypingStart(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );
    }

    // Reset the debounce timer every keystroke.
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _onStoppedTyping);
  }

  /// Emits a typing-stop event and marks the user as no longer typing.
  /// Called either automatically by the debounce timer or immediately when
  /// a message is sent.
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

  // ─── Scroll ───────────────────────────────────────────────────────────────

  /// Smoothly scrolls the message list to reveal the most recent message.
  /// Deferred to the next frame to ensure the layout has settled after
  /// [setState] adds the new message.
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

  // ─── Overlay Lifecycle ────────────────────────────────────────────────────

  /// Plays the exit animation before calling [onClose] so the panel slides
  /// down gracefully rather than disappearing instantly.
  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  // ─── Voice Chat ───────────────────────────────────────────────────────────

  /// Joins or leaves the voice channel for this room.  The button label and
  /// colour update reactively because the build method reads
  /// [voiceService.inVoiceChat] directly.
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

  /// Toggles the microphone mute state for the current session.
  /// Does nothing when the user is not in voice chat.
  Future<void> _toggleMute() async {
    if (!widget.voiceService.inVoiceChat) return;
    await widget.voiceService.toggleMute();
    setState(() {});
  }

  // ─── Social Actions ───────────────────────────────────────────────────────

  /// Opens a bottom sheet with friend-request, block, and report options for
  /// [messageUserId].  Silently returns if the target is the current user so
  /// players cannot accidentally report themselves.
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

  // ─── Disposal ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks.
    _chatMessageSub.cancel();
    _chatHistorySub.cancel();
    _typingSub.cancel();
    _voiceParticipantsSub?.cancel();

    // Dispose controllers.
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _animationController.dispose();

    // Ensure the typing indicator is cleared from other players' screens
    // when the overlay is closed.
    _onStoppedTyping();

    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Compact mode for very small handsets (e.g. 320 px wide budget devices).
    final isSmall = size.width < 360;

    return GestureDetector(
      // Tapping the semi-transparent backdrop closes the overlay.
      onTap: _close,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Semi-transparent dark backdrop.
        color: AppColors.primaryNavyDark.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            // Absorb taps inside the panel so they don't propagate to the
            // backdrop detector above.
            onTap: () {},
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                width: size.width * 0.9,
                height: size.height * 0.7,
                // Push the panel slightly above centre so the keyboard does
                // not cover it on smaller screens.
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
                    // ── Header ─────────────────────────────────────────────
                    // Contains the title, message count, close button, voice
                    // controls, and the participant count badge.
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
                          // ── Title Row ────────────────────────────────────
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
                              // Total message count shown for context.
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

                          // ── Voice Controls Row ────────────────────────────
                          // Shown beneath the title so voice and text controls
                          // are co-located rather than split across screens.
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Join / leave voice button.
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
                                    // Green when in voice to reinforce "active"
                                    // state; purple when not joined yet.
                                    backgroundColor:
                                        widget.voiceService.inVoiceChat
                                            ? Colors.green
                                            : Colors.purple,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmall ? 8 : 10,
                                    ),
                                  ),
                                ),
                              ),

                              // Mute toggle – only visible whilst in voice.
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
                                      // Red when muted for clear visual feedback.
                                      backgroundColor:
                                          widget.voiceService.isMuted
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

                          // ── Voice Participant Count ────────────────────────
                          // Small green badge shown when at least one person
                          // is in voice so everyone can see who is present.
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

                    // ── Message List ────────────────────────────────────────
                    // Scrollable area containing all chat messages.  Shows an
                    // empty-state illustration when no messages have been
                    // exchanged yet.
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

                    // ── Typing Indicator ────────────────────────────────────
                    // Shown above the input bar whilst other players are typing.
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

                    // ── Message Input ───────────────────────────────────────
                    // Fixed footer with a rounded text field and send button.
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
                              // Enforce the 500-character limit without showing
                              // the built-in character counter (kept clean).
                              maxLength: 500,
                              buildCounter: (context,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) {
                                return null; // Hide the default counter label.
                              },
                              onChanged: (text) {
                                if (text.isNotEmpty) {
                                  _onTyping();
                                } else {
                                  // Field cleared – stop broadcasting "typing".
                                  _onStoppedTyping();
                                }
                              },
                              // Allow sending with the keyboard return key.
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          SizedBox(width: isSmall ? 6 : 8),
                          // Send button: tappable arrow icon.
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

  // ─── Message Bubble ───────────────────────────────────────────────────────

  /// Builds the appropriate message bubble for [message].
  ///
  /// System messages (e.g. "Player X joined") are displayed centred without
  /// an avatar.  Regular messages are right-aligned for the current user and
  /// left-aligned for others, with avatar initials and a tappable username
  /// that opens the social action modal.
  Widget _buildMessageBubble(ChatMessage message, bool isSmall) {
    final isOwnMessage = message.userId == widget.userId;
    final isSystem = message.isSystemMessage;

    // ── System Message ───────────────────────────────────────────────────
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

    // ── Regular Message ──────────────────────────────────────────────────
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmall ? 3 : 4),
      child: Row(
        // Own messages on the right; others' on the left.
        mainAxisAlignment: isOwnMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left avatar – only for other players, tappable for social actions.
          if (!isOwnMessage) ...[
            GestureDetector(
              onTap: () =>
                  _showUserActionModal(message.userId!, message.username),
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

          // Message content column.
          Flexible(
            child: Column(
              crossAxisAlignment: isOwnMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Tappable username shown above other players' messages.
                if (!isOwnMessage)
                  GestureDetector(
                    onTap: () => _showUserActionModal(
                        message.userId!, message.username),
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
                          // Underline hints the username is tappable.
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                // Bubble containing the message text and timestamp.
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 10 : 12,
                    vertical: isSmall ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    // Own messages: blue.  Others': dark grey.
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
                      // Relative timestamp (e.g. "Just now", "3m ago").
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

          // Right avatar – only for the current user's own messages.
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Builds a natural-language typing indicator string for the names in
  /// [_typingUsers].
  ///
  /// Examples:
  ///   - "Alice is typing..."
  ///   - "Alice and Bob are typing..."
  ///   - "Alice and 2 others are typing..."
  String _buildTypingText() {
    final users = _typingUsers.toList();
    if (users.isEmpty) return '';
    if (users.length == 1) return '${users[0]} is typing...';
    if (users.length == 2) return '${users[0]} and ${users[1]} are typing...';
    return '${users[0]} and ${users.length - 1} others are typing...';
  }

  /// Formats a [timestamp] as a human-friendly relative string.
  ///
  /// Returns:
  ///   - "Just now"   – less than 1 minute ago
  ///   - "Xm ago"    – less than 1 hour ago
  ///   - "Xh ago"    – less than 1 day ago
  ///   - "HH:MM"     – older messages (absolute time)
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';

    // Fall back to an absolute time for messages older than 24 hours.
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

// ====================================
// _UserActionModal
// Bottom sheet providing social actions against another player
// ====================================

/// A bottom sheet that lets the current player send a friend request to,
/// block, or report another player encountered in the chat.
///
/// Confirmation dialogs are shown before destructive actions (block) to
/// prevent accidental submissions.  Report submissions are routed through
/// [_ReportReasonDialog] to capture a categorised reason, as required for
/// UK Online Safety Act 2023 compliance.
class _UserActionModal extends StatefulWidget {
  /// The target player's account ID.
  final String userId;

  /// The target player's display name, shown in dialog titles.
  final String username;

  /// The acting user's ID, used internally by service calls.
  final String currentUserId;

  /// Called after an action completes so the parent can close the sheet.
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
  /// Indicates an async operation (friend request / block / report) is in
  /// progress.  Replaced the action list with a loading spinner whilst true.
  bool _isLoading = false;

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Sends a friend request to [widget.userId] via [FriendsService].
  Future<void> _handleFriendRequest() async {
    setState(() => _isLoading = true);

    final result = await FriendsService.sendRequest(widget.userId);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success']) {
        _showSnackBar(
            'Friend request sent to ${widget.username}', Colors.green);
        widget.onAction();
      } else {
        _showSnackBar(result['error'], Colors.red);
      }
    }
  }

  /// Prompts for confirmation and blocks [widget.userId] if confirmed.
  ///
  /// Blocking prevents the target from sending this player messages or friend
  /// requests, consistent with expectations under the UK Online Safety Act.
  Future<void> _handleBlock() async {
    // Require explicit confirmation before taking an irreversible action.
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
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
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
          _showSnackBar(
              '${widget.username} has been blocked', Colors.orange);
          widget.onAction();
        } else {
          _showSnackBar(result['error'], Colors.red);
        }
      }
    }
  }

  /// Opens [_ReportReasonDialog] to collect a category and optional detail,
  /// then submits the report via [FriendsService].
  ///
  /// Providing a structured reason category is a requirement of the UK Online
  /// Safety Act 2023 to support effective content moderation.
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Shows a brief [message] snackbar with the given background [color].
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Player Info Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // Avatar initial circle.
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

          // ── Action List / Loading Spinner ──────────────────────────────
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Send Friend Request.
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

            // Block User.
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

            // Report User.
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

// ====================================
// _ReportReasonDialog
// Categorised report submission form
// ====================================

/// Modal dialog that asks the reporter to select a reason category and
/// optionally provide additional context before submitting a user report.
///
/// Categories are aligned with the harmful content definitions set out in the
/// UK Online Safety Act 2023.  The structured category data is passed back
/// to the caller via [Navigator.pop] as a `Map<String, String>` containing
/// `reason` (category value) and `message` (optional free text).
class _ReportReasonDialog extends StatefulWidget {
  /// Display name of the user being reported, shown in the dialog title.
  final String username;

  const _ReportReasonDialog({required this.username});

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  /// Currently selected report category value (e.g. 'harassment').
  String? _selectedReason;

  /// Optional free-text field for additional context.
  final TextEditingController _messageController = TextEditingController();

  /// Available report reason categories.  Values are stored server-side;
  /// labels are displayed to the user.
  ///
  /// Categories are informed by the UK Online Safety Act 2023 categories of
  /// regulated content, ensuring reports are actionable by moderators.
  final List<Map<String, String>> _reasons = [
    {'value': 'harassment',            'label': 'Harassment or Bullying'},
    {'value': 'inappropriate_content', 'label': 'Inappropriate Content'},
    {'value': 'offensive_language',    'label': 'Offensive Language'},
    {'value': 'spam',                  'label': 'Spam'},
    {'value': 'cheating',              'label': 'Cheating'},
    {'value': 'other',                 'label': 'Other'},
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

            // Radio list of report categories.
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

            // Optional free-text field for supplementary details.
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
          // Submit button remains disabled until a reason category is selected.
          onPressed: _selectedReason == null
              ? null
              : () {
                  final message = _messageController.text.trim();
                  // Return the category and optional detail to the caller.
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