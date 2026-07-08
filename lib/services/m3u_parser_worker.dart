// lib/services/m3u_parser_worker.dart
import 'dart:isolate';
import 'm3u_parser.dart';

/// Executa o parser pesado do arquivo M3U em uma linha de execução separada (Isolate).
///
/// Isso evita por completo micro-travamentos (jank) na interface do usuário (UI),
/// mesmo se o arquivo M3U contiver dezenas de milhares de canais ativos.
Future<List<Map<String, String>>> parseM3uInIsolate(String content) async {
  // Isolate.run é a API moderna de concorrência do Flutter (altamente otimizada para zero-copy)
  return await Isolate.run<List<Map<String, String>>>(() {
    // Roda a extração Regex e LineSplitter em segundo plano
    return M3uParser.parseToMap(content);
  });
}
