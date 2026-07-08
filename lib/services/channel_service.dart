import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // Lista M3U principal do utilizador
  static const String _defaultM3uUrl =
      'https://raw.githubusercontent.com/Paulinho-Fortunato/Segundalista/refs/heads/main/z.m3u';
  static const String _m3uPrefKey = 'm3u_url';
  static const String _lastFetchKey = 'last_fetch_time';

  static Box<Channel>? _channelBox;
  static Box<dynamic>? _metaBox;

  /// Inicialização do Banco de Dados Hive
  static Future<void> initHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChannelAdapter());
    }
    _channelBox = await Hive.openBox<Channel>('channels');
    _metaBox = await Hive.openBox('channel_meta');
  }

  /// Retorna o link M3U configurado ou o padrão
  static Future<String> getM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3uPrefKey) ?? _defaultM3uUrl;
  }

  /// Salva um link M3U customizado
  static Future<void> setM3uUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_m3uPrefKey);
      if (kDebugMode) debugPrint('🔧 Link M3U restaurado para o padrão.');
    } else {
      await prefs.setString(_m3uPrefKey, url.trim());
      if (kDebugMode) debugPrint('🔧 Link M3U atualizado para: $url');
    }
  }

  /// Obtém metadados de cabeçalho do canal de forma rápida
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

  /// Carrega canais priorizando Cache Local (Rápido e Offline-First)
  static Future<List<Channel>> loadChannels({bool forceRefresh = false}) async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');

    if (!forceRefresh && box.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('✅ Base de dados carregada: ${box.length} canais obtidos via cache local.');
      }
      return box.values.toList();
    }

    // Se forçar atualização ou o cache estiver limpo, busca na nuvem
    return await _fetchFromRemote();
  }

  /// Efetua o download e parseamento ultra-veloz da lista remota
  static Future<List<Channel>> _fetchFromRemote() async {
    try {
      final m3uUrl = await getM3uUrl();

      if (kDebugMode) debugPrint('📡 Conectando com o servidor de IPTV: $m3uUrl');

      final response = await http.get(
        Uri.parse(m3uUrl),
        headers: {
          'User-Agent': 'AngoMovie/1.2.0 Android',
          'Accept-Encoding': 'gzip, deflate', // Solicita compactação para economizar dados
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final m3uContent = response.body;

        if (m3uContent.isEmpty) {
          throw Exception('O arquivo M3U obtido está vazio.');
        }

        // Parse inteligente da lista de canais
        final entries = M3uParser.parseToMap(m3uContent);
        
        // UX PRESERVADA: Descobre canais que já estavam marcados como favoritos
        final currentBox = _channelBox ?? await Hive.openBox<Channel>('channels');
        final Set<String> favoriteIds = currentBox.values
            .where((c) => c.isFavorite)
            .map((c) => c.id)
            .toSet();

        final List<Channel> channels = [];
        final Map<String, Map<String, String>> batchMeta = {};

        for (final entry in entries) {
          final ch = Channel.fromM3uEntry(entry);
          
          // Reatribui o status de favorito caso esse canal já fosse favoritado anteriormente
          if (favoriteIds.contains(ch.id)) {
            ch.isFavorite = true;
          }

          // Agrupa metadados do VLC para gravação otimizada em lote posterior
          final meta = <String, String>{};
          entry.forEach((k, v) {
            if (k.startsWith('vlc-')) meta[k] = v;
          });
          if (meta.isNotEmpty) {
            batchMeta[ch.id] = meta;
          }

          channels.add(ch);
        }

        if (channels.isEmpty) {
          throw Exception('Não foi possível identificar canais válidos neste arquivo M3U.');
        }

        // SALVAMENTO EM LOTE (BATCH WRITE): Grava toda a metadata de uma vez só
        if (batchMeta.isNotEmpty) {
          final metaBox = _metaBox ?? await Hive.openBox('channel_meta');
          await metaBox.putAll(batchMeta);
        }

        if (kDebugMode) {
          debugPrint('📊 Parseamento finalizado com sucesso. ${channels.length} canais estruturados.');
        }

        // Grava no cache de canais principal
        await _saveToCache(channels);
        return channels;
      } else {
        throw Exception('Servidor respondeu com erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erro no sincronismo de rede: $e');

      // Se falhar o download de rede (ex: Sem Internet), retorna o cache local de fallback de forma segura
      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      if (box.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('💾 Internet offline. Fallback ativado: ${box.length} canais carregados do cache.');
        }
        return box.values.toList();
      }

      rethrow;
    }
  }

  /// Grava a lista completa no banco de dados usando escrita otimizada em Lote (Batch Transaction)
  static Future<void> _saveToCache(List<Channel> channels) async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    
    // Limpa a base antiga de forma veloz
    await box.clear();

    // PERFORMANCE: Cria um mapa chave-valor para salvar todos os canais de uma única vez no disco
    final Map<String, Channel> batchMap = {
      for (final channel in channels) channel.id: channel
    };

    // Apenas uma escrita de I/O em lote na memória física
    await box.putAll(batchMap);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    
    if (kDebugMode) {
      debugPrint('💾 Cache sincronizado: ${channels.length} canais gravados em lote.');
    }
  }

  /// Remove o cache local de canais e metadados
  static Future<void> clearCache() async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    await box.clear();
    
    final metaBox = _metaBox ?? await Hive.openBox('channel_meta');
    await metaBox.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastFetchKey);
    
    if (kDebugMode) debugPrint('🗑️ Base de dados limpa com sucesso.');
  }
}
