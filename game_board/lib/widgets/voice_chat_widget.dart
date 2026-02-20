// ====================================
// lib/widgets/voice_chat_widget.dart
// Compact in-game voice chat overlay widget
//
// PURPOSE:
//   Provides a minimal floating widget, pinned to the top-right corner of the
//   game screen, for managing voice communication without obscuring gameplay.
//   Players can join/leave voice, mute/unmute themselves, and view or report
//   other participants – all without navigating away from the game table.
//
// FEATURES:
//   - Single tap: join or leave the voice channel
//   - Long press (when in voice): expand the participant list panel
//   - Mute/unmute button shown beneath the join/leave control whilst in voice
//   - Animated expand/collapse of the participant list (SizeTransition)
//   - Participant count badge to show at a glance how many are in voice
//   - Report dialog for each participant (UK Online Safety Act 2023 compliance)
//   - Error toasts via ScaffoldMessenger
//   - Loading spinner whilst a join/leave operation is in progress to prevent
//     double-taps
//
// COMPLIANCE:
//   The report dialog provides categorised reporting as required by the UK
//   Online Safety Act 2023, ensuring players can flag harmful voice behaviour.
//
// USAGE:
//   Mount inside a Stack (e.g. on the game screen) so it floats above the
//   game canvas:
//     Stack(children: [
//       GameCanvas(),
//       VoiceChatWidget(
//         voiceService: _voiceService,
//         roomId: _roomId,
//         userId: _userId,
//         username: _username,
//       ),
//     ])
// ====================================

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/voice_chat_service.dart';
import '../theme/app_theme.dart';

/// Compact floating widget for in-game voice chat control and participant
/// management.
class VoiceChatWidget extends StatefulWidget {
  /// The voice chat service that manages WebRTC connections and peer state.
  final VoiceChatService voiceService;

  /// Room identifier – passed to [VoiceChatService.joinVoiceChat] to scope
  /// the voice session to the current game room.
  final String roomId;

  /// The authenticated user's ID.
  final String userId;

  /// The authenticated user's display name, broadcast to other participants.
  final String username;

  const VoiceChatWidget({
    super.key,
    required this.voiceService,
    required this.roomId,
    required this.userId,
    required this.username,
  });

  @override
  State<VoiceChatWidget> createState() => _VoiceChatWidgetState();
}

