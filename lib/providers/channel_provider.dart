// lib/providers/channel_provider.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:isolate';
import '../models/channel.dart';
import '../models/watch_history_entry.dart';
import '../services/channel_service.dart';
import '../services/local_media_store.dart';

enum LoadingState { idle, loading, success, error }

class ChannelProvider extends ChangeNotifier {
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Map<String, List<Channel>> _categorizedChannels = {};
  LoadingState _state = LoadingState.idle;
  String _errorMessage = '';
  String _searchQuery = '';
  Channel? _featuredChannel;
  List<WatchHistoryEntry> _watchHistory = [];
  
  int _loadedCategoriesCount = 0;
  int _categoriesPerBatch = 6; 
  Timer? _categoryLoadTimer;

  List<Channel> get allChannels => _allChannels;
  List<Channel> get filteredChannels => _searchQuery.isEmpty ? _allChannels : _filteredChannels;
  Map<String, List<Channel>> get categorizedChannels => _categorizedChannels;
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  Channel? get featuredChannel => _featuredChannel;
  List<WatchHistoryEntry> get watchHistory => List.unmodifiable(_watchHistory);
  bool get isLoading => _state == LoadingState.loading;
  bool get hasError => _state == LoadingState.error;
  bool get hasData => _allChannels.isNotEmpty;
  int get loadedCategoriesCount => _loadedCategoriesCount;

  /// Carrega os canais com Isolates e cria a categoria virtual de favoritos no topo
  Future<void> loadChannels({bool forceRefresh = false}) async {
    if (_state == LoadingState.loading) return;
    
    _state = LoadingState.loading;
    _errorMessage = '';
    _loadedCategoriesCount = 0;
    _categorizedChannels.clear();
    _categoryLoadTimer?.cancel();
    notifyListeners();

    try {
      final channels = await _loadChannelsSecure(forceRefresh);
      _allChannels = channels;
      await _restoreLocalMediaState(channels);
      _featuredChannel = channels.isNotEmpty ? channels.first : null;
      
      if (channels.isNotEmpty) {
        _startLazyCategoryLoading(channels);
      }
      
      _state = LoadingState.success;
    } catch (e, stack) {
      _errorMessage = 'Não foi possível carregar os canais. Verifique a sua conexão.';
      _state = LoadingState.error;
      if (kDebugMode) {
        debugPrint('❌ Erro crítico no ChannelProvider: $e\n$stack');
      }
    }

    notifyListeners();
  }

  /// Restores Room-backed favorites/history after the channel cache is loaded.
  /// A Room outage must not prevent the cached playlist from being used.
  Future<void> _restoreLocalMediaState(List<Channel> channels) async {
    final legacyFavoriteIds = channels
        .where((channel) => channel.isFavorite)
        .map((channel) => channel.id)
        .toSet();
    var legacyMigrationCompleted = false;
    try {
      await LocalMediaStore.migrateLegacyFavorites(channels);
      legacyMigrationCompleted = true;
    } catch (error) {
      if (kDebugMode) debugPrint('Migração de favoritos locais falhou: $error');
    }

    try {
      final favoriteIds = await LocalMediaStore.getFavoriteIds();
      // Keep pre-Room favorites visible if their one-time import could not finish.
      if (!legacyMigrationCompleted) favoriteIds.addAll(legacyFavoriteIds);
      for (final channel in channels) {
        channel.isFavorite = favoriteIds.contains(channel.id);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Leitura de favoritos locais falhou: $error');
    }

    await loadWatchHistory(notify: false);
  }

  Future<void> loadWatchHistory({bool notify = true}) async {
    try {
      _watchHistory = await LocalMediaStore.getWatchHistory();
      if (notify) notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('Leitura do histórico local falhou: $error');
    }
  }

  /// Adds a channel to the history only after the player reports playback.
  Future<void> recordPlayback(Channel channel) async {
    try {
      final entry = await LocalMediaStore.recordPlayback(channel);
      _watchHistory = <WatchHistoryEntry>[
        entry,
        ..._watchHistory.where((item) => item.channelId != entry.channelId),
      ].take(100).toList(growable: false);
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('Gravação do histórico local falhou: $error');
    }
  }

  Future<void> clearWatchHistory() async {
    try {
      await LocalMediaStore.clearWatchHistory();
      _watchHistory = [];
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('Limpeza do histórico local falhou: $error');
      rethrow;
    }
  }

  /// Gerenciamento inteligente de Isolates para evitar bloqueios de UI
  Future<List<Channel>> _loadChannelsSecure(bool forceRefresh) async {
    if (!forceRefresh) {
      final cached = await ChannelService.loadChannels(forceRefresh: false);
      if (cached.isNotEmpty) return cached;
    }

    try {
      return await Isolate.run<List<Channel>>(() async {
        return await ChannelService.loadChannels(forceRefresh: true);
      }).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('O carregamento da lista expirou.'),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha no Isolate. Rodando fallback na Main Thread: $e');
      }
      return await ChannelService.loadChannels(forceRefresh: forceRefresh);
    }
  }

