import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';
import '../services/channel_service.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isControlsVisible = true;

  bool _hasError = false;
  String _errorMessage = '';
  Timer? _hideControlsTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controlsAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controlsAnimController, curve: Curves.easeInOut),
    );
    _initPlayer();
    _scheduleHideControls();
  }

  Future<void> _initPlayer() async {
    // Forçar modo paisagem e imersivo ao entrar no player
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      final uri = Uri.parse(widget.channel.streamUrl);

      // --- LEITURA DE METADADOS (vlc-http-user-agent, etc.)
      final meta = await ChannelService.getChannelMeta(widget.channel.id);
      final headers = <String, String>{};

      // User-Agent Padrão do app
      headers['User-Agent'] = 'AngoMovie/1.2.0 Android';

      // Aplicar opções personalizadas do VLC se estiverem presentes
      if (meta.containsKey('vlc-http-user-agent')) {
        headers['User-Agent'] = meta['vlc-http-user-agent']!;
      }
      if (meta.containsKey('vlc-http-referrer')) {
        headers['Referer'] = meta['vlc-http-referrer']!;
      }
      if (meta.containsKey('vlc-http-origin')) {
        headers['Origin'] = meta['vlc-http-origin']!;
      }

      if (kDebugMode) {
        debugPrint('🎯 Player headers for ${widget.channel.name}: $headers');
      }

      // Se o usuário saiu da tela enquanto os metadados eram carregados da API
      if (!mounted) return;

      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      _controller = controller;
      await controller.initialize();

      // PROTEÇÃO: Se o usuário saiu da tela durante a inicialização demorada da rede
      if (!mounted) {
        await controller.dispose();
        if (_controller == controller) _controller = null;
        return;
      }

      setState(() {});
      await controller.play();
      controller.addListener(_onPlayerStateChanged);
      
    } catch (e, st) {
      if (kDebugMode) debugPrint('❌ Player init error: $e\n$st');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Erro ao carregar stream. Verifique sua conexão.';
        });
      }
    }
  }

  void _onPlayerStateChanged() {
    if (_controller?.value.hasError == true && mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Stream indisponível no momento.';
      });
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isControlsVisible) {
        _controlsAnimController.forward(); // Faz o efeito fade-out rodar
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    if (_isControlsVisible) {
      _controlsAnimController.reverse(); // Mostra os controles
      _scheduleHideControls(); // Inicia contagem para sumir de novo
    } else {
      _controlsAnimController.forward(); // Esconde os controles
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
    _scheduleHideControls(); // Reinicia o timer ao clicar para não sumir na hora
  }

  Future<void> _exitPlayer() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    _controlsAnimController.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls, // Toque no fundo alterna a visibilidade de TUDO
        child: Stack(
          children: [
            // Camada 1: O Vídeo Player
            Center(
              child: _hasError
                  ? _buildErrorScreen()
                  : _controller?.value.isInitialized == true
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.accent),
                              SizedBox(height: 16),
                              Text(
                                'Conectando ao stream...',
                                style: TextStyle(color: AppColors.lightGray),
                              ),
                            ],
                          ),
                        ),
            ),

            // Camada 2: Toda a interface de controle (Envolvida na animação)
            if (!_hasError)
              IgnorePointer(
                ignoring: !_isControlsVisible, // Bloqueia toques fantasmas quando invisível
                child: AnimatedBuilder(
                  animation: _controlsAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 1.0 - _controlsAnimation.value,
                      child: child,
                    );
                  },
                  child: _buildControls(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000), // Sombra superior
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000), // Sombra inferior
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [
          // 1. BARRA SUPERIOR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 28),
                  onPressed: _exitPlayer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.channel.name,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.channel.groupTitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.channel.isHttpStream) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(153),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HTTP',
                      style: TextStyle(color: AppColors.warning, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.white, size: 22),
                  onPressed: () {
                    _scheduleHideControls(); // Adia o sumiço automático
                    // TODO: Menu de definições
                  },
                ),
              ],
            ),
          ),

          // 2. BOTÃO CENTRAL (PLAY/PAUSE)
          Expanded(
            child: Center(
              child: IconButton(
                iconSize: 70,
                onPressed: _togglePlayPause,
                icon: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withAlpha(216),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),

          // 3. BARRA INFERIOR (Barra vermelha removida com sucesso)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AO VIVO',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: AppColors.white, size: 22),
                  onPressed: () {
                    _scheduleHideControls(); // Adia o sumiço automático
                    // TODO: Controle de volume
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: AppColors.white, size: 22),
                  onPressed: () {
                    _scheduleHideControls(); // Adia o sumiço automático
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.signal_wifi_bad,
                color: AppColors.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Stream indisponível no momento',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _exitPlayer,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Voltar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                      });
                      _initPlayer();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Tentar Novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
