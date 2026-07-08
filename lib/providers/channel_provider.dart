// lib/providers/channel_provider.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:isolate';
import '../models/channel.dart';
import '../services/channel_service.dart';

enum LoadingState { idle, loading, success, error }

class ChannelProvider extends ChangeNotifier {
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Map<String, List<Channel>> _categorizedChannels = {};
  LoadingState _state = LoadingState.idle;
  String _errorMessage = '';
  String _searchQuery = '';
  Channel? _featuredChannel;
  
  int _loadedCategoriesCount = 0;
  int _categoriesPerBatch = 6; 
  Timer? _categoryLoadTimer;

  List<Channel> get allChannels => _allChannels;
  List<Channel> get filteredChannels => _searchQuery.isEmpty ? _allChannels : _filteredChannels;
  Map<String, List<Channel>> get categorizedChannels => _categorizedChannels;
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  Channel? get featuredChannel => _featuredChannel;
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

  /// Alterna o estado de favoritos de forma instantânea e atualiza a categoria virtual
  Future<void> toggleFavorite(Channel channel) async {
    channel.isFavorite = !channel.isFavorite;
    await channel.save(); // Salva de forma síncrona no Hive
    
    _updateFavoritesInMap();
    notifyListeners();
  }

  /// Atualiza apenas a categoria virtual sem precisar reconstruir toda a estrutura do app
  void _updateFavoritesInMap() {
    final favorites = _allChannels.where((c) => c.isFavorite).toList();
    
    if (favorites.isNotEmpty) {
      _categorizedChannels['★ Favoritos'] = favorites;
      
      // Garante que os favoritos apareçam na primeira posição
      if (!_categorizedChannels.containsKey('★ Favoritos')) {
        final Map<String, List<Channel>> tempMap = {'★ Favoritos': favorites};
        tempMap.addAll(_categorizedChannels);
        _categorizedChannels = tempMap;
      }
    } else {
      // Se não houver nenhum favorito ativo, remove a categoria virtual do ecrã
      _categorizedChannels.remove('★ Favoritos');
    }
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
    if (favorites.isNotEmpty) {
      _categorizedChannels['★ Favoritos'] = favorites;
    }

    _categorizedChannels.addAll(groupedMap);
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
