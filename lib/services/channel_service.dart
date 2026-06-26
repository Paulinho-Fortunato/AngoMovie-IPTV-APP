import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // Backend URL - Use production URL or configurable endpoint
  // For development on Android emulator, use 10.0.2.2 to access localhost
  // For real devices, you need to use your computer's actual IP address or a public server
  static String get _backendBase {
    const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'AUTO');
    
    // If explicitly set via dart-define, use it
    if (backendUrl != 'AUTO') {
      return backendUrl; // Can be empty string '' to disable backend
    }
    
    // Default behavior: only try backend in debug mode
    if (kDebugMode) {
      // On emulator, 10.0.2.2 maps to host machine localhost
      return 'http://10.0.2.2:8000';
    }
    
    // In production/release builds, skip backend and go directly to M3U
    return '';
  }
  
  // Direct M3U URL as fallback (works on all devices if URL is publicly accessible)
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

      // Try backend proxy first (only in debug mode)
      final backendUrl = _backendBase;
      if (backendUrl.isNotEmpty) {
        try {
          if (kDebugMode) debugPrint('🌐 Trying backend: $backendUrl');
          final response = await http
              .get(
                Uri.parse('$backendUrl/api/channels'),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final List<dynamic> data = jsonDecode(response.body);
            final channels = data
                .map((e) => Channel.fromJson(e as Map<String, dynamic>))
                .toList();
            await _saveToCache(channels);
            return channels;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Backend failed: $e, falling back to M3U');
          // Backend not available, fall through to direct M3U fetch
        }
      }

      // Direct M3U fetch - this should work on real devices
      if (kDebugMode) debugPrint('📡 Fetching M3U directly: $_m3uDirectUrl');
      final response = await http.get(
        Uri.parse(_m3uDirectUrl),
        headers: {
          'User-Agent': 'AngoMovie/1.2.0 Android',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        m3uContent = response.body;
        if (kDebugMode) debugPrint('✅ M3U fetched successfully (${m3uContent.length} bytes)');
        final channels = M3uParser.parse(m3uContent);
        if (kDebugMode) debugPrint('📺 Parsed ${channels.length} channels');
        await _saveToCache(channels);
        return channels;
      }

      throw Exception('Falha ao carregar canais: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching channels: $e');
      // Return cached data if available (stale but better than nothing)
      try {
        final box = _channelBox ?? await Hive.openBox<Channel>('channels');
        if (box.isNotEmpty) {
          if (kDebugMode) debugPrint('⚠️ Returning ${box.length} cached channels');
          return box.values.toList();
        }
      } catch (_) {
        // Ignore cache errors
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
