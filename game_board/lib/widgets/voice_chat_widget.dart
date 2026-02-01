// lib/widgets/voice_chat_widget.dart
// Voice Chat UI Widget - Compact overlay for in-game voice
// FIXED: All compilation errors resolved

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/mobile_voice_service.dart';
import '../theme/app_theme.dart';
import '../utils/platform_utils.dart';

class VoiceChatWidget extends StatefulWidget {
  final VoiceChatService voiceService;
  final String roomId;
  final String userId;
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
  
  late StreamSubscription _participantsSub;
  late StreamSubscription _errorSub;
  
  List<VoiceParticipant> _participants = [];
  bool _isExpanded = false;
  bool _isJoining = false;
  
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

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

  void _setupListeners() {
    _participantsSub = widget.voiceService.participantsStream.listen((participants) {
      setState(() {
        _participants = participants;
      });
    });

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

  Future<void> _toggleVoiceChat() async {
    if (_isJoining) return;

    setState(() => _isJoining = true);

    try {
      if (widget.voiceService.inVoiceChat) {
        await widget.voiceService.leaveVoiceChat();
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
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final inVoice = widget.voiceService.inVoiceChat;
    final isMuted = widget.voiceService.isMuted;

    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
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
              // Main control button
              InkWell(
                onTap: _toggleVoiceChat,
                onLongPress: inVoice ? _toggleExpanded : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isJoining)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.green),
                          ),
                        )
                      else
                        Icon(
                          inVoice
                              ? (isMuted ? Icons.mic_off : Icons.mic)
                              : Icons.mic_none,
                          color: inVoice 
                              ? (isMuted ? Colors.red : Colors.green)
                              : Colors.grey,
                          size: 20,
                        ),
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

              // Mute button
              if (inVoice)
                InkWell(
                  onTap: () => widget.voiceService.toggleMute(),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: isMuted ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),

              // Expanded participant list
              SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: -1,
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
                            final isCurrentUser = participant.userId == widget.userId;
                            
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                participant.muted ? Icons.mic_off : Icons.mic,
                                color: participant.muted ? Colors.red : Colors.green,
                                size: 16,
                              ),
                              title: Text(
                                isCurrentUser ? 'You' : participant.username,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isCurrentUser 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: !isCurrentUser
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () => _showReportDialog(participant),
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

  @override
  void dispose() {
    _participantsSub.cancel();
    _errorSub.cancel();
    _animationController.dispose();
    super.dispose();
  }
}

// ===================================
// REPORT DIALOG (UK Online Safety Act 2023 Compliance)
// ===================================

class _ReportDialog extends StatefulWidget {
  final VoiceParticipant participant;
  final Function(String reason) onReport;

  const _ReportDialog({
    required this.participant,
    required this.onReport,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

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
                onTap: () {
                  setState(() => _selectedReason = reason);
                },
              );
            }),
            const SizedBox(height: 16),
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
          onPressed: _selectedReason == null
              ? null
              : () {
                  final details = _detailsController.text.trim();
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