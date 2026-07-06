import '../models/channel.dart';

class M3uParser {
  // Keywords to EXCLUDE from live TV (filter out VOD/Movies/Series)
  static const List<String> _excludedKeywords = [
    'FILME',
    'SERIE',
    'VOD',
    'MOVIE',
    'EPISODIO',
    'TEMPORADA',
    'DESENHO',
    'ANIME',
    'SERIES',
    'FILMES',
    'MOVIES',
  ];

  /// Parse M3U content into a list of Channel objects (synchronous).
  /// This method is kept for compatibility but for large M3U files you should
  /// call [parseToMap] inside a background isolate and then convert to Channel.
  static List<Channel> parse(String content) {
    final maps = parseToMap(content);
    return maps.map((m) => Channel.fromM3uEntry(m)).toList();
  }

  /// Parse M3U content into a list of simple Maps. This function is
  /// suitable for running inside a background isolate via compute().
  ///
  /// Improvements:
  /// - Accept entries that have a URL without a preceding #EXTINF
  /// - Collect #EXTVLCOPT options that appear between EXTINF and URL and
  ///   include them in the resulting map (prefixed with 'vlc-')
  /// - Be tolerant to missing metadata and different line endings
  static List<Map<String, String>> parseToMap(String content) {
    final List<Map<String, String>> channels = [];

    if (content.trim().isEmpty) return channels;

    final lines = content.replaceAll('\r', '').split('\n');

    String? currentExtInf;
    final Map<String, String> currentVlcOpts = {};

    for (int i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // New EXTINF metadata block
        currentExtInf = line;
        currentVlcOpts.clear();
      } else if (line.startsWith('#EXTVLCOPT:')) {
        // VLC specific options sometimes appear between EXTINF and the real URL
        // Format: #EXTVLCOPT:key=value
        final opt = line.substring('#EXTVLCOPT:'.length);
        final eq = opt.indexOf('=');
        if (eq != -1) {
          final key = opt.substring(0, eq).trim();
          final value = opt.substring(eq + 1).trim();
          // store with prefix to avoid collision with other keys
          currentVlcOpts['vlc-${key}'] = value;
        } else {
          currentVlcOpts['vlc-${opt.trim()}'] = '';
        }
      } else if (line.startsWith('#')) {
        // Other comments - ignore
        continue;
      } else {
        // Non-comment, non-empty line -> assume this is a URL
        final url = line;

        Map<String, String> entry;
        if (currentExtInf != null) {
          entry = _parseExtInf(currentExtInf, url);
        } else {
          // No EXTINF: create minimal entry from URL
          entry = _parseUrlOnly(url);
        }

        // Merge any VLC opts collected for this entry
        if (currentVlcOpts.isNotEmpty) {
          for (final k in currentVlcOpts.keys) {
            entry[k] = currentVlcOpts[k]!;
          }
        }

        // Decide whether to include (live TV) before adding
        final group = (entry['group-title'] ?? 'Geral').toUpperCase();
        if (_isLiveTv(group)) {
          channels.add(entry);
        }

        // Reset state for next entry
        currentExtInf = null;
        currentVlcOpts.clear();
      }
    }

    return channels;
  }

  static bool _isLiveTv(String groupTitle) {
    final upper = groupTitle.toUpperCase();
    for (final keyword in _excludedKeywords) {
      if (upper.contains(keyword)) return false;
    }
    return true;
  }

  static Map<String, String> _parseExtInf(String extInf, String url) {
    final Map<String, String> result = {'url': url};

    // Extract attributes like tvg-id, tvg-name, tvg-logo, group-title
    // Matches key="value"
    final attrRegex = RegExp(r'(\S+)="([^"]*)"');
    for (final match in attrRegex.allMatches(extInf)) {
      result[match.group(1)!] = match.group(2)!;
    }

    // Extract channel name (after the last comma)
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex != -1) {
      result['name'] = extInf.substring(commaIndex + 1).trim();
      if (result['tvg-name'] == null || result['tvg-name']!.isEmpty) {
        result['tvg-name'] = result['name']!;
      }
    }

    // Normalize keys used by Channel.fromM3uEntry
    result['group-title'] = result['group-title'] ?? result['group_title'] ?? 'Geral';
    result['tvg-logo'] = result['tvg-logo'] ?? result['tvg_logo'] ?? '';
    result['tvg-id'] = result['tvg-id'] ?? result['tvg_id'] ?? '';

    return result;
  }

  static Map<String, String> _parseUrlOnly(String url) {
    final Map<String, String> result = {'url': url};

    // Derive a friendly name from the URL path or host
    try {
      final uri = Uri.parse(url);
      String name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;
      // remove query and file extension hints
      name = name.replaceAll(RegExp(r'\.(m3u8?|mp4|ts)$', caseSensitive: false), '');
      if (name.isEmpty) name = uri.host;
      result['name'] = name;
      result['tvg-name'] = name;
      result['group-title'] = 'Geral';
      result['tvg-logo'] = '';
      result['tvg-id'] = '';
    } catch (_) {
      result['name'] = url;
      result['tvg-name'] = url;
      result['group-title'] = 'Geral';
      result['tvg-logo'] = '';
      result['tvg-id'] = '';
    }

    return result;
  }

  static Map<String, List<Channel>> groupByCategory(List<Channel> channels) {
    final Map<String, List<Channel>> grouped = {};
    for (final channel in channels) {
      final key = channel.groupTitle.toUpperCase();
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(channel);
    }
    return grouped;
  }
}
