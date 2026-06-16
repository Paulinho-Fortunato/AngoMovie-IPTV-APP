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
  /// call [parseToMap] inside a compute isolate and then convert to Channel.
  static List<Channel> parse(String content) {
    final maps = parseToMap(content);
    return maps.map((m) => Channel.fromM3uEntry(m)).toList();
  }

  /// Parse M3U content into a list of simple Maps. This function is
  /// suitable for running inside a background isolate via compute().
  static List<Map<String, String>> parseToMap(String content) {
    final List<Map<String, String>> channels = [];
    final lines = content.split('\n');

    String? currentExtInf;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
      } else if (line.isNotEmpty && !line.startsWith('#') && currentExtInf != null) {
        final entry = _parseExtInf(currentExtInf, line);

        // Decide whether to include (live TV) before adding
        final group = (entry['group-title'] ?? 'Geral').toUpperCase();
        if (_isLiveTv(group)) {
          channels.add(entry);
        }

        currentExtInf = null;
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
