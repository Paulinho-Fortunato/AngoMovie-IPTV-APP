// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import '../models/channel.dart';
import '../widgets/channel_card.dart';
import '../widgets/featured_channel.dart';
import '../services/update_service.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'privacy_screen.dart';

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
  Timer? _featuredRotationTimer;
  int _featuredIndex = 0;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startFeaturedRotation();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        UpdateService.checkForUpdates(context);
      }
    });
  }

  void _onScroll() {
    final isSolid = _scrollController.offset > 50;
    if (isSolid != _isHeaderSolid) {
      setState(() => _isHeaderSolid = isSolid);
    }
  }

  void _startFeaturedRotation() {
    _featuredRotationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final provider = context.read<ChannelProvider>();
      if (provider.hasData) {
        final allChannels = provider.allChannels;
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
        SnackBar(
          content: const Text('Lista de canais atualizada!'),
          backgroundColor: AppColors.background.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _featuredRotationTimer?.cancel();
    _searchController.dispose();
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
                    'Sincronizando base de dados...',
                    style: TextStyle(color: AppColors.lightGray, fontWeight: FontWeight.w500),
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
                    const Icon(Icons.signal_wifi_bad, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.lightGray),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: _refreshChannels,
                      icon: const Icon(Icons.refresh, color: AppColors.white),
                      label: const Text('Tentar Novamente', style: TextStyle(color: AppColors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_isSearchExpanded && _searchController.text.isNotEmpty) {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduzido padding lateral
            child: !_isSearchExpanded
                ? Row(
                    children: [
                      // Botão do Menu Lateral com toque responsivo
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu, color: AppColors.white),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 8), // Espaço reduzido seguro
                      
                      // Logo Inteligente (Adapta o tamanho e evita quebrar em telas pequenas)
                      const Expanded(
                        child: Text(
                          'ANGOMOVIE',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 17, // Tamanho otimizado extremamente elegante
                            fontWeight: FontWeight.black, // Peso black para destaque visual
                            letterSpacing: 1.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      
                      // Bloco de Ações Ultra Otimizado em espaço horizontal
                      IconButton(
                        icon: const Icon(Icons.search, color: AppColors.white, size: 22),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = true;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.white, size: 22),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        onPressed: _refreshChannels,
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppColors.white, size: 22),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(left: 8, right: 4, top: 8, bottom: 8),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.white),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = false;
                            _searchController.clear();
                          });
                          context.read<ChannelProvider>().clearSearch();
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.mediumGray.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: AppColors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Pesquise canais, filmes...',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.white, size: 20),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          onPressed: () {
                            _searchController.clear();
                            context.read<ChannelProvider>().clearSearch();
                            setState(() {});
                          },
                        ),
                      ]
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
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Premium v1.2.0', // Corrigido de IPTV para Premium apenas
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.home_outlined, 'Início', () => Navigator.pop(context)),
            _drawerItem(Icons.settings_outlined, 'Configurações', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _drawerItem(Icons.privacy_tip_outlined, 'Privacidade', () {
              Navigator.pop(context);
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const PrivacyScreen(isGateMode: false))
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'AngoMovie © 2026', // Corrigido o copyright
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildMainContent(ChannelProvider provider) {
    final categories = provider.categorizedChannels.keys.toList();
    final allChannels = provider.allChannels;

    Channel? currentFeatured;
    if (allChannels.isNotEmpty) {
      currentFeatured = allChannels[_featuredIndex % allChannels.length];
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (currentFeatured != null)
          SliverToBoxAdapter(
            key: ValueKey('featured_${currentFeatured.id}'),
            child: FeaturedChannelWidget(
              channel: currentFeatured,
              onPlay: () => _openPlayer(currentFeatured!),
              onFavoriteToggle: () => provider.toggleFavorite(currentFeatured!),
            ),
          ),

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
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 28, bottom: 10),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: category == '★ Favoritos' ? Colors.amber.shade400 : AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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
                          width: 120,
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

        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _buildSearchResults(List<Channel> channels) {
    final double topPadding = MediaQuery.of(context).padding.top + 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Resultados Obtidos (${channels.length})',
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
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
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
