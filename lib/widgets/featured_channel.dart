import 'dart:ui'; // Necessário para usar ImageFilter (Efeito Blur)
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';

class FeaturedChannelWidget extends StatelessWidget {
  final Channel channel;
  final VoidCallback onPlay;
  final VoidCallback onFavoriteToggle; // Novo callback para favoritar diretamente no banner

  const FeaturedChannelWidget({
    super.key,
    required this.channel,
    required this.onPlay,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      // Limita a altura do banner para evitar exageros em ecrãs muito grandes (Tablets / Dobráveis)
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.55 > 450 ? 450 : screenHeight * 0.55,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // CAMADA 1: Fundo Desfocado Ambiental (Glassmorphism Glow)
          if (channel.logoUrl.isNotEmpty)
            ClipRect( // Impede que o efeito de desfoque transborde para fora do banner
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: channel.logoUrl,
                    fit: BoxFit.cover,
                    
                    // PERFORMANCE EXTREMA: Como o fundo é totalmente desfocado, 
                    // usar uma resolução baixíssima economiza até 95% de memória RAM!
                    memCacheWidth: 150, 
                    memCacheHeight: 150,
                    
                    errorWidget: (_, __, ___) => Container(color: AppColors.background),
                    placeholder: (_, __) => Container(color: AppColors.background),
                  ),
                  // Desfoque Gaussiano real por cima da imagem
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45), // Escurece o brilho de fundo
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.darkBlue, AppColors.background],
                ),
              ),
            ),

          // CAMADA 2: Sobreposição de Degradê Cinematográfico (Garante contraste e legibilidade das informações)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x33000000),
                  Color(0xCC000000),
                  Color(0xFF060E1A), // Transiciona suavemente para a cor de fundo do app
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),

          // CAMADA 3: Conteúdo e Botões de Ação
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logotipo Pequeno do Canal em Destaque
                  if (channel.logoUrl.isNotEmpty)
                    Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: channel.logoUrl,
                          fit: BoxFit.contain,
                          memCacheWidth: 150, // Limita RAM da miniatura
                          memCacheHeight: 150,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.tv_outlined,
                            color: AppColors.textMuted,
                            size: 32,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Tag de Categoria com Visual Premium
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      channel.groupTitle.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Nome do Canal com Sombra Projetada
                  Text(
                    channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                      ],
                    ),
                  ),

                  // Indicador de Fluxo HTTP Inseguro
                  if (channel.isHttpStream)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Ligação HTTP Insegura',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Botões de Interação (Assistir & Favoritar)
                  Row(
                    children: [
                      // Botão: Assistir Agora (Principal)
                      ElevatedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text(
                          'ASSISTIR AGORA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.white,
                          elevation: 3,
                          shadowColor: AppColors.accent.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Botão: Favoritar (Reativo e Dinâmico)
                      OutlinedButton.icon(
                        onPressed: onFavoriteToggle,
                        icon: Icon(
                          channel.isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                          color: channel.isFavorite ? Colors.redAccent.shade400 : AppColors.white,
                          size: 18,
                        ),
                        label: Text(
                          channel.isFavorite ? 'FAVORITO' : 'FAVORITAR',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white,
                          side: BorderSide(
                            color: channel.isFavorite 
                              ? Colors.redAccent.shade400.withValues(alpha: 0.5) 
                              : AppColors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          backgroundColor: channel.isFavorite 
                            ? Colors.redAccent.shade400.withValues(alpha: 0.05) 
                            : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
