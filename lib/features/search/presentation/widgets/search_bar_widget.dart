// lib/features/search/presentation/widgets/search_bar_widget.dart

import 'package:flutter/material.dart';

/// Widget de barra de busca reutilizável.
///
/// Responsabilidade: Capturar input de texto do usuário e notificar via callback.
/// Gerencia internamente o foco e o controller de texto.
/// Completamente desacoplado do BLoC — comunica via callbacks.
class SearchBarWidget extends StatefulWidget {
  /// Callback disparado a cada mudança de texto.
  final ValueChanged<String> onChanged;

  /// Callback disparado ao limpar o campo.
  final VoidCallback? onClear;

  /// Placeholder exibido quando o campo está vazio.
  final String hint;

  /// Valor inicial do campo (usado para restaurar estado).
  final String initialValue;

  const SearchBarWidget({
    super.key,
    required this.onChanged,
    this.onClear,
    this.hint = 'Buscar...',
    this.initialValue = '',
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza o texto se o valor inicial mudou externamente (ex: limpar filtros)
    if (widget.initialValue != oldWidget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clear,
                tooltip: 'Limpar busca',
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

