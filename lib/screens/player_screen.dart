import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';

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
    // Force landscape for player
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      final uri = Uri.parse(widget.channel.streamUrl);
      _controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: {
          'User-Agent': 'AngoMovie/1.2.0 Android',
        },
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {});
        await _controller!.play();
        _controller!.addListener(_onPlayerStateChanged);
      }
    } catch (e) {
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
        _controlsAnimController.forward();
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _toggleControls() {
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

  void _seekBackward() {
    if (_controller == null) return;
    final position = _controller!.value.position;
    _controller!.seekTo(
      position - const Duration(seconds: 10),
    );
    _scheduleHideControls();
  }

  void _seekForward() {
    if (_controller == null) return;
    final position = _controller!.value.position;
    _controller!.seekTo(
      position + const Duration(seconds: 10),
    );
    _scheduleHideControls();
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
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video Player
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

            // Controls Overlay
            if (!_hasError)
              AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: 1.0 - _controlsAnimation.value,
                    child: child,
                  );
                },
                child: _buildControls(),
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
          stops: [0.0, 0.2, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _exitPlayer,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                // HTTP indicator
                if (widget.channel.isHttpStream)
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
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.white, size: 22),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Center controls
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Seek backward
                  GestureDetector(
                    onTap: _seekBackward,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.replay_10, color: AppColors.white, size: 36),
                      ],
                    ),
                  ),

                  const SizedBox(width: 40),

                  // Play/Pause
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
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

                  const SizedBox(width: 40),

                  // Seek forward
                  GestureDetector(
                    onTap: _seekForward,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward_10, color: AppColors.white, size: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Progress bar (live indicator)
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: null, // Indeterminate for live
                        backgroundColor: AppColors.mediumGray,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      icon: const Icon(Icons.volume_up,
                          color: AppColors.white, size: 22),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen,
                          color: AppColors.white, size: 22),
                      onPressed: () {},
                    ),
                  ],
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
