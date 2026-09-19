class ChatPreview {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String otherUid;
  final int otherProfileColor;
  final int unreadCount;

  ChatPreview({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.otherUsername,
    this.otherAvatarUrl,
    required this.otherUid,
    this.otherProfileColor = 0xFF2AABEE,
    this.unreadCount = 0,
  });
}