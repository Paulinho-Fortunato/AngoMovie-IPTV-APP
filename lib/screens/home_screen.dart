import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import '../models/channel.dart';
import '../widgets/channel_card.dart';
import '../widgets/featured_channel.dart';
import '../widgets/search_bar_widget.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final isSolid = _scrollController.offset > 50;
    if (isSolid != _isHeaderSolid) {
      setState(() => _isHeaderSolid = isSolid);
    }
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
          color: _isHeaderSolid
              ? AppColors.background.withValues(alpha: 0.95)
              : Colors.transparent,
          boxShadow: _isHeaderSolid
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
                // Hamburger menu
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 12),
                // App Logo
                const Text(
                  'ANGOMOVIE',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                // Search bar
                Expanded(
                  flex: 3,
                  child: SearchBarWidget(
                    controller: _searchController,
                    isExpanded: _isSearchExpanded,
                    onChanged: _onSearchChanged,
                    onTap: () => setState(() => _isSearchExpanded = true),
                    onClose: () {
                      setState(() {
                        _isSearchExpanded = false;
                        _searchController.clear();
                      });
                      context.read<ChannelProvider>().clearSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh button
                if (!_isSearchExpanded)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.white, size: 22),
                    onPressed: _refreshChannels,
                    tooltip: 'Atualizar Lista',
                  ),
                // Settings
                if (!_isSearchExpanded)
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppColors.white, size: 22),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
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

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Featured Channel Section
        if (provider.featuredChannel != null)
          SliverToBoxAdapter(
            child: FeaturedChannelWidget(
              channel: provider.featuredChannel!,
              onPlay: () => _openPlayer(provider.featuredChannel!),
            ),
          ),

        // Category rows
        for (final category in categories)
          if (provider.categorizedChannels[category]!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 32, bottom: 8),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: provider.categorizedChannels[category]!.length,
                  itemBuilder: (context, index) {
                    final channel =
                        provider.categorizedChannels[category]![index];
                    return ChannelCard(
                      channel: channel,
                      onTap: () => _openPlayer(channel),
                    );
                  },
                ),
              ),
            ),
          ],

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSearchResults(List<Channel> channels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 90),
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
