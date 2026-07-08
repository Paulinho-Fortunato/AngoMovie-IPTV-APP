import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import '../models/channel.dart';
import '../widgets/channel_card.dart';
import '../widgets/featured_channel.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderSolid = false;
  bool _isSearchExpanded = false;
  
  Timer? _debounceTimer;
  Timer? _featuredRotationTimer; // Timer para rotacionar o destaque
  int _featuredIndex = 0; // Índice do canal em destaque atual
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startFeaturedRotation(); // Inicia a rotação automática
  }

  void _onScroll() {
    final isSolid = _scrollController.offset > 50;
    if (isSolid != _isHeaderSolid) {
      setState(() => _isHeaderSolid = isSolid);
    }
  }

  // Rotaciona o canal em destaque a cada 15 segundos
  void _startFeaturedRotation() {
    _featuredRotationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final provider = context.read<ChannelProvider>();
      if (provider.hasData) {
        // Pega todos os canais disponíveis para rotacionar entre eles
        final allChannels = provider.categorizedChannels.values.expand((e) => e).toList();
        if (allChannels.isNotEmpty) {
          setState(() {
            _featuredIndex = (_featuredIndex + 1) % allChannels.length;
          });
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      context.read<ChannelProvider>().search(query);
    });
  }

  void _openPlayer(Channel channel) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PlayerScreen(channel: channel),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _refreshChannels() async {
    await context.read<ChannelProvider>().refreshChannels();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lista de canais atualizada!'),
          backgroundColor: AppColors.darkGray,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _featuredRotationTimer?.cancel(); // Cancela o timer de rotação
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Consumer<ChannelProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 16),
                  Text(
                    'Carregando canais...',
                    style: TextStyle(color: AppColors.lightGray),
                  ),
                ],
              ),
            );
          }

          if (provider.hasError && !provider.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.lightGray),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshChannels,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Search results
          if (_isSearchExpanded &&
              _searchController.text.isNotEmpty &&
              provider.filteredChannels.isNotEmpty) {
            return _buildSearchResults(provider.filteredChannels);
          }

          if (!provider.hasData) {
            return const Center(
              child: Text(
                'Nenhum canal disponível no momento.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          return _buildMainContent(provider);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isHeaderSolid || _isSearchExpanded
              ? AppColors.background.withValues(alpha: 0.95)
              : Colors.transparent,
          boxShadow: _isHeaderSolid || _isSearchExpanded
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (!_isSearchExpanded) ...[
                  // Hamburguer Menu (Visível apenas quando não está pesquisando)
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: AppColors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // App Logo
                  const Text(
                    'ANGOMOVIE',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  // Botão de abrir pesquisa
                  IconButton(
                    icon: const Icon(Icons.search, color: AppColors.white),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = true;
                      });
                      _searchFocusNode.requestFocus();
                    },
                  ),
                  // Botão Atualizar
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.white),
                    onPressed: _refreshChannels,
                  ),
                  // Botão Configurações
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppColors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ] else ...[
                  // Barra de pesquisa totalmente expandida (ocupa a tela toda para evitar bugs)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = false;
                        _searchController.clear();
                      });
                      context.read<ChannelProvider>().clearSearch();
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: AppColors.white),
                      decoration: const InputDecoration(
                        hintText: 'Pesquise canais...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.white),
                      onPressed: () {
                        _searchController.clear();
                        context.read<ChannelProvider>().clearSearch();
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.darkGray,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              color: AppColors.background,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANGOMOVIE',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'IPTV v1.2.0',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.home, 'Início', () => Navigator.pop(context)),
            _drawerItem(Icons.tv, 'Categorias', () => Navigator.pop(context)),
            _drawerItem(
              Icons.settings,
              'Configurações',
              () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            _drawerItem(
              Icons.privacy_tip,
              'Privacidade',
              () => Navigator.pop(context),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'AngoMovie IPTV © 2026',
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.white),
      title: Text(label, style: const TextStyle(color: AppColors.white)),
      onTap: onTap,
      hoverColor: AppColors.mediumGray,
    );
  }

  Widget _buildMainContent(ChannelProvider provider) {
    final categories = provider.categorizedChannels.keys.toList();
    final allChannels = provider.categorizedChannels.values.expand((e) => e).toList();

    // Seleciona dinamicamente o canal baseado no Timer rotativo
    Channel? currentFeatured;
    if (allChannels.isNotEmpty) {
      currentFeatured = allChannels[_featuredIndex % allChannels.length];
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Canal de Destaque Dinâmico e Rotativo
        if (currentFeatured != null)
          SliverToBoxAdapter(
            key: ValueKey('featured_${currentFeatured.id}'), // Força atualização visual com animação fluida
            child: FeaturedChannelWidget(
              channel: currentFeatured,
              onPlay: () => _openPlayer(currentFeatured!),
            ),
          ),

        // ALTA PERFORMANCE: SliverList substitui o loop 'for' antigo.
        // Ele renderiza de forma preguiçosa (lazy loading) apenas as categorias visíveis no ecrã.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final category = categories[index];
              final channels = provider.categorizedChannels[category] ?? [];

              if (channels.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 8),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: channels.length,
                      itemBuilder: (context, itemIndex) {
                        final channel = channels[itemIndex];
                        return ChannelCard(
                          channel: channel,
                          onTap: () => _openPlayer(channel),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            childCount: categories.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSearchResults(List<Channel> channels) {
    // Busca a altura segura do topo (notch/status bar) para evitar sobreposição
    final double topPadding = MediaQuery.of(context).padding.top + 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Resultados (${channels.length})',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              return ChannelCard(
                channel: channels[index],
                onTap: () => _openPlayer(channels[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
