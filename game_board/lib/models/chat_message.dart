// lib/models/chat_message.dart
class ChatMessage {
  final String id;
  final String? userId;
  final String username;
  final String message;
  final DateTime timestamp;
  final ChatMessageType type;

  ChatMessage({
    required this.id,
    this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.type = ChatMessageType.user,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      userId: json['userId'],
      username: json['username'] ?? 'Unknown',
      message: json['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      type: json['type'] == 'system' 
          ? ChatMessageType.system 
          : ChatMessageType.user,
    );
  }

  bool get isSystemMessage => type == ChatMessageType.system;
}

enum ChatMessageType {
  user,
  system,
}