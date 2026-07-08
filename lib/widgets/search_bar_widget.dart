import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isExpanded;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;   // Callback disparado ao clicar para abrir
  final VoidCallback onClose; // Callback disparado ao clicar na seta de voltar/fechar

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.isExpanded,
    required this.onChanged,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AUTO-FOCUS INTELIGENTE: Quando a barra for expandida externamente,
    // requisita o foco e sobe o teclado do telemóvel automaticamente.
    if (widget.isExpanded && !oldWidget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    } else if (!widget.isExpanded && oldWidget.isExpanded) {
      _focusNode.unfocus();
    }
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      height: 44, // Altura padrão de acessibilidade para toque
      decoration: BoxDecoration(
        // Feedback visual: Se estiver ativa/focada, ganha uma borda brilhante sutil
        color: _isFocused 
            ? AppColors.mediumGray.withValues(alpha: 0.6) 
            : AppColors.mediumGray.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isFocused 
              ? AppColors.accent.withValues(alpha: 0.4) 
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // ÍCONE DINÂMICO INICIAL (Seta de Voltar quando expandido ou Lupa quando fechado)
          if (widget.isExpanded)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white, size: 20),
              onPressed: () {
                _focusNode.unfocus();
                widget.onClose();
              },
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              splashRadius: 20,
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 14, right: 6),
              child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            ),

          // CAMPO DE TEXTO DE BUSCA
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: AppColors.accent,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Pesquise canais, filmes...',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),

          // ÍCONE FINAL: Limpar texto (X) - Aparece apenas se houver algo digitado
          if (widget.isExpanded && widget.controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
              onPressed: () {
                widget.controller.clear();
                widget.onChanged(''); // Dispara o callback para resetar a pesquisa do Provider
              },
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              splashRadius: 18,
            ),
        ],
      ),
    );
  }
}
