// lib/services/update_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

class UpdateService {
  // Link bruto do JSON hospedado no seu repositório do Github
  static const String _updateUrl =
      'https://raw.githubusercontent.com/Paulinho-Fortunato/Segundalista/refs/heads/main/version.json';

  /// Verifica se há uma atualização disponível e exibe o diálogo
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_updateUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String remoteVersion = data['version'] ?? '1.0.0';
        final String downloadUrl = data['download_url'] ?? '';
        final String changelog = data['changelog'] ?? 'Nova atualização disponível.';
        final bool forceUpdate = data['force_update'] ?? false;

        // Obtém a versão atualmente instalada no telemóvel/TV
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String localVersion = packageInfo.version;

        if (_isNewerVersion(localVersion, remoteVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersion, downloadUrl, changelog, forceUpdate);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar atualizações: $e');
    }
  }

  /// Compara as duas strings de versão de forma matemática semântica (ex: 1.2.0 < 1.3.0)
  static bool _isNewerVersion(String local, String remote) {
    List<int> localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < remoteParts.length; i++) {
      int localPart = i < localParts.length ? localParts[i] : 0;
      int remotePart = remoteParts[i];

      if (remotePart > localPart) return true;
      if (remotePart < localPart) return false;
    }
    return false;
  }

  /// Exibe a janela de atualização com suporte nativo a controle remoto
  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String downloadUrl,
    String changelog,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate, // Impede fechar se for uma atualização obrigatória
      builder: (context) {
        return PopScope(
          canPop: !forceUpdate, // Bloqueia o botão voltar do telemóvel se for obrigatório
          child: AlertDialog(
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.system_update_alt_rounded, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Nova Atualização!',
                  style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A versão $newVersion já está disponível para download.',
                  style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.mediumGray.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Novidades desta versão:',
                        style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        changelog,
                        style: const TextStyle(color: AppColors.lightGray, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!forceUpdate)
                _TVButtonWrapper(
                  onTap: () => Navigator.of(context).pop(),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('MAIS TARDE', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              _TVButtonWrapper(
                onTap: () => _launchURL(downloadUrl),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _launchURL(downloadUrl),
                  child: const Text('ATUALIZAR AGORA', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Abre o navegador padrão para baixar o APK
  static Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ Não foi possível abrir o link: $e');
    }
  }
}

/// Envoltório de Foco para botões do diálogo na TV Box (Comando D-PAD)
class _TVButtonWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TVButtonWrapper({required this.child, required this.onTap});

  @override
  State<_TVButtonWrapper> createState() => _TVButtonWrapperState();
}

class _TVButtonWrapperState extends State<_TVButtonWrapper> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focus) => setState(() => _isFocused = focus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
