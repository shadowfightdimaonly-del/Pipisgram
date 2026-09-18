class AppUser {
  final String uid;
  final String username;
  final String? avatarUrl;
  final bool online;
  final DateTime? lastSeen;

  AppUser({
    required this.uid,
    required this.username,
    this.avatarUrl,
    this.online = false,
    this.lastSeen,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      username: map['username'] ?? 'Без имени',
      avatarUrl: map['avatarUrl'],
      online: map['online'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'avatarUrl': avatarUrl,
      'online': online,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
    };
  }
}
