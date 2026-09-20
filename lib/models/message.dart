enum MessageType { text, image, file, system }

class Message {
  final String id;
  final String senderId;
  final String? senderUsername;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;
  final bool read;
  final bool edited;

  Message({
    required this.id,
    required this.senderId,
    this.senderUsername,
    required this.text,
    this.type = MessageType.text,
    required this.timestamp,
    this.mediaUrl,
    this.read = false,
    this.edited = false,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      senderUsername: map['senderUsername'],
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      mediaUrl: map['mediaUrl'],
      read: map['read'] ?? false,
      edited: map['edited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderUsername': senderUsername,
      'text': text,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'mediaUrl': mediaUrl,
      'read': read,
      'edited': edited,
    };
  }
}