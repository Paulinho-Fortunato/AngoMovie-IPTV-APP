// lib/screens/player_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';
import '../services/channel_service.dart';
import '../services/external_player_service.dart';

enum AspectRatioMode { fit, stretch, zoom }

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  VlcPlayerController? _controller;
  
  bool _isControlsVisible = true;
  bool _hasError = false;
  bool _isBuffering = false;
  String _errorMessage = '';
  
  Timer? _hideControlsTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;
  double _volumeValue = 0.5;      
  double _brightnessValue = 0.5;  
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

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
        await _controller!.stop();
      } catch (_) {}
      await _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    // 1. Cancelar todos os Timers ativos para evitar vazamento de memória (Memory Leaks)
    _hideControlsTimer?.cancel();
    _indicatorTimer?.cancel();
    _controlsAnimController.dispose();

    // 2. Desativar Wakelock
    WakelockPlus.disable();

    // 3. Destruir o Player de Vídeo VLC
    final controllerToDispose = _controller;
    if (controllerToDispose != null) {
      controllerToDispose.removeListener(_onPlayerStateChanged);
      controllerToDispose.stop().then((_) => controllerToDispose.dispose());
    }

    // 4. FORÇAR a rotação voltar para Vertical (Retrato) ao sair da tela
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // 5. Reativar as barras de status e navegação do celular
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Future<void> _initPlayer() async {
    await _disposeController();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      final meta = await ChannelService.getChannelMeta(widget.channel.id);
      final List<String> vlcOptions = [
        '--http-user-agent=VLC/3.0.18 LibVLC/3.0.18',
        '--network-caching=3000',                     
        '--rtsp-tcp',                                 
        '--drop-late-frames',                         
        '--skip-frames',
      ];

      if (meta.containsKey('vlc-http-referrer')) {
        vlcOptions.add('--http-referrer=${meta['vlc-http-referrer']}');
      }

      final controller = VlcPlayerController.network(
        widget.channel.streamUrl,
        hwAcc: HwAcc.disabled, 
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions(vlcOptions),
          http: VlcHttpOptions([
            '--http-user-agent=VLC/3.0.18 LibVLC/3.0.18',
          ]),
        ),
      );

      _controller = controller;
      _controller!.addListener(_onPlayerStateChanged);
      setState(() {});
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Falha ao iniciar motor de descodificação de vídeo.';
        });
      }
    }
  }

  void _onPlayerStateChanged() {
    if (_controller == null || !mounted) return;

    final value = _controller!.value;

    if (value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = value.errorDescription ?? 'O stream parou inesperadamente.';
      });
      return;
    }

    final isBuffering = value.playingState == PlayingState.buffering;
    if (isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }

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
    if (_isLiveStream) return;
    if (_controller == null) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
    _scheduleHideControls();
  }

  void _fastForward() {
    if (_controller == null) return;
    final currentPosition = _controller!.value.position;
    final targetPosition = currentPosition + const Duration(seconds: 10);
    _controller!.seekTo(targetPosition);
    _scheduleHideControls();
  }

  void _rewind() {
    if (_controller == null) return;
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
        _controller?.setVolume((_volumeValue * 100).toInt());
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

  void _exitPlayer() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTap: _isLiveStream ? null : _togglePlayPause,
        onVerticalDragUpdate: (details) => _handleVerticalDragUpdate(details, size.width),
        child: Stack(
          children: [
            Center(
              child: _hasError
                  ? _buildErrorScreen()
                  : _controller != null && _controller!.value.isInitialized
                      ? _buildVideoPlayerWrapper()
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.accent),
                              SizedBox(height: 16),
                              Text(
                                'A carregar transmissão...',
                                style: TextStyle(color: AppColors.lightGray),
                              ),
                            ],
                          ),
                        ),
            ),

            if (_isBuffering && !_hasError && _controller != null)
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
    final double aspect = _controller!.value.aspectRatio <= 0 
        ? 16 / 9 
        : _controller!.value.aspectRatio;

    switch (_aspectRatioMode) {
      case AspectRatioMode.stretch:
        return SizedBox.expand(
          child: VlcPlayer(
            controller: _controller!,
            aspectRatio: MediaQuery.of(context).size.aspectRatio,
            placeholder: const Center(child: CircularProgressIndicator()),
          ),
        );
      case AspectRatioMode.zoom:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width <= 0 ? 1280 : _controller!.value.size.width.toDouble(),
              height: _controller!.value.size.height <= 0 ? 720 : _controller!.value.size.height.toDouble(),
              child: VlcPlayer(
                controller: _controller!,
                aspectRatio: aspect,
              ),
            ),
          ),
        );
      case AspectRatioMode.fit:
      default:
        return AspectRatio(
          aspectRatio: aspect,
          child: VlcPlayer(
            controller: _controller!,
            aspectRatio: aspect,
            placeholder: const Center(child: CircularProgressIndicator()),
          ),
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
                          style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.channel.groupTitle,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
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

            Expanded(
              child: Center(
                child: _isLiveStream
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TVControlWrapper(
                            onTap: _rewind,
                            child: IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.replay_10_rounded, color: AppColors.white),
                              onPressed: _rewind,
                            ),
                          ),
                          const SizedBox(width: 24),
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                                  value: _controller!.value.position.inSeconds.toDouble().clamp(
                                    0.0, 
                                    _controller!.value.duration.inSeconds.toDouble() == 0.0 
                                      ? 1.0 
                                      : _controller!.value.duration.inSeconds.toDouble()
                                  ),
                                  max: _controller!.value.duration.inSeconds.toDouble() == 0.0 
                                      ? 1.0 
                                      : _controller!.value.duration.inSeconds.toDouble(),
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
                      _buildBadge(),
                      const Spacer(),
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
              style: TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
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
          style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
              const SizedBox(height: 12),
              const Text(
                'Não foi possível reproduzir este canal',
                style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Se preferir, pode abrir o fluxo em um player externo especializado:',
                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TVControlWrapper(
                    onTap: () async {
                      final success = await ExternalPlayerService.playInVlc(widget.channel);
                      if (!success && mounted) {
                        _showInfoSnackBar('Instale o VLC Player na Google Play Store.');
                      }
                    },
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ExternalPlayerService.playInVlc(widget.channel);
                        if (!success && mounted) {
                          _showInfoSnackBar('Instale o VLC Player na Google Play Store.');
                        }
                      },
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                      label: const Text('Abrir no VLC'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TVControlWrapper(
                    onTap: () async {
                      final success = await ExternalPlayerService.playInMxPlayer(widget.channel);
                      if (!success && mounted) {
                        _showInfoSnackBar('Instale o MX Player na Google Play Store.');
                      }
                    },
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ExternalPlayerService.playInMxPlayer(widget.channel);
                        if (!success && mounted) {
                          _showInfoSnackBar('Instale o MX Player na Google Play Store.');
                        }
                      },
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                      label: const Text('Abrir no MX Player'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
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

  void _showInfoSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

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
