import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';
import '../services/channel_service.dart';

// Modos de enquadramento de vídeo suportados
enum AspectRatioMode {
  fit,    // Mantém a proporção original (com barras pretas se necessário)
  stretch, // Estica o vídeo para preencher todo o ecrã
  zoom,   // Corta as bordas para preencher o ecrã sem distorcer
}

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
  bool _isBuffering = false; // Estado de Buffering em tempo real
  String _errorMessage = '';
  
  Timer? _hideControlsTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  // Recursos Premium para Gestão de Ecrã
  AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;
  double _volumeValue = 0.5;      // Controlado por gesto do lado direito
  double _brightnessValue = 0.5;  // Controlado por gesto do lado esquerdo
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

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

  // Descarte seguro de processos para evitar Vazamento de Memória
  Future<void> _disposeController() async {
    if (_controller != null) {
      _controller!.removeListener(_onPlayerStateChanged);
      try {
        await _controller!.pause();
      } catch (_) {}
      await _controller!.dispose();
      _controller = null;
    }
  }

  Future<void> _initPlayer() async {
    await _disposeController(); // Garante o encerramento de conexões órfãs

    // Forçar modo paisagem e imersivo ao entrar no player
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      final uri = Uri.parse(widget.channel.streamUrl);

      // Leitura dos Metadados (VLC/Headers customizados)
      final meta = await ChannelService.getChannelMeta(widget.channel.id);
      final headers = <String, String>{};

      headers['User-Agent'] = 'AngoMovie/1.2.0 Android';

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
        debugPrint('🎯 Player headers para ${widget.channel.name}: $headers');
      }

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

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {});
      await controller.play();
      controller.addListener(_onPlayerStateChanged);
      
    } catch (e, st) {
      if (kDebugMode) debugPrint('❌ Falha na inicialização do player: $e\n$st');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Erro ao carregar stream. Verifique a sua conexão de rede.';
        });
      }
    }
  }

  void _onPlayerStateChanged() {
    if (_controller == null || !mounted) return;

    // Detectar erro crítico no reprodutor de vídeo
    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'O stream de vídeo parou ou ficou indisponível.';
      });
      return;
    }

    // Monitoramento do Buffering em Tempo Real
    final isBuffering = _controller!.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isControlsVisible) {
        _controlsAnimController.forward();
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
      _controlsAnimController.reverse();
      _scheduleHideControls();
    } else {
      _controlsAnimController.forward();
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
    _scheduleHideControls();
  }

  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioMode = AspectRatioMode.values[
          (_aspectRatioMode.index + 1) % AspectRatioMode.values.length];
    });
    _scheduleHideControls();
  }

  // Manipuladores de Gestos para Volume e Brilho do Ecrã
  void _handleVerticalDragUpdate(DragUpdateDetails details, double screenWidth) {
    _scheduleHideControls();
    final isLeftSide = details.globalPosition.dx < (screenWidth / 2);
    final dragDelta = -details.primaryDelta! / 150.0; // Sensibilidade de arraste

    setState(() {
      if (isLeftSide) {
        // Controle de Brilho
        _brightnessValue = (_brightnessValue + dragDelta).clamp(0.0, 1.0);
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
      } else {
        // Controle de Volume
        _volumeValue = (_volumeValue + dragDelta).clamp(0.0, 1.0);
        _controller?.setVolume(_volumeValue);
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
      }
    });

    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      setState(() {
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
      });
    });
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
    _indicatorTimer?.cancel();
    _disposeController();
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTap: _togglePlayPause, // Toque duplo pausa ou dá play instantâneo
        onVerticalDragUpdate: (details) => _handleVerticalDragUpdate(details, size.width),
        child: Stack(
          children: [
            // CAMADA 1: O Renderizador do Vídeo com Aspect Ratio Dinâmico
            Center(
              child: _hasError
                  ? _buildErrorScreen()
                  : _controller?.value.isInitialized == true
                      ? _buildVideoPlayerWrapper()
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.accent),
                              SizedBox(height: 16),
                              Text(
                                'Conectando ao stream de TV...',
                                style: TextStyle(color: AppColors.lightGray),
                              ),
                            ],
                          ),
                        ),
            ),

            // CAMADA 2: Indicador Visual de Buffering (No meio do filme/canal)
            if (_isBuffering && !_hasError && _controller?.value.isInitialized == true)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(color: AppColors.accent),
                ),
              ),

            // CAMADA 3: HUD Indicador de Gestos Deslizantes (Brilho / Volume)
            if (_showVolumeIndicator) _buildGestureHUD(Icons.volume_up, _volumeValue, 'Volume'),
            if (_showBrightnessIndicator) _buildGestureHUD(Icons.brightness_5, _brightnessValue, 'Brilho'),

            // CAMADA 4: Controles de Reprodução Interativos
            if (!_hasError)
              IgnorePointer(
                ignoring: !_isControlsVisible,
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

  // Construtor Inteligente de Enquadramento de Imagem (Formato)
  Widget _buildVideoPlayerWrapper() {
    final videoValue = _controller!.value;

    switch (_aspectRatioMode) {
      case AspectRatioMode.stretch:
        // Estica a imagem para preencher toda a tela artificialmente
        return SizedBox.expand(
          child: VideoPlayer(_controller!),
        );
      case AspectRatioMode.zoom:
        // Dá crop (corte) inteligente na imagem mantendo o foco sem distorcer o elemento
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoValue.size.width,
              height: videoValue.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      case AspectRatioMode.fit:
      default:
        // Padrão original da emissora/transmissora
        return AspectRatio(
          aspectRatio: videoValue.aspectRatio,
          child: VideoPlayer(_controller!),
        );
    }
  }

  // Indicador Visual Estilizado dos Gestos no Ecrã (Brilho / Volume)
  Widget _buildGestureHUD(IconData icon, double value, String label) {
    return Positioned(
      top: 40,
      left: label == 'Brilho' ? 40 : null,
      right: label == 'Volume' ? 40 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Barra de Comandos e Controles da Tela
  Widget _buildControls() {
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000), // Gradiente superior
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000), // Gradiente inferior
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        // O SafeArea dentro do Container previne que furos na tela/notches cubram os botões
        child: Column(
          children: [
            // 1. BARRA SUPERIOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        color: Colors.black.withValues(alpha: 0.6),
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
                      _scheduleHideControls();
                      // TODO: Menu de configurações avançadas (Legenda/Aúdio se houver)
                    },
                  ),
                ],
              ),
            ),

            // 2. BOTÃO CENTRAL DE REPRODUÇÃO
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
                      color: AppColors.accent.withValues(alpha: 0.85),
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

            // 3. BARRA INFERIOR (Controles Rápidos de Proporção e Status)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  
                  // Botão de Modificar Aspect Ratio de Vídeo (Esticar / Ajustar / Zoom)
                  IconButton(
                    icon: Icon(
                      _aspectRatioMode == AspectRatioMode.fit
                          ? Icons.fit_screen
                          : _aspectRatioMode == AspectRatioMode.stretch
                              ? Icons.fullscreen_exit
                              : Icons.aspect_ratio,
                      color: AppColors.white,
                      size: 24,
                    ),
                    onPressed: _cycleAspectRatio,
                    tooltip: 'Proporção do Ecrã',
                  ),
                ],
              ),
            ),
          ],
        ),
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
