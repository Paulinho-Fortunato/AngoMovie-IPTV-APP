import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/channel_provider.dart';
import '../utils/app_colors.dart';
import '../services/channel_service.dart';
import 'home_screen.dart';
import 'privacy_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _showSecondaryText = false;
  int _dotCount = 0;
  
  Timer? _dotsTimer;             // Timer para os pontinhos de carregamento
  Timer? _secondaryTextTimer;    // Timer seguro para o texto de suporte

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startLoading();
  }

  void _setupAnimations() {
    // Animação de rotação contínua do spinner inferior
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Animação de pulsação suave para o ícone/logo do app
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Timer periódico e seguro para os pontos de carregamento ("...")
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });

    // Timer de disparo único para revelar o texto de suporte de rede
    _secondaryTextTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSecondaryText = true);
      }
    });
  }

  Future<void> _startLoading() async {
    bool privacyAccepted = false;
    
    try {
      // 1. Verificar se a política de privacidade já foi aceita pelo usuário
      final prefs = await SharedPreferences.getInstance();
      privacyAccepted = prefs.getBool('privacy_accepted') ?? false;

      // 2. Inicializar banco de dados local cacheado (Hive)
      await ChannelService.initHive();

      // 3. Efetuar o carregamento de canais (Local/M3U) de forma assíncrona
      if (mounted) {
        await context.read<ChannelProvider>().loadChannels();
      }

      // Tempo de espera mínimo de segurança visual na Splash (Garante suavidade)
      await Future.delayed(const Duration(milliseconds: 800));

      _navigateToNextScreen(privacyAccepted);

    } catch (e) {
      debugPrint('⚠️ Erro crítico na inicialização da Splash: $e');
      
      // Mesmo com falha catastrófica de rede ou banco de dados, o app não pode travar.
      // Redireciona o utilizador de forma segura baseando-se no aceite prévio dele.
      _navigateToNextScreen(privacyAccepted);
    }
  }

  void _navigateToNextScreen(bool privacyAccepted) {
    if (!mounted) return;

    // Navegação otimizada: A transição de Fade é controlada unicamente pela rota,
    // eliminando o duplo fade e garantindo suavidade absoluta a 60FPS.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            privacyAccepted 
                ? const HomeScreen() 
                : const PrivacyScreen(isGateMode: true), // Correção: Configura explicitamente como Gate de primeiro acesso
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _secondaryTextTimer?.cancel(); // Cancela o timer do texto de suporte
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;

    return Scaffold(
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

              // Ícone com Animação de Pulsação de Escala Dinâmica
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        // Uso atualizado do padrão .withValues para compatibilidade total
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 35,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
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

              const SizedBox(height: 24),

              // Identidade de Marca do Aplicativo
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

              // Indicador Circular de Carregamento Estilizado (Spinner)
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 44,
                  height: 44,
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
                        color: AppColors.mediumGray.withValues(alpha: 0.3),
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

              // Feedback em tempo real sobre a inicialização
              Text(
                'Carregando experiência$dots',
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // Texto Informativo Secundário (Ativado via Timer seguro)
              AnimatedOpacity(
                opacity: _showSecondaryText ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: const Text(
                  'Preparando canais de TV ao vivo...',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),

              const Spacer(),

              // Rodapé com controle estrito de versão de produção
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'v1.2.0',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