  /// Otimização Algorítmica O(N) com injeção automática de Favoritos no topo
  void _startLazyCategoryLoading(List<Channel> channels) {
    _categoryLoadTimer?.cancel();

    final Map<String, List<Channel>> groupedMap = {};
    for (final channel in channels) {
      final category = channel.groupTitle.isEmpty ? 'Sem Categoria' : channel.groupTitle;
      (groupedMap[category] ??= []).add(channel);
    }

    final sortedCategories = groupedMap.keys.toList()..sort();

    // CATEGORIA VIRTUAL: Se houver canais favoritados, coloca no topo
    final favorites = channels.where((c) => c.isFavorite).toList();
    if (favorites.isNotEmpty) {
      groupedMap['★ Favoritos'] = favorites;
      sortedCategories.insert(0, '★ Favoritos');
    }

    _loadBatchOfCategories(groupedMap, sortedCategories, 0);
  }

  void _loadBatchOfCategories(
    Map<String, List<Channel>> groupedChannels,
    List<String> sortedCategories,
    int startIndex,
  ) {
    final endIndex = (startIndex + _categoriesPerBatch).clamp(0, sortedCategories.length);

    for (int i = startIndex; i < endIndex; i++) {
      final category = sortedCategories[i];
      _categorizedChannels[category] = groupedChannels[category] ?? [];
      _loadedCategoriesCount++;
    }

    notifyListeners();

    if (endIndex < sortedCategories.length) {
      _categoryLoadTimer = Timer(const Duration(milliseconds: 60), () {
        _loadBatchOfCategories(groupedChannels, sortedCategories, endIndex);
      });
    }
  }

  /// Persists the favorite in Room on Android, then updates the virtual category.
  Future<void> toggleFavorite(Channel channel) async {
    try {
      channel.isFavorite = await LocalMediaStore.toggleFavorite(channel);
      _updateFavoritesInMap();
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('Não foi possível guardar o favorito: $error');
    }
  }

  /// Rebuilds the virtual category first so favorites always remain at the top.
  void _updateFavoritesInMap() {
    final favorites = _allChannels.where((channel) => channel.isFavorite).toList();
    final updated = <String, List<Channel>>{};

    if (favorites.isNotEmpty) updated['★ Favoritos'] = favorites;
    for (final entry in _categorizedChannels.entries) {
      if (entry.key != '★ Favoritos') updated[entry.key] = entry.value;
    }
    _categorizedChannels = updated;
  }

  void loadAllCategories() {
    if (_allChannels.isEmpty) return;
    
    _categoryLoadTimer?.cancel();
    final Map<String, List<Channel>> groupedMap = {};
    
    for (final channel in _allChannels) {
      final category = channel.groupTitle.isEmpty ? 'Sem Categoria' : channel.groupTitle;
      (groupedMap[category] ??= []).add(channel);
    }

    final favorites = _allChannels.where((c) => c.isFavorite).toList();
    final orderedCategories = <String, List<Channel>>{};
    if (favorites.isNotEmpty) orderedCategories['★ Favoritos'] = favorites;
    orderedCategories.addAll(groupedMap);
    _categorizedChannels = orderedCategories;
    _loadedCategoriesCount = _categorizedChannels.length;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _filteredChannels = [];
    } else {
      final cleanQuery = _searchQuery.toLowerCase();
      _filteredChannels = _allChannels.where((channel) {
        final nameMatch = channel.name.toLowerCase().contains(cleanQuery);
        final categoryMatch = channel.groupTitle.toLowerCase().contains(cleanQuery);
        return nameMatch || categoryMatch;
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredChannels = [];
    notifyListeners();
  }

  Future<void> refreshChannels() async {
    await loadChannels(forceRefresh: true);
  }

  @override
  void dispose() {
    _categoryLoadTimer?.cancel();
    super.dispose();
  }
}
