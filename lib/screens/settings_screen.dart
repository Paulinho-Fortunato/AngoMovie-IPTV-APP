import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/channel_provider.dart';
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
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = await ChannelService.getM3uUrl();
      if (mounted) {
        setState(() {
          _blockHttpStreams = prefs.getBool('block_http_streams') ?? false;
          _m3uUrl = url;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
    }
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;
    setState(() => _isClearing = true);

    try {
      await ChannelService.clearCache();
      
      // REATIVIDADE: Limpa o estado global de canais no Provider
      if (mounted) {
        context.read<ChannelProvider>().clearSearch();
        await context.read<ChannelProvider>().refreshChannels();
      }

      if (mounted) {
        _showSuccessSnackBar('Cache e canais redefinidos com sucesso!');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Erro ao limpar cache.');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _toggleBlockHttp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('block_http_streams', value);
    if (mounted) {
      setState(() => _blockHttpStreams = value);
      // REATIVIDADE: Recarrega os canais respeitando o novo filtro de segurança
      context.read<ChannelProvider>().refreshChannels();
    }
  }

  Future<void> _editM3uUrl() async {
    final controller = TextEditingController(text: _m3uUrl);
    final formKey = GlobalKey<FormState>();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Lista M3U Personalizada', 
          style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insira um link M3U válido para carregar a sua lista de reprodução personalizada.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'https://exemplo.com/lista.m3u',
                  hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: AppColors.mediumGray.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                maxLines: 1,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !uri.hasAbsolutePath) {
                    return 'Insira um endereço URL válido.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              await ChannelService.setM3uUrl(null);
              final newUrl = await ChannelService.getM3uUrl();
              if (context.mounted) Navigator.of(context).pop(true);
              _updateUrlState(newUrl, 'Lista revertida para o padrão de fábrica.');
            },
            child: const Text('Resetar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final text = controller.text.trim();
                await ChannelService.setM3uUrl(text.isEmpty ? null : text);
                final newUrl = await ChannelService.getM3uUrl();
                if (context.mounted) Navigator.of(context).pop(true);
                _updateUrlState(newUrl, 'Nova lista de canais carregada!');
              }
            },
            child: const Text('Gravar', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  void _updateUrlState(String newUrl, String message) {
    if (!mounted) return;
    setState(() => _m3uUrl = newUrl);
    
    // REATIVIDADE: Notifica e recarrega os canais na Home instantaneamente
    context.read<ChannelProvider>().refreshChannels();
    _showSuccessSnackBar(message);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // SEÇÃO 1: SOBRE O APP
          _sectionTitle('Sobre o App'),
          _buildCard(
            children: [
              _infoTile('Versão', '1.2.0 (Build 3)'),
              _buildDivider(),
              _infoTile('Plataforma', 'Android OS'),
              _buildDivider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Lista de Canais M3U', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _m3uUrl.isEmpty ? 'Usando lista interna padrão' : _m3uUrl,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit, color: AppColors.accent, size: 20),
                onTap: _editM3uUrl,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SEÇÃO 2: CACHE E DESEMPENHO
          _sectionTitle('Dados & Desempenho'),
          _buildCard(
            children: [
              _actionTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Limpar Cache de Streams',
                subtitle: _isClearing ? 'A redefinir base de dados...' : 'Remove dados locais e sincroniza novamente.',
                trailing: _isClearing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: _isClearing ? () {} : _clearCache,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SEÇÃO 3: SEGURANÇA E PROTOCOLO
          _sectionTitle('Rede & Segurança'),
          _buildCard(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: const Text(
                  'Bloquear Links HTTP',
                  style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Força ligações encriptadas (HTTPS). Melhora a privacidade, mas pode desativar alguns canais de TV mais antigos.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                ),
                value: _blockHttpStreams,
                onChanged: _toggleBlockHttp,
                activeColor: AppColors.accent,
                activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.mediumGray.withValues(alpha: 0.3),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SEÇÃO 4: SUPORTE E PRIVACIDADE
          _sectionTitle('Legal & Suporte'),
          _buildCard(
            children: [
              _actionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Política de Privacidade',
                subtitle: 'Consulte os seus direitos e o tratamento de dados.',
                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    // CORREÇÃO CRÍTICA DO BUG DE LOOP DE NAVEGAÇÃO
                    builder: (_) => const PrivacyScreen(isGateMode: false),
                  ),
                ),
              ),
              _buildDivider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aviso de Isenção',
                      style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'O AngoMovie IPTV é um motor de reprodução. Não alojamos nem somos responsáveis pelos streams ou conteúdos adicionados pelos utilizadores através de links M3U.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // Componente Premium: Cartão de agrupamento visual de opções
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkGray.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.mediumGray.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.mediumGray.withValues(alpha: 0.15),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
