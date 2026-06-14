import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // M3U source URL - fetched via backend proxy for security
  static const String _backendBase = 'http://10.0.2.2:8000';
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
      if (kDebugMode) debugPrint('Loading ${box.length} channels from cache');
      return box.values.toList();
    }

    // Fetch from remote
    return await _fetchFromRemote();
  }

  static Future<List<Channel>> _fetchFromRemote() async {
    try {
      String m3uContent = '';

      // Try backend proxy first, then direct URL
      try {
        final response = await http
            .get(
              Uri.parse('$_backendBase/api/channels'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final channels = data
              .map((e) => Channel.fromJson(e as Map<String, dynamic>))
              .toList();
          await _saveToCache(channels);
          return channels;
        }
      } catch (_) {
        // Backend not available, fall through to direct M3U fetch
      }

      // Direct M3U fetch
      final response = await http.get(
        Uri.parse(_m3uDirectUrl),
        headers: {
          'User-Agent': 'AngoMovie/1.2.0 Android',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        m3uContent = response.body;
        final channels = M3uParser.parse(m3uContent);
        await _saveToCache(channels);
        return channels;
      }

      throw Exception('Falha ao carregar canais: ${response.statusCode}');
    } catch (e) {
      // Return cached data if available (stale but better than nothing)
      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      if (box.isNotEmpty) {
        return box.values.toList();
      }
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
    if (kDebugMode) debugPrint('Saved ${channels.length} channels to cache');
  }

  static Future<void> clearCache() async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    await box.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastFetchKey);
  }
}
