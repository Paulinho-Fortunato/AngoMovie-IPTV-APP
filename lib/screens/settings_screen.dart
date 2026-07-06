import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../services/channel_service.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _blockHttpStreams = false;
  String _m3uUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = await ChannelService.getM3uUrl();
    setState(() {
      _blockHttpStreams = prefs.getBool('block_http_streams') ?? false;
      _m3uUrl = url;
    });
  }

  Future<void> _clearCache() async {
    await ChannelService.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache limpo com sucesso!'),
          backgroundColor: AppColors.darkGray,
        ),
      );
    }
  }

  Future<void> _toggleBlockHttp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('block_http_streams', value);
    setState(() => _blockHttpStreams = value);
  }

  Future<void> _editM3uUrl() async {
    final controller = TextEditingController(text: _m3uUrl);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('URL M3U personalizada', style: TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Insira uma URL M3U para testes. Deixe em branco para usar a URL padrão.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'http://exemplo.com/lista.m3u',
                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppColors.mediumGray.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              // Reset to default
              await ChannelService.setM3uUrl(null);
              final newUrl = await ChannelService.getM3uUrl();
              if (mounted) {
                setState(() => _m3uUrl = newUrl);
                Navigator.of(context).pop(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL revertida para a padrão'), backgroundColor: AppColors.darkGray),
                );
              }
            },
            child: const Text('Resetar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              final text = controller.text.trim();
              await ChannelService.setM3uUrl(text.isEmpty ? null : text);
              final newUrl = await ChannelService.getM3uUrl();
              if (mounted) {
                setState(() => _m3uUrl = newUrl);
                Navigator.of(context).pop(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL salva com sucesso'), backgroundColor: AppColors.darkGray),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    // opcional: se salvou, talvez forçar reload da lista em seguida (o user pode usar botão Atualizar na UI)
    if (result == true) {
      // nada automático aqui — deixa o usuário atualizar via botão Refresh na home
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info Section
          _sectionTitle('Sobre o App'),
          _infoTile('Versão', '1.2.0 (Build 3)'),
          _infoTile('Plataforma', 'Android'),
          _infoTile('Fonte de Dados', 'IPTV Remoto'),
          // Mostrar a URL atual e botão para editar
          ListTile(
            leading: const Icon(Icons.link, color: AppColors.textMuted),
            title: const Text('URL M3U atual', style: TextStyle(color: AppColors.white, fontSize: 14)),
            subtitle: Text(
              _m3uUrl,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit, color: AppColors.textMuted),
            onTap: _editM3uUrl,
          ),

          const SizedBox(height: 24),

          // Cache Section
          _sectionTitle('Cache e Dados'),
          _actionTile(
            icon: Icons.delete_sweep,
            title: 'Limpar Cache',
            subtitle: 'Remove canais salvos localmente',
            onTap: _clearCache,
          ),

          const SizedBox(height: 24),

          // Security Section
          _sectionTitle('Segurança da Conexão'),
          _settingsTile(
            title: 'Informação HTTP',
            subtitle:
                'Alguns servidores utilizam protocolo HTTP (não seguro). O app limita o acesso apenas a servidores autorizados.',
          ),
          SwitchListTile(
            title: const Text(
              'Bloquear Streams HTTP',
              style: TextStyle(color: AppColors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Apenas reproduzir streams HTTPS (pode reduzir canais disponíveis)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            value: _blockHttpStreams,
            onChanged: _toggleBlockHttp,
            activeThumbColor: AppColors.accent,
            inactiveThumbColor: AppColors.textMuted,
          ),

          const SizedBox(height: 24),

          // Privacy Section
          _sectionTitle('Privacidade'),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: AppColors.textMuted),
            title: const Text(
              'Ver Política de Privacidade',
              style: TextStyle(color: AppColors.white, fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // About
          _sectionTitle('Créditos'),
          _settingsTile(
            title: 'AngoMovie IPTV',
            subtitle:
                'App desenvolvido para reprodução de conteúdo IPTV. Todo o conteúdo é de responsabilidade do provedor do serviço.',
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      trailing: Text(value, style: const TextStyle(color: AppColors.white, fontSize: 13)),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textMuted),
      title: Text(title, style: const TextStyle(color: AppColors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _settingsTile({required String title, required String subtitle}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: AppColors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
    );
  }
}
