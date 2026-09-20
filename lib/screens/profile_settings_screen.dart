Future<void> _loadSettings() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    final data = doc.data();
    setState(() {
      _showOnlineStatus = data?['showOnlineStatus'] ?? true;
      _showGifts = data?['showGifts'] ?? false;
      _showTakeoverGift = data?['showTakeoverGift'] ?? false;
      _username = data?['username'] ?? '';
      _avatarUrl = data?['avatarUrl'];
      _profileColorValue = data?['profileColor'] ?? 0xFF2AABEE;
      _hasEditGift = data?['hasGiftEditMessages'] == true;
      _hasAvatarGift = data?['hasGiftChangeAvatars'] == true;
      _hasTakeoverGift = data?['hasGiftGroupTakeover'] == true;
      _loading = false;
    });
  }