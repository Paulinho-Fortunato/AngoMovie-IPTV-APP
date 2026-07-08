// lib/widgets/channel_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importação essencial para comandos físicos de teclado/TV
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';

class ChannelCard extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;
  final double? width; 

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.width,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false; // Estado de foco do comando de TV

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escala dinâmica: Se focado pelo comando de TV, expande para 1.08x
    final double currentScale = _isFocused ? 1.08 : _scaleAnimation.value;

    return Focus(
      // 1. Ouvinte de alteração de foco físico (D-PAD)
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
        if (hasFocus) {
          // AUTO-SCROLL DA TV: Quando focado, rola a lista de forma suave para centralizar este item
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
            alignment: 0.5, // Centraliza o widget focado horizontalmente/verticalmente
            curve: Curves.easeInOut,
          );
        }
      },
      
      // 2. Interceptador de cliques físicos (Botão "OK" ou "Center Select" do comando)
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
      
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: AnimatedScale(
          scale: currentScale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Container(
            width: widget.width,
            margin: widget.width != null ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.darkGray,
              borderRadius: BorderRadius.circular(12),
              // Feedback visual de TV: Adiciona uma borda ativa do AngoMovie
              border: Border.all(
                color: _isFocused ? AppColors.accent : Colors.transparent,
                width: _isFocused ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isFocused 
                      ? AppColors.accent.withValues(alpha: 0.45) // Brilho pulsante
                      : Colors.black.withValues(alpha: 0.4),
                  blurRadius: _isFocused ? 12 : 6,
                  offset: Offset(0, _isFocused ? 4 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.channel.logoUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.channel.logoUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 180, 
                      memCacheHeight: 180,
                      placeholder: (_, __) => _buildPlaceholder(),
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  else
                    _buildPlaceholder(),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Text(
                      widget.channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  if (widget.channel.isFavorite)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.redAccent.shade400,
                        size: 16,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),

                  if (widget.channel.isHttpStream)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final initial = widget.channel.name.isNotEmpty 
        ? widget.channel.name.substring(0, 1).toUpperCase() 
        : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mediumGray.withValues(alpha: 0.6),
            AppColors.darkGray,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tv_outlined, 
              color: AppColors.accent.withValues(alpha: 0.35), 
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              initial,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.25),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
