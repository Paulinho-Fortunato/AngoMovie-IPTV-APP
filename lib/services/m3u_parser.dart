// lib/services/m3u_parser.dart
import 'dart:convert';
import '../models/channel.dart';

class M3uParser {
  static final RegExp _attrRegex = RegExp(r'(\S+)\s*=\s*"([^"]*)"');

  // Filtro de VOD aperfeiçoado para remover apenas quando solicitado
  static final RegExp _vodFilterRegex = RegExp(
    r'\b(VOD|MOVIE|EPISODIO|TEMPORADA|ANIME|EPISODIOS|VODS|MOVIES|S01|S02|S03|S04|S05|NOVELA)\b',
    caseSensitive: false,
  );

  static List<Channel> parse(String content, {bool ignoreVod = false}) {
    final maps = parseToMap(content, ignoreVod: ignoreVod);
    return maps.map((m) => Channel.fromM3uEntry(m)).toList();
  }

  static List<Map<String, String>> parseToMap(String content, {bool ignoreVod = false}) {
    final List<Map<String, String>> channels = [];
    if (content.trim().isEmpty) return channels;

    final lines = const LineSplitter().convert(content);
    String? currentExtInf;
    final Map<String, String> currentVlcOpts = {};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
        currentVlcOpts.clear();
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring('#EXTVLCOPT:'.length);
        final eq = opt.indexOf('=');
        if (eq != -1) {
          final key = opt.substring(0, eq).trim();
          final value = opt.substring(eq + 1).trim();
          currentVlcOpts['vlc-$key'] = value;
        } else {
          currentVlcOpts['vlc-${opt.trim()}'] = '';
        }
      } else if (line.startsWith('#')) {
        continue;
      } else {
        final url = line;
        Map<String, String> entry = currentExtInf != null 
            ? _parseExtInf(currentExtInf, url) 
            : _parseUrlOnly(url);

        if (currentVlcOpts.isNotEmpty) {
          entry.addAll(currentVlcOpts);
        }

        final group = entry['group-title'] ?? 'Geral';
        
        // DECISÃO DINÂMICA: Se "ignoreVod" for falso, adiciona tudo. 
        // Se for verdadeiro, aplica o filtro de TV ao vivo.
        if (!ignoreVod || _isLiveTv(group)) {
          channels.add(entry);
        }

        currentExtInf = null;
        currentVlcOpts.clear();
      }
    }
    return channels;
  }

  static bool _isLiveTv(String groupTitle) {
    return !_vodFilterRegex.hasMatch(groupTitle);
  }

  static Map<String, String> _parseExtInf(String extInf, String url) {
    final Map<String, String> result = {'url': url};
    final matches = _attrRegex.allMatches(extInf);
    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        result[key] = value;
      }
    }

    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex != -1) {
      final name = extInf.substring(commaIndex + 1).trim();
      result['name'] = name;
      if (result['tvg-name'] == null || result['tvg-name']!.isEmpty) {
        result['tvg-name'] = name;
      }
    }

    result['group-title'] = result['group-title'] ?? result['group_title'] ?? 'Geral';
    result['tvg-logo'] = result['tvg-logo'] ?? result['tvg_logo'] ?? '';
    result['tvg-id'] = result['tvg-id'] ?? result['tvg_id'] ?? '';
    return result;
  }

  static Map<String, String> _parseUrlOnly(String url) {
    final Map<String, String> result = {'url': url};
    try {
      final uri = Uri.parse(url);
      String name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;
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
}
