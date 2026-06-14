import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isExpanded;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.isExpanded,
    required this.onChanged,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.mediumGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(Icons.search, color: AppColors.textMuted, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              style: const TextStyle(color: AppColors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Buscar canais...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          if (isExpanded && controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
