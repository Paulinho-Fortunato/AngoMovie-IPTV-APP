import 'dart:convert';
import '../models/channel.dart';

class M3uParser {
  // Regex compilada uma única vez para mapear os atributos (tvg-id, group-title, etc.)
  static final RegExp _attrRegex = RegExp(r'(\S+)\s*=\s*"([^"]*)"');

  // Regex inteligente com "word boundary" (\b) para filtrar VOD/Filmes sob demanda 
  // sem excluir canais de TV ao vivo como "HBO Filmes" ou "Telecine Filmes"
  static final RegExp _vodFilterRegex = RegExp(
    r'\b(VOD|MOVIE|EPISODIO|TEMPORADA|ANIME|EPISODIOS|VODS|MOVIES)\b',
    caseSensitive: false,
  );

  /// Converte o conteúdo do M3U em uma lista de objetos Channel de forma síncrona
  static List<Channel> parse(String content) {
    final maps = parseToMap(content);
    return maps.map((m) => Channel.fromM3uEntry(m)).toList();
  }

  /// Converte o arquivo M3U em um mapa de alta performance
  static List<Map<String, String>> parseToMap(String content) {
    final List<Map<String, String>> channels = [];

    if (content.trim().isEmpty) return channels;

    // PERFORMANCE: LineSplitter nativo do Dart evita duplicação de strings na memória RAM
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
        // Captura opções personalizadas do VLC (Headers, User-Agent, etc.)
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
        // Ignora outros comentários do arquivo
        continue;
      } else {
        // Linha sem comentário -> Assume-se que seja a URL do fluxo de vídeo
        final url = line;

        Map<String, String> entry;
        if (currentExtInf != null) {
          entry = _parseExtInf(currentExtInf, url);
        } else {
          entry = _parseUrlOnly(url);
        }

        // Mescla as opções de VLC associadas ao canal
        if (currentVlcOpts.isNotEmpty) {
          entry.addAll(currentVlcOpts);
        }

        // Filtro de canais ao vivo (Exclui VODs puros mas preserva canais de TV de Filmes)
        final group = entry['group-title'] ?? 'Geral';
        if (_isLiveTv(group)) {
          channels.add(entry);
        }

        currentExtInf = null;
        currentVlcOpts.clear();
      }
    }

    return channels;
  }

  /// Verifica se a categoria do canal corresponde a TV Ao Vivo ou VOD puro
  static bool _isLiveTv(String groupTitle) {
    // Se a categoria contiver a palavra exata "VOD", "MOVIE", "TEMPORADA", etc., é excluída.
    // Categorias como "Canais de Filmes" ou "Telecine Filmes" passam sem problemas.
    return !_vodFilterRegex.hasMatch(groupTitle);
  }

  /// Efetua o mapeamento das propriedades usando a Regex pré-compilada
  static Map<String, String> _parseExtInf(String extInf, String url) {
    final Map<String, String> result = {'url': url};

    // PERFORMANCE: Uso da Regex estática pré-compilada (Até 90% mais rápido)
    final matches = _attrRegex.allMatches(extInf);
    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        result[key] = value;
      }
    }

    // Extrai o nome amigável do canal após a última vírgula
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex != -1) {
      final name = extInf.substring(commaIndex + 1).trim();
      result['name'] = name;
      if (result['tvg-name'] == null || result['tvg-name']!.isEmpty) {
        result['tvg-name'] = name;
      }
    }

    // Normalização rápida de chaves
    result['group-title'] = result['group-title'] ?? result['group_title'] ?? 'Geral';
    result['tvg-logo'] = result['tvg-logo'] ?? result['tvg_logo'] ?? '';
    result['tvg-id'] = result['tvg-id'] ?? result['tvg_id'] ?? '';

    return result;
  }

  /// Gera metadados temporários caso o canal venha apenas com a URL no arquivo
  static Map<String, String> _parseUrlOnly(String url) {
    final Map<String, String> result = {'url': url};

    try {
      final uri = Uri.parse(url);
      String name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;
      
      // Remove extensões de arquivo comuns
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
