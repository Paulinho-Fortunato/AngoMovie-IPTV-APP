import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // M3U source URL - Direct URL only (backend was causing issues on real devices)
  static const String _m3uDirectUrl =
      'http://nitidez.pro:80/get.php?username=Marcio&password=123456&type=m3u_plus';

  static const String _lastFetchKey = 'last_fetch_time';

  static Box<Channel>? _channelBox;

  static Future<void> initHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChannelAdapter());
    }
    _channelBox = await Hive.openBox<Channel>('channels');
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
      // Direct M3U fetch from nitidez.pro
      if (kDebugMode) debugPrint('📡 Connecting to M3U source: $_m3uDirectUrl');
      
      final response = await http.get(
        Uri.parse(_m3uDirectUrl),
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
