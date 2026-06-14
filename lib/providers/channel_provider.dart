import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';
import '../services/m3u_parser.dart';

enum LoadingState { idle, loading, success, error }

class ChannelProvider extends ChangeNotifier {
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Map<String, List<Channel>> _categorizedChannels = {};
  LoadingState _state = LoadingState.idle;
  String _errorMessage = '';
  String _searchQuery = '';
  Channel? _featuredChannel;

  List<Channel> get allChannels => _allChannels;
  List<Channel> get filteredChannels =>
      _searchQuery.isEmpty ? _allChannels : _filteredChannels;
  Map<String, List<Channel>> get categorizedChannels => _categorizedChannels;
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  Channel? get featuredChannel => _featuredChannel;
  bool get isLoading => _state == LoadingState.loading;
  bool get hasError => _state == LoadingState.error;
  bool get hasData => _allChannels.isNotEmpty;

  Future<void> loadChannels({bool forceRefresh = false}) async {
    _state = LoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _allChannels = await ChannelService.loadChannels(forceRefresh: forceRefresh);
      _categorizedChannels = M3uParser.groupByCategory(_allChannels);
      _featuredChannel = _allChannels.isNotEmpty ? _allChannels.first : null;
      _state = LoadingState.success;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar os canais. Verifique sua conexão.';
      _state = LoadingState.error;
      if (kDebugMode) debugPrint('Error loading channels: $e');
    }

    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _filteredChannels = [];
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredChannels = _allChannels
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.groupTitle.toLowerCase().contains(q))
          .toList();
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
}
