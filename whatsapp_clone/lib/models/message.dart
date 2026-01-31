class ChatMessage {
  final DateTime timestamp;
  final String? sender; // Null for system messages
  final String message;
  final bool isMe;

  ChatMessage({
    required this.timestamp,
    this.sender,
    required this.message,
    required this.isMe,
  });

  bool get isSystem => sender == null;

  @override
  String toString() {
    return 'ChatMessage(time: $timestamp, sender: $sender, message: $message, isMe: $isMe)';
  }
}
