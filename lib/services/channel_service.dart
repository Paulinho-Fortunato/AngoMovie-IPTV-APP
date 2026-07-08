// lib/services/channel_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser_worker.dart';

class ChannelService {
  // Lista M3U principal do utilizador
  static const String _defaultM3uUrl =
      'https://raw.githubusercontent.com/Paulinho-Fortunato/Segundalista/refs/heads/main/z.m3u';
  static const String _m3uPrefKey = 'm3u_url';
  static const String _lastFetchKey = 'last_fetch_time';
  static const String _hideVodPrefKey = 'hide_vod_streams';

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

  /// Retorna se o utilizador deseja ocultar filmes e séries (Default: false)
  static Future<bool> getHideVod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideVodPrefKey) ?? false;
  }

  /// Salva a preferência de ocultar/mostrar VOD
  static Future<void> setHideVod(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideVodPrefKey, value);
  }

  /// Retorna o link M3U configurado ou o padrão
  static Future<String> getM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3uPrefKey) ?? _defaultM3uUrl;
  }

  /// Inteligência de Rede: Corrige erros de digitação comuns de protocolos/portas de IPTV
  static String _normalizeUrl(String url) {
    var cleanedUrl = url.trim();
    
    // CORREÇÃO CRÍTICA: Se a URL contiver ":80" e começar com "https://", 
    // força a alteração para "http://" para evitar falhas de handshake SSL/TLS
    if (cleanedUrl.toLowerCase().startsWith('https://') && cleanedUrl.contains(':80/')) {
      cleanedUrl = cleanedUrl.replaceFirst(RegExp(r'https://', caseSensitive: false), 'http://');
      if (kDebugMode) {
        debugPrint('🔧 URL normalizada de HTTPS para HTTP para compatibilidade com a porta 80.');
      }
    }
    return cleanedUrl;
  }

  /// Salva um link M3U customizado
  static Future<void> setM3uUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_m3uPrefKey);
      if (kDebugMode) debugPrint('🔧 Link M3U restaurado para o padrão.');
    } else {
      final normalized = _normalizeUrl(url);
      await prefs.setString(_m3uPrefKey, normalized);
      if (kDebugMode) debugPrint('🔧 Link M3U configurado para: $normalized');
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

    return await _fetchFromRemote();
  }

  /// Efetua o download e parseamento ultra-veloz da lista remota em Isolate
  static Future<List<Channel>> _fetchFromRemote() async {
    try {
      final rawM3uUrl = await getM3uUrl();
      final m3uUrl = _normalizeUrl(rawM3uUrl); // Aplica a normalização inteligente
      final hideVod = await getHideVod();

      if (kDebugMode) {
        debugPrint('📡 Conectando ao servidor: $m3uUrl | Filtro de VOD: $hideVod');
      }

      // Aumentado o Timeout para 60 segundos para suportar listas Xtream gigantes (20MB+)
      final response = await http.get(
        Uri.parse(m3uUrl),
        headers: {
          'User-Agent': 'AngoMovie/1.2.0 Android',
          'Accept-Encoding': 'gzip, deflate',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final m3uContent = response.body;

        if (m3uContent.isEmpty) {
          throw Exception('O arquivo M3U obtido está vazio.');
        }

        // Envia para o Isolate Worker em segundo plano
        final entries = await parseM3uInIsolate(m3uContent, ignoreVod: hideVod);
        
        final currentBox = _channelBox ?? await Hive.openBox<Channel>('channels');
        final Set<String> favoriteIds = currentBox.values
            .where((c) => c.isFavorite)
            .map((c) => c.id)
            .toSet();

        final List<Channel> channels = [];
        final Map<String, Map<String, String>> batchMeta = {};

        for (final entry in entries) {
          final ch = Channel.fromM3uEntry(entry);
          
          if (favoriteIds.contains(ch.id)) {
            ch.isFavorite = true;
          }

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
          throw Exception('Nenhum canal compatível encontrado na sua lista.');
        }

        if (batchMeta.isNotEmpty) {
          final metaBox = _metaBox ?? await Hive.openBox('channel_meta');
          await metaBox.putAll(batchMeta);
        }

        if (kDebugMode) {
          debugPrint('📊 Sincronização finalizada. ${channels.length} conteúdos carregados.');
        }

        await _saveToCache(channels);
        return channels;
      } else {
        throw Exception('Servidor IPTV respondeu com erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erro no sincronismo de rede: $e');

      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      if (box.isNotEmpty) {
        return box.values.toList();
      }
      rethrow;
    }
  }

  /// Grava no disco em uma única transação rápida (Batch Write)
  static Future<void> _saveToCache(List<Channel> channels) async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    await box.clear();

    final Map<String, Channel> batchMap = {
      for (final channel in channels) channel.id: channel
    };

    await box.putAll(batchMap);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Limpa toda a base de dados
  static Future<void> clearCache() async {
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    await box.clear();
    
    final metaBox = _metaBox ?? await Hive.openBox('channel_meta');
    await metaBox.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastFetchKey);
  }
}
