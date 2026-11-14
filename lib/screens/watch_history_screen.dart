import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../models/watch_history_entry.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import 'player_screen.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChannelProvider>().loadWatchHistory();
    });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: const Text(
          'Limpar histórico?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'Esta ação remove do dispositivo os canais vistos recentemente.',
          style: TextStyle(color: AppColors.lightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await context.read<ChannelProvider>().clearWatchHistory();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível limpar o histórico.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _playEntry(WatchHistoryEntry entry, ChannelProvider provider) {
    Channel? channel;
    for (final candidate in provider.allChannels) {
      if (candidate.id == entry.channelId) {
        channel = candidate;
        break;
      }
    }

    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este canal já não está disponível na lista carregada.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayerScreen(channel: channel!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: const Text('Histórico de visualização'),
        actions: [
          IconButton(
            tooltip: 'Limpar histórico',
            onPressed: _isClearing
                ? null
                : () => _confirmClear(),
            icon: _isClearing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Consumer<ChannelProvider>(
        builder: (context, provider, _) {
          if (provider.watchHistory.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, color: AppColors.textMuted, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'Ainda não há canais no histórico.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.lightGray, fontSize: 16),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'O histórico é atualizado quando a reprodução começa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.watchHistory.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
              color: AppColors.mediumGray,
            ),
            itemBuilder: (context, index) {
              final entry = provider.watchHistory[index];
              final date = DateTime.fromMillisecondsSinceEpoch(
                entry.lastPlayedAt,
              );
              final channelAvailable = provider.allChannels
                  .any((channel) => channel.id == entry.channelId);
              final dateText = MaterialLocalizations.of(context)
                  .formatShortDate(date);
              final timeText = TimeOfDay.fromDateTime(date).format(context);

              return ListTile(
                minVerticalPadding: 12,
                leading: CircleAvatar(
                  backgroundColor: AppColors.darkGray,
                  child: entry.logoUrl.isEmpty
                      ? const Icon(Icons.live_tv, color: AppColors.accent)
                      : ClipOval(
                          child: Image.network(
                            entry.logoUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.live_tv,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                ),
                title: Text(
                  entry.name.isEmpty ? 'Canal sem nome' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${entry.groupTitle.isEmpty ? "Geral" : entry.groupTitle} · $dateText, $timeText',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                trailing: Text(
                  '${entry.playCount}×',
                  semanticsLabel: 'Reproduzido ${entry.playCount} vezes',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                onTap: channelAvailable
                    ? () => _playEntry(entry, provider)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
