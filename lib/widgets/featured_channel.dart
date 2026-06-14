import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../utils/app_colors.dart';

class FeaturedChannelWidget extends StatelessWidget {
  final Channel channel;
  final VoidCallback onPlay;

  const FeaturedChannelWidget({
    super.key,
    required this.channel,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.55,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background
          if (channel.logoUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: channel.logoUrl,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.6),
              colorBlendMode: BlendMode.darken,
              errorWidget: (_, __, ___) => Container(color: AppColors.darkBlue),
              placeholder: (_, __) => Container(color: AppColors.darkBlue),
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

          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x80000000),
                  Color(0xFF000000),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel logo
                  if (channel.logoUrl.isNotEmpty)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.overlay,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: channel.logoUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.tv,
                            color: AppColors.textMuted,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Channel Name
                  Text(
                    channel.name,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Category tag
                  Text(
                    '• ${channel.groupTitle}',
                    style: const TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 14,
                    ),
                  ),

                  // HTTP indicator
                  if (channel.isHttpStream)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Conexão HTTP',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      // Watch Now
                      ElevatedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text(
                          'Assistir Agora',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // More Info
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.white),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
