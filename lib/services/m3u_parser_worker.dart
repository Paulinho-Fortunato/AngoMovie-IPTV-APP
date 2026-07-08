// lib/services/m3u_parser_worker.dart
import 'dart:isolate';
import 'm3u_parser.dart';

/// Executa o parser pesado em segundo plano transferindo a configuração "ignoreVod"
Future<List<Map<String, String>>> parseM3uInIsolate(
  String content, {
  bool ignoreVod = false,
}) async {
  return await Isolate.run<List<Map<String, String>>>(() {
    return M3uParser.parseToMap(content, ignoreVod: ignoreVod);
  });
}