class _VoiceChatWidgetState extends State<VoiceChatWidget>
    with SingleTickerProviderStateMixin {
  // ─── Stream Subscriptions ─────────────────────────────────────────────────

  /// Listens for participant list updates from [VoiceChatService] so the
  /// widget rebuilds when someone joins or leaves voice.
  late StreamSubscription _participantsSub;

  /// Listens for error events from [VoiceChatService] and surfaces them as
  /// snackbar notifications.
  late StreamSubscription _errorSub;

  // ─── State ────────────────────────────────────────────────────────────────

  /// Local copy of the current voice participant list, updated via the stream.
  List<VoiceParticipant> _participants = [];

  /// Whether the participant list panel is currently expanded.
  bool _isExpanded = false;

  /// Guard flag to prevent duplicate join/leave requests whilst one is
  /// already in progress.
  bool _isJoining = false;

  // ─── Animation ────────────────────────────────────────────────────────────

  /// Drives the expand/collapse animation for the participant list.
  late AnimationController _animationController;

  /// Curved animation derived from [_animationController] for smooth
  /// ease-in/out expansion.
  late Animation<double> _expandAnimation;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _setupListeners();
  }

  /// Subscribes to [VoiceChatService] streams to keep local state in sync.
  void _setupListeners() {
    // Update the local participant list whenever the service emits new data.
    _participantsSub =
        widget.voiceService.participantsStream.listen((participants) {
      setState(() {
        _participants = participants;
      });
    });

    // Show any service errors as floating snackbars.
    _errorSub = widget.voiceService.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ─── Voice Controls ───────────────────────────────────────────────────────

  /// Toggles between joining and leaving the voice channel.
  ///
  /// Sets [_isJoining] to prevent re-entrant calls whilst the async operation
  /// is running (e.g. the user tapping repeatedly).  Collapses the participant
  /// panel automatically when leaving.
  Future<void> _toggleVoiceChat() async {
    if (_isJoining) return; // Ignore taps whilst already transitioning.

    setState(() => _isJoining = true);

    try {
      if (widget.voiceService.inVoiceChat) {
        await widget.voiceService.leaveVoiceChat();
        // Collapse and hide the participant list on leave.
        _animationController.reverse();
        setState(() => _isExpanded = false);
      } else {
        await widget.voiceService.joinVoiceChat(
          roomId: widget.roomId,
          userId: widget.userId,
          username: widget.username,
        );
      }
    } finally {
      // Always clear the loading flag, even if an error was thrown.
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  /// Toggles the expanded state of the participant list panel and drives the
  /// corresponding animation.
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  // ─── Reporting ────────────────────────────────────────────────────────────

  /// Opens the report dialog for [participant].
  ///
  /// On confirmation, submits the report via [VoiceChatService.reportUser]
  /// and shows a success snackbar.  Implements the user-reporting requirement
  /// of the UK Online Safety Act 2023.
  void _showReportDialog(VoiceParticipant participant) {
    showDialog(
      context: context,
      builder: (context) => _ReportDialog(
        participant: participant,
        onReport: (reason) {
          widget.voiceService.reportUser(
            reportedUserId: participant.userId,
            reportedUsername: participant.username,
            reason: reason,
          );
          Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report submitted'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  // ─── Disposal ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _participantsSub.cancel();
    _errorSub.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inVoice = widget.voiceService.inVoiceChat;
    final isMuted  = widget.voiceService.isMuted;

    // Positioned in the top-right corner, above the game canvas.
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            // Border colour signals whether the user is in voice (green) or not.
            border: Border.all(
              color: inVoice ? Colors.green : Colors.grey[700]!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main Control Button ──────────────────────────────────────
              // Tap to join/leave; long-press to expand the participant list.
              InkWell(
                onTap: _toggleVoiceChat,
                onLongPress: inVoice ? _toggleExpanded : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show a spinner whilst the join/leave request is in flight.
                      if (_isJoining)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.green),
                          ),
                        )
                      else
                        // Microphone icon reflects current mute state.
                        Icon(
                          inVoice
                              ? (isMuted ? Icons.mic_off : Icons.mic)
                              : Icons.mic_none,
                          color: inVoice
                              ? (isMuted ? Colors.red : Colors.green)
                              : Colors.grey,
                          size: 20,
                        ),

                      // Participant count badge – only shown when in voice.
                      if (inVoice && _participants.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_participants.length}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Mute / Unmute Button ─────────────────────────────────────
              // Only visible whilst in a voice session.
              if (inVoice)
                InkWell(
                  onTap: () => widget.voiceService.toggleMute(),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      // Red when muted to provide a clear "you cannot be heard" signal.
                      color: isMuted ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),

              // ── Expandable Participant List ───────────────────────────────
              // Animated panel revealed on long-press.  Lists all participants
              // with their mute status and a report option for non-self users.
              SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: -1, // Expand downward from the top of the panel.
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(color: Colors.grey, height: 1),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _participants.length,
                          itemBuilder: (context, index) {
                            final participant = _participants[index];
                            // Distinguish the current user from other participants.
                            final isCurrentUser =
                                participant.userId == widget.userId;

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                participant.muted
                                    ? Icons.mic_off
                                    : Icons.mic,
                                color: participant.muted
                                    ? Colors.red
                                    : Colors.green,
                                size: 16,
                              ),
                              title: Text(
                                // Show "You" for the current user for clarity.
                                isCurrentUser ? 'You' : participant.username,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isCurrentUser
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              // Report option for other participants only.
                              trailing: !isCurrentUser
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _showReportDialog(participant),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================
// _ReportDialog
// UK Online Safety Act 2023 compliant report submission form
// ====================================

/// Modal dialog for reporting a voice-chat participant.
///
/// Requires the reporter to select a reason category before enabling the
/// submit button, and optionally accepts additional detail text (up to 500
/// characters).  Categorised reporting supports the moderation obligations
/// set out in the UK Online Safety Act 2023.
class _ReportDialog extends StatefulWidget {
  /// The participant being reported.
  final VoiceParticipant participant;

  /// Callback invoked with the full report reason string when the player
  /// submits the report.
  final Function(String reason) onReport;

  const _ReportDialog({
    required this.participant,
    required this.onReport,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  /// Currently selected reason category.  Submit button is disabled until
  /// this is non-null.
  String? _selectedReason;

  /// Optional free-text controller for additional context.
  final TextEditingController _detailsController = TextEditingController();

  /// Available report reason categories, aligned with harmful content
  /// definitions in the UK Online Safety Act 2023.
  final List<String> _reportReasons = [
    'Harassment or bullying',
    'Hate speech',
    'Inappropriate language',
    'Spam or advertising',
    'Threats or violence',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Report ${widget.participant.username}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you reporting this user?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Reason radio buttons.
            ..._reportReasons.map((reason) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Radio<String>(
                  value: reason,
                  groupValue: _selectedReason,
                  activeColor: AppColors.accentGold,
                  onChanged: (value) {
                    setState(() => _selectedReason = value);
                  },
                ),
                title: Text(
                  reason,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                // Allow tapping the row as well as the radio button itself.
                onTap: () {
                  setState(() => _selectedReason = reason);
                },
              );
            }),

            const SizedBox(height: 16),

            // Optional detail field – capped at 500 characters.
            TextField(
              controller: _detailsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Additional details (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accentGold),
                ),
              ),
              maxLines: 3,
              maxLength: 500,
            ),

            const SizedBox(height: 8),

            // Deterrence notice to discourage false reports.
            const Text(
              'Reports are reviewed by moderators. False reports may result in restrictions on your account.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          // Disabled until a reason category has been selected.
          onPressed: _selectedReason == null
              ? null
              : () {
                  final details = _detailsController.text.trim();
                  // Combine the category with the optional detail text.
                  final fullReason = details.isEmpty
                      ? _selectedReason!
                      : '$_selectedReason: $details';
                  widget.onReport(fullReason);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit Report'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}