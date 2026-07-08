import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';

class ChannelCard extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;
  
  // Largura opcional: Permite que o cartão seja flexível dentro de Grids
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
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          // Se width for null, ele se adapta ao pai (perfeito para GridView)
          width: widget.width,
          margin: widget.width != null ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: AppColors.darkGray,
            borderRadius: BorderRadius.circular(12), // Cantos arredondados premium
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // CAMADA 1: Renderização do Logotipo do Canal
                if (widget.channel.logoUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: widget.channel.logoUrl,
                    fit: BoxFit.contain,
                    
                    // PERFORMANCE CRÍTICA: Limita a resolução na memória RAM (Otimiza até 90% de RAM)
                    memCacheWidth: 180, 
                    memCacheHeight: 180,
                    
                    placeholder: (_, __) => _buildPlaceholder(),
                    errorWidget: (_, __, ___) => _buildPlaceholder(),
                  )
                else
                  _buildPlaceholder(),

                // CAMADA 2: Sombra em Degradê inferior para legibilidade do texto
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

                // CAMADA 3: Nome do Canal centralizado na base
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

                // CAMADA 4: Indicador de Canal Favoritado (Coração)
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

                // CAMADA 5: Badge de aviso de fluxo HTTP Inseguro
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
    );
  }

  /// Construtor de Placeholder Premium (Usado quando a imagem está carregando ou falha)
  Widget _buildPlaceholder() {
    // Pega a primeira letra do canal como inicial
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
