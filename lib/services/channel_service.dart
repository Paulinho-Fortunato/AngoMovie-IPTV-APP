import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // Default M3U source URL - updated to use the raw primary list provided by the user
  static const String _defaultM3uUrl =
      'https://raw.githubusercontent.com/Paulinho-Fortunato/Segundalista/refs/heads/main/z.m3u';
  static const String _m3uPrefKey = 'm3u_url';

  static const String _lastFetchKey = 'last_fetch_time';

  static Box<Channel>? _channelBox;
  static Box<dynamic>? _metaBox;

  static Future<void> initHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChannelAdapter());
    }
    _channelBox = await Hive.openBox<Channel>('channels');
    // Separate box to store per-channel metadata (vlc opts, headers, etc.)
    _metaBox = await Hive.openBox('channel_meta');
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

  /// Get per-channel metadata (vlc opts / headers)
  static Future<Map<String, String>> getChannelMeta(String channelId) async {
    final box = _metaBox ?? await Hive.openBox('channel_meta');
    final raw = box.get(channelId);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(raw as Map);
    } catch (_) {
      return {};
    }
  }

  /// Set per-channel metadata (vlc opts / headers)
  static Future<void> setChannelMeta(String channelId, Map<String, String> meta) async {
    final box = _metaBox ?? await Hive.openBox('channel_meta');
    await box.put(channelId, meta);
    if (kDebugMode) debugPrint('🔧 Saved metadata for channel $channelId');
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

  /// Fetch remote M3U on the main thread and parse in an isolate to avoid plugin calls in isolates.
  static Future<List<Channel>> _fetchFromRemote() async {
    try {
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

        // Parse entries to map first (so we keep vlc opts available)
        final entries = M3uParser.parseToMap(m3uContent);
        final List<Channel> channels = [];

        for (final entry in entries) {
          // create initial channel from entry
          final ch = Channel.fromM3uEntry(entry);
          String finalUrl = ch.streamUrl;

          // If the URL points to another playlist (.m3u8/.m3u), try to fetch it and extract a real stream
          if (finalUrl.toLowerCase().endsWith('.m3u8') || finalUrl.toLowerCase().endsWith('.m3u')) {
            try {
              final nestedResp = await http.get(Uri.parse(finalUrl)).timeout(const Duration(seconds: 20));
              if (nestedResp.statusCode == 200 && nestedResp.body.isNotEmpty) {
                final nestedBody = nestedResp.body;

                // If nested playlist is a master (EXT-X-STREAM-INF), parse variants and prefer one with audio codecs
                if (nestedBody.contains('#EXT-X-STREAM-INF')) {
                  final selected = _selectVariantWithAudio(nestedBody, baseUrl: finalUrl);
                  if (selected != null) {
                    finalUrl = selected;
                  } else {
                    // fallback: parse first entry url from nested
                    final nested = M3uParser.parseToMap(nestedBody);
                    if (nested.isNotEmpty && nested.first['url'] != null && nested.first['url']!.isNotEmpty) {
                      finalUrl = _resolveUrl(finalUrl, nested.first['url']!);
                    }
                  }
                } else {
                  // Not a master playlist; parse as media playlist and take first media URL if present
                  final nested = M3uParser.parseToMap(nestedBody);
                  if (nested.isNotEmpty && nested.first['url'] != null && nested.first['url']!.isNotEmpty) {
                    finalUrl = _resolveUrl(finalUrl, nested.first['url']!);
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) debugPrint('Nested playlist fetch failed for $finalUrl: $e');
            }
          }

          // Save VLC options (vlc-*) into meta storage for this channel id
          final meta = <String, String>{};
          entry.forEach((k, v) {
            if (k.startsWith('vlc-')) meta[k] = v;
          });
          if (meta.isNotEmpty) {
            await setChannelMeta(ch.id, meta);
          }

          // Create a channel instance using finalUrl
          final updated = Channel(
            id: ch.id,
            name: ch.name,
            streamUrl: finalUrl,
            logoUrl: ch.logoUrl,
            groupTitle: ch.groupTitle,
            tvgId: ch.tvgId,
            isHttpStream: finalUrl.startsWith('http://'),
          );

          channels.add(updated);
        }

        if (channels.isEmpty) {
          throw Exception('No channels parsed from M3U');
        }

        if (kDebugMode) debugPrint('✅ Parsed ${channels.length} channels (including nested playlists)');
        await _saveToCache(channels);
        return channels;
      } else {
        throw Exception('Failed to fetch M3U: HTTP ${response.statusCode}. Body: ${response.body.length} bytes');
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

  /// Selects a variant URL from a master playlist body that likely contains audio.
  /// Prefers variants whose CODECS includes an audio codec (mp4a, aac) or that
  /// explicitly include an AUDIO group. Returns resolved absolute URL or null.
  static String? _selectVariantWithAudio(String masterBody, {required String baseUrl}) {
    final lines = masterBody.replaceAll('\r', '').split('\n');
    final variants = <Map<String, String>>[]; // each item: {attrs:..., url:...}

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attrsLine = line.substring('#EXT-X-STREAM-INF:'.length);
        String url = '';
        // next non-empty, non-comment line is the URL
        for (int j = i + 1; j < lines.length; j++) {
          final candidate = lines[j].trim();
          if (candidate.isEmpty) continue;
          if (candidate.startsWith('#')) continue;
          url = candidate;
          break;
        }
        if (url.isNotEmpty) {
          variants.add({'attrs': attrsLine, 'url': url});
        }
      }
    }

    if (variants.isEmpty) return null;

    // try to find variant with audio codec in CODECS or with AUDIO attribute
    for (final v in variants) {
      final attrs = v['attrs'] ?? '';
      final codecsMatch = RegExp(r'CODECS=\"?([^\",]+)\"?', caseSensitive: false).firstMatch(attrs);
      if (codecsMatch != null) {
        final codecs = codecsMatch.group(1) ?? '';
        final lower = codecs.toLowerCase();
        if (lower.contains('mp4a') || lower.contains('aac') || lower.contains('ac-3') || lower.contains('ec-3')) {
          return _resolveUrl(baseUrl, v['url']!);
        }
      }
      final audioMatch = RegExp(r'AUDIO=([^,]+)', caseSensitive: false).firstMatch(attrs);
      if (audioMatch != null) {
        return _resolveUrl(baseUrl, v['url']!);
      }
    }

    // fallback: return first variant resolved
    return _resolveUrl(baseUrl, variants.first['url']!);
  }

  /// Resolve possibly relative variantUrl against base playlist URL
  static String _resolveUrl(String basePlaylistUrl, String variantUrl) {
    try {
      final base = Uri.parse(basePlaylistUrl);
      final resolved = base.resolve(variantUrl).toString();
      return resolved;
    } catch (_) {
      return variantUrl;
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
