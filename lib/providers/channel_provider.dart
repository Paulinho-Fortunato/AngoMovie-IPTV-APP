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
  
  // Controle de Lazy Loading de Alta Performance
  int _loadedCategoriesCount = 0;
  int _categoriesPerBatch = 6; 
  Timer? _categoryLoadTimer;

  // Getters Públicos
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

  /// Carrega os canais usando Isolates reais para tarefas pesadas e categorização O(N)
  Future<void> loadChannels({bool forceRefresh = false}) async {
    if (_state == LoadingState.loading) return;
    
    _state = LoadingState.loading;
    _errorMessage = '';
    _loadedCategoriesCount = 0;
    _categorizedChannels.clear();
    _categoryLoadTimer?.cancel();
    notifyListeners();

    try {
      // 1. Carrega os canais (Se for leitura local do Hive, é instantâneo na main thread. 
      // Se for download/parse de M3U pesado, o Isolate real é invocado)
      final channels = await _loadChannelsSecure(forceRefresh);
      
      _allChannels = channels;
      _featuredChannel = channels.isNotEmpty ? channels.first : null;
      
      if (channels.isNotEmpty) {
        // 2. Prepara o lazy loading de categorias com performance O(N)
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
    // Se não for forçar atualização, tenta carregar do cache local (rápido, main thread)
    if (!forceRefresh) {
      final cached = await ChannelService.loadChannels(forceRefresh: false);
      if (cached.isNotEmpty) return cached;
    }

    // Se precisar atualizar M3U externo (pesado), executa em Isolate real usando a API moderna do Dart
    try {
      return await Isolate.run<List<Channel>>(() async {
        // Isolate.run inicializa corretamente os contextos básicos necessários
        return await ChannelService.loadChannels(forceRefresh: true);
      }).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('O carregamento da lista de canais expirou.'),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Falha no Isolate. Rodando fallback seguro na Main Thread: $e');
      }
      // Fallback de segurança na thread principal caso o dispositivo rejeite Isolates secundários
      return await ChannelService.loadChannels(forceRefresh: forceRefresh);
    }
  }

  /// Otimização Algorítmica O(N): Agrupa todos os canais por categoria em uma única passada
  void _startLazyCategoryLoading(List<Channel> channels) {
    _categoryLoadTimer?.cancel();

    // Criação do Mapa Hash em tempo linear O(N)
    final Map<String, List<Channel>> groupedMap = {};
    for (final channel in channels) {
      final category = channel.groupTitle.isEmpty ? 'Sem Categoria' : channel.groupTitle;
      (groupedMap[category] ??= []).add(channel);
    }

    // Obtém as chaves ordenadas alfabeticamente
    final sortedCategories = groupedMap.keys.toList()..sort();

    // Dispara a entrega dos lotes para a UI
    _loadBatchOfCategories(groupedMap, sortedCategories, 0);
  }

  /// Processa a entrega de lotes de forma instantânea, eliminando filtros pesados dentro do Timer
  void _loadBatchOfCategories(
    Map<String, List<Channel>> groupedChannels,
    List<String> sortedCategories,
    int startIndex,
  ) {
    final endIndex = (startIndex + _categoriesPerBatch).clamp(0, sortedCategories.length);

    for (int i = startIndex; i < endIndex; i++) {
      final category = sortedCategories[i];
      // A atribuição aqui é O(1) (Apenas aponta referências na memória)
      _categorizedChannels[category] = groupedChannels[category] ?? [];
      _loadedCategoriesCount++;
    }

    notifyListeners();

    // Agenda o próximo lote com intervalo reduzido (carregamento mais veloz na tela do usuário)
    if (endIndex < sortedCategories.length) {
      _categoryLoadTimer = Timer(const Duration(milliseconds: 60), () {
        _loadBatchOfCategories(groupedChannels, sortedCategories, endIndex);
      });
    }
  }

  /// Carrega todas as categorias de uma vez caso o usuário precise (ex: Categorias do Drawer)
  void loadAllCategories() {
    if (_allChannels.isEmpty) return;
    
    _categoryLoadTimer?.cancel();
    final Map<String, List<Channel>> groupedMap = {};
    
    for (final channel in _allChannels) {
      final category = channel.groupTitle.isEmpty ? 'Sem Categoria' : channel.groupTitle;
      (groupedMap[category] ??= []).add(channel);
    }

    _categorizedChannels = groupedMap;
    _loadedCategoriesCount = _categorizedChannels.length;
    notifyListeners();
  }

  /// Define o número de categorias carregadas por lote
  void setCategoriesPerBatch(int n) {
    _categoriesPerBatch = n.clamp(1, 50);
  }

  /// Pesquisa Otimizada e segura contra falhas de digitação
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
