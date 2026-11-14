class WatchHistoryEntry {
  final String channelId;
  final String name;
  final String logoUrl;
  final String groupTitle;
  final String? tvgId;
  final int lastPlayedAt;
  final int playCount;

  const WatchHistoryEntry({
    required this.channelId,
    required this.name,
    required this.logoUrl,
    required this.groupTitle,
    required this.tvgId,
    required this.lastPlayedAt,
    required this.playCount,
  });

  factory WatchHistoryEntry.fromMap(Map<String, dynamic> map) {
    return WatchHistoryEntry(
      channelId: map['channelId'] as String? ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      groupTitle: map['groupTitle'] as String? ?? '',
      tvgId: map['tvgId'] as String?,
      lastPlayedAt: (map['lastPlayedAt'] as num?)?.toInt() ?? 0,
      playCount: (map['playCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'channelId': channelId,
        'name': name,
        'logoUrl': logoUrl,
        'groupTitle': groupTitle,
        'tvgId': tvgId,
        'lastPlayedAt': lastPlayedAt,
        'playCount': playCount,
      };
}
