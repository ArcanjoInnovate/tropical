// lib/features/search/presentation/widgets/filter_dropdown.dart

import 'package:flutter/material.dart';
import 'package:tclub/features/search/data/services/ibge_service.dart';

import '../../../../core/theme/tclub_theme.dart';

/// Widget de dropdown para filtros de localização (estado, cidade, bairro).
class FilterDropdown extends StatefulWidget {
  final IbgeService ibgeService;
  final List<String>? bairros;
  final String? selectedEstado;
  final String? selectedCidade;
  final String? selectedBairro;
  final void Function({
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  }) onApply;

  const FilterDropdown({
    super.key,
    required this.ibgeService,
    required this.onApply,
    this.bairros,
    this.selectedEstado,
    this.selectedCidade,
    this.selectedBairro,
  });

  @override
  State<FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown> {
  // ── Seleções (usamos sigla/nome como String — sem comparação por referência)

  String? _estadoSigla;
  String? _cidadeNome;
  String? _bairro;

  // ── Dados carregados da API IBGE ─────────────────────────────────────────

  List<EstadoIbge> _estados = [];
  List<CidadeIbge> _cidades = [];

  // ── Estado de carregamento/erro ──────────────────────────────────────────

  bool _loadingEstados = false;
  bool _loadingCidades = false;
  String? _errorEstados;
  String? _errorCidades;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _estadoSigla = widget.selectedEstado;
    _cidadeNome = widget.selectedCidade;
    _bairro = widget.selectedBairro;

    _loadEstados();

    if (_estadoSigla != null) {
      _loadCidades(_estadoSigla!);
    }
  }

  @override
  void didUpdateWidget(FilterDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedEstado != oldWidget.selectedEstado) {
      setState(() => _estadoSigla = widget.selectedEstado);
    }
    if (widget.selectedCidade != oldWidget.selectedCidade) {
      setState(() => _cidadeNome = widget.selectedCidade);
    }
    if (widget.selectedBairro != oldWidget.selectedBairro) {
      setState(() => _bairro = widget.selectedBairro);
    }
  }

  // ── Carregamento ─────────────────────────────────────────────────────────

  Future<void> _loadEstados() async {
    if (!mounted) return;
    setState(() {
      _loadingEstados = true;
      _errorEstados = null;
    });

    try {
      final estados = await widget.ibgeService.fetchEstados();
      if (!mounted) return;
      setState(() => _estados = estados);
    } on IbgeServiceException catch (e) {
      if (!mounted) return;
      setState(() => _errorEstados = 'Erro ao carregar estados: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorEstados = 'Erro ao carregar estados.');
    } finally {
      if (mounted) setState(() => _loadingEstados = false);
    }
  }

  Future<void> _loadCidades(String uf) async {
    if (!mounted) return;
    setState(() {
      _loadingCidades = true;
      _errorCidades = null;
      _cidades = [];
    });

    try {
      final cidades = await widget.ibgeService.fetchCidades(uf);
      if (!mounted) return;
      setState(() => _cidades = cidades);
    } on IbgeServiceException catch (e) {
      if (!mounted) return;
      setState(() => _errorCidades = 'Erro ao carregar cidades: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorCidades = 'Erro ao carregar cidades.');
    } finally {
      if (mounted) setState(() => _loadingCidades = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Dropdown Estado ──────────────────────────────────────────────
        if (_loadingEstados)
          const _LoadingField(label: 'Estado')
        else if (_errorEstados != null)
          _ErrorField(
            label: 'Estado',
            message: _errorEstados!,
            onRetry: _loadEstados,
          )
        else
          _buildEstadoDropdown(),

        const SizedBox(height: 8),

        // ── Dropdown Cidade ──────────────────────────────────────────────
        if (_estadoSigla != null && _loadingCidades)
          const _LoadingField(label: 'Cidade')
        else if (_errorCidades != null)
          _ErrorField(
            label: 'Cidade',
            message: _errorCidades!,
            onRetry: () => _loadCidades(_estadoSigla!),
          )
        else
          _buildCidadeDropdown(),

        // ── Dropdown Bairro (opcional) ───────────────────────────────────
        if (widget.bairros != null && widget.bairros!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildBairroDropdown(),
        ],

        const SizedBox(height: 16),

        // ── Botões ───────────────────────────────────────────────────────
        _buildActionButtons(),
      ],
    );
  }

  // ── Dropdowns ────────────────────────────────────────────────────────────

  /// 🔥 CORREÇÃO: usa String? (sigla) como tipo do dropdown — evita comparação
  /// por referência de objetos EstadoIbge sem operator==.
  Widget _buildEstadoDropdown() {
    return DropdownButtonFormField<String>(
      value: _estadoSigla,
      dropdownColor: TClubTheme.main.scaffoldBackgroundColor,
      decoration: InputDecoration(
        labelText: 'Estado',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Todos', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ..._estados.map(
          (e) => DropdownMenuItem<String>(
            value: e.sigla,
            child: Text('${e.sigla} — ${e.nome}'),
          ),
        ),
      ],
      onChanged: (sigla) {
        setState(() {
          _estadoSigla = sigla;
          _cidadeNome = null;
          _bairro = null;
          _cidades = [];
        });
        if (sigla != null) {
          _loadCidades(sigla);
        }
      },
    );
  }

  /// 🔥 CORREÇÃO: usa String? (nome) como tipo do dropdown — mesma razão.
  Widget _buildCidadeDropdown() {
    final enabled = _estadoSigla != null && _cidades.isNotEmpty;

    return DropdownButtonFormField<String>(
      value: _cidadeNome,
      dropdownColor: TClubTheme.main.scaffoldBackgroundColor,
      decoration: InputDecoration(
        labelText: 'Cidade',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabled: enabled,
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Todas', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ..._cidades.map(
          (c) => DropdownMenuItem<String>(
            value: c.nome,
            child: Text(c.nome),
          ),
        ),
      ],
      onChanged: enabled
          ? (nome) {
              setState(() {
                _cidadeNome = nome;
                _bairro = null;
              });
            }
          : null,
    );
  }

  Widget _buildBairroDropdown() {
    return DropdownButtonFormField<String>(
      value: _bairro,
      dropdownColor: TClubTheme.main.scaffoldBackgroundColor,
      decoration: InputDecoration(
        labelText: 'Bairro',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabled: _cidadeNome != null,
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Todos', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ...widget.bairros!.map(
          (b) => DropdownMenuItem<String>(value: b, child: Text(b)),
        ),
      ],
      onChanged: _cidadeNome != null
          ? (value) => setState(() => _bairro = value)
          : null,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _estadoSigla = null;
                _cidadeNome = null;
                _bairro = null;
                _cidades = [];
              });
              widget.onApply(
                estadoSigla: null,
                cidadeNome: null,
                bairro: null,
              );
            },
            child: const Text('Limpar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => widget.onApply(
              estadoSigla: _estadoSigla,
              cidadeNome: _cidadeNome,
              bairro: _bairro,
            ),
            child: const Text('Aplicar'),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ───────────────────────────────────────────────────────

class _LoadingField extends StatelessWidget {
  final String label;
  const _LoadingField({required this.label});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Carregando...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorField extends StatelessWidget {
  final String label;
  final String message;
  final VoidCallback onRetry;

  const _ErrorField({
    required this.label,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Tentar novamente',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

