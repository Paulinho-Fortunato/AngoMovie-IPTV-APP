// lib/screens/privacy_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';

class PrivacyScreen extends StatefulWidget {
  final bool isGateMode;

  const PrivacyScreen({
    super.key,
    this.isGateMode = true,
  });

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGateMode) {
      _scrollController.addListener(_onScroll);
    } else {
      _hasScrolledToBottom = true;
    }
  }

  void _onScroll() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    
    if (!context.mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: !widget.isGateMode
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'POLÍTICA DE PRIVACIDADE',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              centerTitle: true,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              if (widget.isGateMode) ...[
                const SizedBox(height: 20),
                const Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'AVISO DE PRIVACIDADE',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 80,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 24),
              ],
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.mediumGray.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection(
                              icon: Icons.lock_outline,
                              title: 'Tratamento de Dados',
                              text: 'O AngoMovie IPTV não recolhe, armazena, monitoriza ou partilha quaisquer dados pessoais dos utilizadores. Todas as configurações e listas de canais são guardadas única e exclusivamente de forma local no seu próprio dispositivo.',
                            ),
                            _buildSection(
                              icon: Icons.wifi_lock,
                              title: 'Segurança nas Conexões de Rede',
                              text: 'Alguns fluxos de transmissão utilizam o protocolo HTTP simples. Recomendamos o uso de conexões seguras privadas (como Wi-Fi doméstico protegido ou planos de dados de operadoras confiáveis) para prevenir interceptações de tráfego de rede por terceiros.',
                            ),
                            _buildSection(
                              icon: Icons.sd_storage_outlined,
                              title: 'Armazenamento no Dispositivo',
                              text: 'Para otimizar o tempo de resposta e garantir uma reprodução fluida, o aplicativo armazena temporariamente metadados de streaming no armazenamento físico local. Nenhuma destas informações é transmitida para servidores externos do app.',
                            ),
                            _buildSection(
                              icon: Icons.gavel_outlined,
                              title: 'Exclusão de Responsabilidade',
                              text: 'O AngoMovie IPTV atua puramente como um reprodutor multimédia (player). Não hospedamos, distribuímos, vendemos ou controlamos as listas de canais. A legalidade e direitos de transmissão dos conteúdos reproduzidos são da total responsabilidade do fornecedor do serviço IPTV contratado por si.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              if (widget.isGateMode) ...[
                const SizedBox(height: 20),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _hasScrolledToBottom ? 1.0 : 0.5,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _hasScrolledToBottom ? () => _accept(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor: AppColors.mediumGray,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _hasScrolledToBottom ? 'ACEITAR E CONTINUAR' : 'ROLE ATÉ O FIM PARA ACEITAR',
                        style: TextStyle(
                          color: _hasScrolledToBottom ? AppColors.white : AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      // CORREÇÃO EFETUADA: EdgeInsets.only em vez do inexistente EdgeInsets.bottom
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.lightGray,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}
