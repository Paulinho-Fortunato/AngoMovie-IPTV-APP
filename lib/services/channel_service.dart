import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // Default M3U source URL - Direct URL only (backend was causing issues on real devices)
  static const String _defaultM3uUrl =
      'http://nitidez.pro:80/get.php?username=Marcio&password=123456&type=m3u_plus';
  static const String _m3uPrefKey = 'm3u_url';

  static const String _lastFetchKey = 'last_fetch_time';

  static Box<Channel>? _channelBox;

  static Future<void> initHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChannelAdapter());
    }
    _channelBox = await Hive.openBox<Channel>('channels');
  }

  /// Returns the configured M3U URL or the default if not set
  static Future<String> getM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3uPrefKey) ?? _defaultM3uUrl;
  }

  /// Save a custom M3U URL (null/empty -> resets to default)
  static Future<void> setM3uUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_m3uPrefKey);
      if (kDebugMode) debugPrint('🔧 M3U URL reset to default.');
    } else {
      await prefs.setString(_m3uPrefKey, url.trim());
      if (kDebugMode) debugPrint('🔧 M3U URL set to: $url');
    }
  }

  /// Load channels from local cache or fetch from remote
  static Future<List<Channel>> loadChannels({bool forceRefresh = false}) async {
    // Check if we have cached data
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    // Suppress unused variable warning
    assert(() { _lastFetchKey; return true; }());

    if (!forceRefresh && box.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Loading ${box.length} channels from cache');
      return box.values.toList();
    }

    // Fetch from remote
    if (kDebugMode) debugPrint('🔄 Fetching channels from remote...');
    return await _fetchFromRemote();
  }

  static Future<List<Channel>> _fetchFromRemote() async {
    try {
      // Use configured M3U URL (or default)
      final m3uUrl = await getM3uUrl();

      if (kDebugMode) debugPrint('📡 Connecting to M3U source: $m3uUrl');

      final response = await http.get(
        Uri.parse(m3uUrl),
        headers: {
          'User-Agent': 'AngoMovie/1.2.0 Android',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint('📊 Response status: ${response.statusCode}');
        debugPrint('📊 Response body length: ${response.body.length} bytes');
      }

      if (response.statusCode == 200) {
        final m3uContent = response.body;

        if (m3uContent.isEmpty) {
          throw Exception('M3U content is empty');
        }

        if (kDebugMode) debugPrint('🔍 Parsing M3U content...');
        final channels = M3uParser.parse(m3uContent);

        if (channels.isEmpty) {
          throw Exception('No channels parsed from M3U');
        }

        if (kDebugMode) debugPrint('✅ Parsed ${channels.length} channels');
        await _saveToCache(channels);
        return channels;
      } else {
        throw Exception('Failed to fetch M3U: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching from remote: $e');

      // Return cached data if available (stale but better than nothing)
      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      if (box.isNotEmpty) {
        if (kDebugMode) debugPrint('💾 Returning ${box.length} cached channels as fallback');
        return box.values.toList();
      }

      // No cache and no connection - throw error
      rethrow;
    }
  }

  static Future<void> _saveToCache(List<Channel> channels) async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    await box.clear();
    for (int i = 0; i < channels.length; i++) {
      await box.put(i, channels[i]);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    if (kDebugMode) debugPrint('💾 Saved ${channels.length} channels to cache');
  }

  static Future<void> clearCache() async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    await box.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastFetchKey);
    if (kDebugMode) debugPrint('🗑️ Cache cleared');
  }
}
