// lib/features/penalty/presentation/pages/warning_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/penalty/data/services/penalty_service.dart';

class WarningPage extends StatefulWidget {
  final Map<String, dynamic> penalidade;
  final String               penalidadeKey;
  final String               uid;
  final VoidCallback         onOk;

  const WarningPage({
    super.key,
    required this.penalidade,
    required this.penalidadeKey,
    required this.uid,
    required this.onOk,
  });

  @override
  State<WarningPage> createState() => _WarningPageState();
}

class _WarningPageState extends State<WarningPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  final _service = PenaltyService();

  bool _lido        = false;
  bool _confirmando = false;

  // ── Paleta âmbar ──────────────────────────────────────────────────────────
  static const _amber900 = Color(0xFF412402);
  static const _amber800 = Color(0xFF633806);
  static const _amber600 = Color(0xFF854F0B);
  static const _amber400 = Color(0xFFBA7517);
  static const _amber200 = Color(0xFFFAC775);
  static const _amber50  = Color(0xFFFAEEDA);

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ── Getters ────────────────────────────────────────────────────────────────
  String get _proto  => widget.penalidade['protocolo']      as String? ?? '—';
  String get _artigo => widget.penalidade['artigo_violado'] as String? ?? '—';
  String get _motivo =>
      widget.penalidade['motivo_admin'] as String? ??
      widget.penalidade['motivo']       as String? ?? '—';
  String get _tipo   => widget.penalidade['tipo'] as String? ?? 'advertencia';

  String get _tituloTipo => _tipo == 'remover_conteudo'
      ? 'Conteúdo removido'
      : 'Advertência formal';

  String get _subtitulo => _tipo == 'remover_conteudo'
      ? 'Um conteúdo seu foi removido por violar os Termos de Uso da plataforma.'
      : 'Sua conta recebeu uma advertência por violação dos Termos de Uso da plataforma.';

  // ── Confirmar ──────────────────────────────────────────────────────────────
  Future<void> _confirmar() async {
    if (!_lido || _confirmando) return;
    setState(() => _confirmando = true);
    HapticFeedback.mediumImpact();
    await _service.confirmarLeitura(
      uid:           widget.uid,
      penalidadeKey: widget.penalidadeKey,
    );
    widget.onOk();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.dark,
        systemNavigationBarColor:          Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: TabuColors.bg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                  child: Column(children: [
                    // Ícone circular
                    Container(
                      width:  72,
                      height: 72,
                      decoration: BoxDecoration(
                        color:  _amber50,
                        shape:  BoxShape.circle,
                        border: Border.all(color: _amber200, width: 1.5),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: _amber400, size: 32),
                    ),
                    const SizedBox(height: 20),

                    // Badge "Notificação oficial"
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color:        _amber50,
                        borderRadius: BorderRadius.circular(20),
                        border:       Border.all(color: _amber200, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.description_outlined,
                              size: 13, color: _amber800),
                          SizedBox(width: 6),
                          Text('Notificação oficial',
                              style: TextStyle(
                                fontFamily:  TabuTypography.bodyFont,
                                fontSize:    11,
                                fontWeight:  FontWeight.w500,
                                color:       _amber800,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Título
                    Text(
                      _tituloTipo.toUpperCase(),
                      style: const TextStyle(
                        fontFamily:    TabuTypography.displayFont,
                        fontSize:      20,
                        letterSpacing: 2,
                        color:         _amber600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtítulo
                    Text(
                      _subtitulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize:   13,
                        color:      TabuColors.textoMuted,
                        height:     1.6,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Área rolável ────────────────────────────────────────────
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (!_lido &&
                          n is ScrollEndNotification &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 32) {
                        setState(() => _lido = true);
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(children: [

                        // Card de detalhes
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:        TabuColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(
                                color: TabuColors.border, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: _Campo(
                                  label:    'PROTOCOLO',
                                  valor:    _proto,
                                  corValor: _amber600,
                                )),
                                const SizedBox(width: 16),
                                Expanded(child: _Campo(
                                  label: 'DATA',
                                  valor: _formatarData(
                                      widget.penalidade['aplicada_em']),
                                )),
                              ]),
                              const SizedBox(height: 16),
                              Divider(color: TabuColors.border,
                                  height: 1, thickness: 0.5),
                              const SizedBox(height: 16),
                              _Campo(
                                  label: 'ARTIGO VIOLADO', valor: _artigo),
                              const SizedBox(height: 16),
                              _Campo(
                                label:     'DESCRIÇÃO DA INFRAÇÃO',
                                valor:     _motivo,
                                multiline: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Card informativo âmbar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:        _amber50,
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(
                                color: _amber200, width: 0.5),
                          ),
                          child: Column(children: [
                            _InfoRow(
                              icone: Icons.info_outline_rounded,
                              corpo: _tipo == 'remover_conteudo'
                                  ? 'O conteúdo foi removido permanentemente. '
                                      'Seu acesso continua ativo após confirmar a leitura.'
                                  : 'Esta advertência fica registrada no histórico da sua conta. '
                                      'Seu acesso continua ativo após confirmar a leitura.',
                            ),
                            const SizedBox(height: 12),
                            const _InfoRow(
                              icone: Icons.gavel_outlined,
                              corpo:
                                  'Reincidências podem resultar em suspensão '
                                  'temporária ou banimento permanente.',
                            ),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        // Hint de scroll
                        if (!_lido)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.keyboard_arrow_down,
                                  color: TabuColors.textoMuted, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Role até o fim para continuar',
                                style: TextStyle(
                                  fontFamily:    TabuTypography.bodyFont,
                                  fontSize:      11,
                                  color:         TabuColors.textoMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                      ]),
                    ),
                  ),
                ),

                // ── Botão ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: AnimatedOpacity(
                    opacity:  _lido ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 300),
                    child: SizedBox(
                      width:  double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _lido && !_confirmando ? _confirmar : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:        _amber600,
                          foregroundColor:        Colors.white,
                          disabledBackgroundColor: _amber600.withOpacity(0.4),
                          elevation:  0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _confirmando
                            ? const SizedBox(
                                width:  18,
                                height: 18,
                                child:  CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 1.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'ESTOU CIENTE — CONTINUAR',
                                    style: TextStyle(
                                      fontFamily:    TabuTypography.bodyFont,
                                      fontSize:      12,
                                      fontWeight:    FontWeight.w500,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _formatarData(dynamic ms) {
  if (ms == null) return '—';
  final v = ms is int ? ms : int.tryParse(ms.toString()) ?? 0;
  if (v == 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(v);
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.label,
    required this.valor,
    this.corValor,
    this.multiline = false,
  });
  final String  label;
  final String  valor;
  final Color?  corValor;
  final bool    multiline;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      9,
                fontWeight:    FontWeight.w500,
                letterSpacing: 2,
                color:         TabuColors.textoMuted,
              )),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      corValor ?? TabuColors.textoPrincipal,
                height:     multiline ? 1.6 : 1.3,
              )),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icone, required this.corpo});
  final IconData icone;
  final String   corpo;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16,
              color: const Color(0xFFBA7517)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(corpo,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize:   12,
                  color:      Color(0xFF633806),
                  height:     1.6,
                )),
          ),
        ],
      );
}