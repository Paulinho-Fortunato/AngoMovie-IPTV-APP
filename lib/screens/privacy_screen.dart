import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
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
                color: AppColors.accent,
                margin: const EdgeInsets.symmetric(horizontal: 40),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.mediumGray,
                        width: 1,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Política de Privacidade',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'AngoMovie IPTV não coleta, armazena ou compartilha dados pessoais. Todos os dados de canais são salvos apenas no seu dispositivo. O app acessa servidores de terceiros para reprodução de streams – responsabilidade pelo conteúdo é do provedor do serviço.',
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Conexões de Rede',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Alguns servidores de streams utilizam protocolo HTTP (não seguro), o que pode permitir que terceiros visualizem dados da conexão. O app limita o acesso apenas a servidores autorizados, mas recomendamos usar conexões de rede segura (Wi-Fi privada ou dados móveis) ao utilizar o app.',
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Armazenamento Local',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Os dados dos canais são armazenados localmente no dispositivo para melhorar a performance. Nenhuma informação é enviada para servidores externos além da lista de canais.',
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Responsabilidade pelo Conteúdo',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'O AngoMovie IPTV é um reprodutor de conteúdo. A responsabilidade pelo conteúdo exibido é inteiramente do provedor do serviço IPTV. O app não hospeda nem distribui conteúdo.',
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _accept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'ENTENDI',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
