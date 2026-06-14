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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blockHttpStreams = prefs.getBool('block_http_streams') ?? false;
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
