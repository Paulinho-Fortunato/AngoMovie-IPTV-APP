import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';
import 'privacy_screen.dart';
import '../services/channel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _showSecondaryText = false;
  int _dotCount = 0;
  Timer? _dotsTimer; // Timer para controlar a animação dos pontos de forma segura

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startLoading();
  }

  void _setupAnimations() {
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Substituído o Future.delayed recursivo por um Timer.periodic limpo e seguro
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });

    // Mostrar texto secundário após 2 segundos de forma segura
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSecondaryText = true);
      }
    });
  }

  Future<void> _startLoading() async {
    try {
      // Verificar se a privacidade foi aceita
      final prefs = await SharedPreferences.getInstance();
      final privacyAccepted = prefs.getBool('privacy_accepted') ?? false;

      // Inicializar o Hive para armazenamento local
      await ChannelService.initHive();

      // Carregar os canais via Provider de forma segura
      if (mounted) {
        await context.read<ChannelProvider>().loadChannels();
      }

      // Garantir um tempo mínimo visual para a Splash Screen
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Executar animação de Fade Out da tela inteira
      await _fadeController.forward();

      if (!mounted) return;

      // Navegar para a próxima tela eliminando a Splash da pilha
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              privacyAccepted ? const HomeScreen() : const PrivacyScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      // Evita travamentos se algo falhar na inicialização
      debugPrint('Erro na inicialização da Splash: $e');
      if (mounted) {
        // Redireciona mesmo com erro para não prender o usuário na Splash
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PrivacyScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _dotsTimer?.cancel(); // Cancelar o Timer dos pontinhos obrigatoriamente
    _rotationController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: AppColors.darkBlue,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF0D2040),
                Color(0xFF0A1A2F),
                Color(0xFF060E1A),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Ícone/Logo do Aplicativo com efeito Pulse
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) => Container(
                          color: AppColors.darkGray,
                          child: const Center(
                            child: Text(
                              'ANGO\nMOVIE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Nome do Aplicativo
                const Text(
                  'ANGOMOVIE',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const Text(
                  'IPTV',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    letterSpacing: 8,
                  ),
                ),

                const Spacer(),

                // Indicador de Carregamento Rotativo
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent,
                        width: 3,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.mediumGray,
                          width: 1,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Texto de Carregamento Dinâmico (Carregando experiência...)
                Text(
                  'Carregando experiência$dots',
                  style: const TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 8),

                // Texto Secundário com Animação de Opacidade Nativa
                AnimatedOpacity(
                  opacity: _showSecondaryText ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: const Text(
                    'Preparando canais ao vivo...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),

                const Spacer(),

                // Rodapé com a Versão do App
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'v1.2.0',
                    style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
