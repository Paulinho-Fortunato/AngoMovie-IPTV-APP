import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/watch_history_entry.dart';

/// Flutter-facing persistence contract. Android uses the Room database exposed
/// by MainActivity; other Flutter targets retain the same behavior using private
/// SharedPreferences, without adding a second Android persistence path.
class LocalMediaStore {
  LocalMediaStore._();

  static const MethodChannel _channel =
      MethodChannel('com.angomovie.iptv/local_media');
  static const String _favoriteIdsKey = 'local_media_favorite_ids';
  static const String _historyKey = 'local_media_watch_history';
  static const String _legacyMigrationKey = 'local_media_legacy_favorites_v1';
  static const int _historyLimit = 100;

  static bool get _usesRoom =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Set<String>> getFavoriteIds() async {
    if (_usesRoom) {
      final ids = await _channel.invokeListMethod<Object?>('favorites.getIds');
      return ids?.whereType<String>().toSet() ?? <String>{};
    }

    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_favoriteIdsKey) ?? <String>[]).toSet();
  }

  /// One-time import of the old Hive flag so app upgrades preserve favorites.
  /// Only channel metadata is copied; stream URLs are never sent to Room.
  static Future<void> migrateLegacyFavorites(Iterable<Channel> channels) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_legacyMigrationKey) ?? false) return;

    final legacyFavorites = channels
        .where((channel) => channel.isFavorite)
        .map(_channelMetadata)
        .toList(growable: false);

    if (_usesRoom) {
      await _channel.invokeMethod<void>(
        'favorites.importLegacy',
        <String, Object?>{'channels': legacyFavorites},
      );
    } else {
      final ids = preferences.getStringList(_favoriteIdsKey) ?? <String>[];
      final allIds = <String>{...ids};
      for (final favorite in legacyFavorites) {
        final id = favorite['channelId'] as String?;
        if (id != null && id.isNotEmpty) allIds.add(id);
      }
      await preferences.setStringList(_favoriteIdsKey, allIds.toList());
    }

    await preferences.setBool(_legacyMigrationKey, true);
  }

  /// Returns the persisted state after the atomic Room toggle completes.
  static Future<bool> toggleFavorite(Channel channel) async {
    if (_usesRoom) {
      final isFavorite = await _channel.invokeMethod<bool>(
        'favorites.toggle',
        _channelMetadata(channel),
      );
      return isFavorite ?? !channel.isFavorite;
    }

    final preferences = await SharedPreferences.getInstance();
    final ids = (preferences.getStringList(_favoriteIdsKey) ?? <String>[]).toSet();
    final isFavorite = !ids.contains(channel.id);
    if (isFavorite) {
      ids.add(channel.id);
    } else {
      ids.remove(channel.id);
    }
    await preferences.setStringList(_favoriteIdsKey, ids.toList());
    return isFavorite;
  }

  static Future<WatchHistoryEntry> recordPlayback(Channel channel) async {
    if (_usesRoom) {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'history.record',
        _channelMetadata(channel),
      );
      if (response != null) return WatchHistoryEntry.fromMap(response);
    }

    final preferences = await SharedPreferences.getInstance();
    final rows = _decodeHistory(preferences.getString(_historyKey));
    final previous = rows.where((row) => row.channelId == channel.id).firstOrNull;
    final entry = WatchHistoryEntry(
      channelId: channel.id,
      name: channel.name,
      logoUrl: channel.logoUrl,
      groupTitle: channel.groupTitle,
      tvgId: channel.tvgId,
      lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
      playCount: (previous?.playCount ?? 0) + 1,
    );
    rows.removeWhere((row) => row.channelId == channel.id);
    rows.insert(0, entry);
    await preferences.setString(
      _historyKey,
      jsonEncode(rows.take(_historyLimit).map((row) => row.toMap()).toList()),
    );
    return entry;
  }

  static Future<List<WatchHistoryEntry>> getWatchHistory() async {
    if (_usesRoom) {
      final rows = await _channel.invokeListMethod<Object?>('history.list');
      return rows
              ?.whereType<Map<Object?, Object?>>()
              .map((row) => WatchHistoryEntry.fromMap(
                    Map<String, dynamic>.from(row),
                  ))
              .toList(growable: false) ??
          <WatchHistoryEntry>[];
    }

    final preferences = await SharedPreferences.getInstance();
    return _decodeHistory(preferences.getString(_historyKey));
  }

  static Future<void> clearWatchHistory() async {
    if (_usesRoom) {
      await _channel.invokeMethod<void>('history.clear');
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_historyKey);
  }

  static Map<String, Object?> _channelMetadata(Channel channel) =>
      <String, Object?>{
        'channelId': channel.id,
        'name': channel.name,
        'logoUrl': channel.logoUrl,
        'groupTitle': channel.groupTitle,
        'tvgId': channel.tvgId,
      };

  static List<WatchHistoryEntry> _decodeHistory(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <WatchHistoryEntry>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <WatchHistoryEntry>[];
      return decoded
          .whereType<Map>()
          .map((row) => WatchHistoryEntry.fromMap(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: true);
    } on FormatException {
      return <WatchHistoryEntry>[];
    } on TypeError {
      return <WatchHistoryEntry>[];
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
