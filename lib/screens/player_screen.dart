// lib/screens/player_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';
import '../services/channel_service.dart';

enum AspectRatioMode { fit, stretch, zoom }

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  
  bool _isControlsVisible = true;
  bool _hasError = false;
  bool _isBuffering = false;
  String _errorMessage = '';
  
  Timer? _hideControlsTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  // Modos de Visualização e Gestos
  AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;
  double _volumeValue = 0.5;      
  double _brightnessValue = 0.5;  
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

  // Inteligência de Conteúdo: Detecta se é transmissão ao vivo ou arquivo VOD
  bool get _isLiveStream {
    final title = widget.channel.groupTitle.toLowerCase();
    return !title.contains('vod') &&
           !title.contains('filme') &&
           !title.contains('serie') &&
           !title.contains('movie') &&
           !title.contains('cinema') &&
           !title.contains('episodio') &&
           !title.contains('temporada') &&
           !title.contains('anime') &&
           !title.contains('novela');
  }

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
    await _disposeController();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      final uri = Uri.parse(widget.channel.streamUrl);
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
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Erro ao conectar ao servidor de streaming.';
        });
      }
    }
  }

  void _onPlayerStateChanged() {
    if (_controller == null || !mounted) return;

    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'O sinal do canal foi interrompido.';
      });
      return;
    }

    final isBuffering = _controller!.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }

    // Se for VOD, reconstrói o ecrã constantemente para atualizar a Timeline
    if (!_isLiveStream) {
      setState(() {});
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
    if (_isLiveStream) return; // TV Ao vivo não pode ser pausada/avançada
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

  // Avança o vídeo em 10 segundos (VOD)
  void _fastForward() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final currentPosition = _controller!.value.position;
    final targetPosition = currentPosition + const Duration(seconds: 10);
    _controller!.seekTo(targetPosition);
    _scheduleHideControls();
  }

  // Recua o vídeo em 10 segundos (VOD)
  void _rewind() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final currentPosition = _controller!.value.position;
    final targetPosition = currentPosition - const Duration(seconds: 10);
    _controller!.seekTo(targetPosition);
    _scheduleHideControls();
  }

  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioMode = AspectRatioMode.values[
          (_aspectRatioMode.index + 1) % AspectRatioMode.values.length];
    });
    _scheduleHideControls();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details, double screenWidth) {
    _scheduleHideControls();
    final isLeftSide = details.globalPosition.dx < (screenWidth / 2);
    final dragDelta = -details.primaryDelta! / 150.0;

    setState(() {
      if (isLeftSide) {
        _brightnessValue = (_brightnessValue + dragDelta).clamp(0.0, 1.0);
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
      } else {
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

  // Converte tempos de milissegundos para formatação amigável (01:23:45)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
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
        onDoubleTap: _isLiveStream ? null : _togglePlayPause, // Toque duplo desativado na TV ao Vivo
        onVerticalDragUpdate: (details) => _handleVerticalDragUpdate(details, size.width),
        child: Stack(
          children: [
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
                                'Conectando ao stream...',
                                style: TextStyle(color: AppColors.lightGray),
                              ),
                            ],
                          ),
                        ),
            ),

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

            if (_showVolumeIndicator) _buildGestureHUD(Icons.volume_up, _volumeValue, 'Volume'),
            if (_showBrightnessIndicator) _buildGestureHUD(Icons.brightness_5, _brightnessValue, 'Brilho'),

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

  Widget _buildVideoPlayerWrapper() {
    final videoValue = _controller!.value;

    switch (_aspectRatioMode) {
      case AspectRatioMode.stretch:
        return SizedBox.expand(child: VideoPlayer(_controller!));
      case AspectRatioMode.zoom:
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
        return AspectRatio(
          aspectRatio: videoValue.aspectRatio,
          child: VideoPlayer(_controller!),
        );
    }
  }

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

  Widget _buildControls() {
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. BARRA SUPERIOR (Comun a TV e VOD)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _TVControlWrapper(
                    onTap: _exitPlayer,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 28),
                      onPressed: _exitPlayer,
                    ),
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
                  _TVControlWrapper(
                    onTap: () {},
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: AppColors.white, size: 22),
                      onPressed: () {
                        _scheduleHideControls();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 2. PAINEL CENTRAL (Dinâmico: TV vs VOD)
            Expanded(
              child: Center(
                child: _isLiveStream
                    ? const SizedBox.shrink() // TV Ao Vivo não tem botões de reprodução centralizados
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Botão: Recuar 10 segundos
                          _TVControlWrapper(
                            onTap: _rewind,
                            child: IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.replay_10_rounded, color: AppColors.white),
                              onPressed: _rewind,
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // Botão: Play/Pause Central
                          _TVControlWrapper(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withValues(alpha: 0.85),
                              ),
                              child: IconButton(
                                iconSize: 40,
                                onPressed: _togglePlayPause,
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Botão: Avançar 10 segundos
                          _TVControlWrapper(
                            onTap: _fastForward,
                            child: IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.forward_10_rounded, color: AppColors.white),
                              onPressed: _fastForward,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // 3. BARRA INFERIOR (Dinâmica: TV vs VOD)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timeline/Progresso interativo (Apenas se for VOD)
                  if (!_isLiveStream && _controller != null && _controller!.value.isInitialized) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_controller!.value.position),
                            style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: _TVControlWrapper(
                              onTap: () {},
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.accent,
                                  inactiveTrackColor: AppColors.mediumGray.withValues(alpha: 0.3),
                                  thumbColor: AppColors.accent,
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _controller!.value.position.inSeconds.toDouble(),
                                  max: _controller!.value.duration.inSeconds.toDouble(),
                                  onChanged: (value) {
                                    _controller!.seekTo(Duration(seconds: value.toInt()));
                                    _scheduleHideControls();
                                  },
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_controller!.value.duration),
                            style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      // Badge de Identificação
                      _buildBadge(),
                      const Spacer(),
                      
                      // Ajuste de Enquadramento do Ecrã
                      _TVControlWrapper(
                        onTap: _cycleAspectRatio,
                        child: IconButton(
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
                          tooltip: 'Formato do Ecrã',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Constrói o Badge identificador inferior (AO VIVO ou VOD)
  Widget _buildBadge() {
    if (_isLiveStream) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade700.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ]
        ),
        child: const Row(
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
            SizedBox(width: 6),
            Text(
              'AO VIVO',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1),
        ),
        child: const Text(
          'VOD CINEMA',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      );
    }
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
              const Icon(Icons.signal_wifi_bad, color: AppColors.error, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Stream indisponível de momento',
                style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TVControlWrapper(
                    onTap: _exitPlayer,
                    child: OutlinedButton.icon(
                      onPressed: _exitPlayer,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Voltar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _TVControlWrapper(
                    onTap: () {
                      setState(() => _hasError = false);
                      _initPlayer();
                    },
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _hasError = false);
                        _initPlayer();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Tentar Novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

/// Envoltório de Foco para botões do player na TV Box (Comando D-PAD)
class _TVControlWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TVControlWrapper({required this.child, required this.onTap});

  @override
  State<_TVControlWrapper> createState() => _TVControlWrapperState();
}

class _TVControlWrapperState extends State<_TVControlWrapper> {
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
        scale: _isFocused ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.6),
                      blurRadius: 14,
                      spreadRadius: 3,
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
