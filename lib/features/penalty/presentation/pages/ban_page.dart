// lib/features/penalty/presentation/pages/ban_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/presentation/pages/login_screen.dart';
import 'package:tabuapp/features/penalty/data/services/penalty_service.dart';
import 'package:tabuapp/features/penalty/presentation/widgets/contest_sheet.dart';

class BanPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const BanPage({
    super.key,
    required this.userData,
    required this.uid,
  });

  @override
  State<BanPage> createState() => _BanPageState();
}

class _BanPageState extends State<BanPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  final _service = PenaltyService();

  bool _confirmandoLogout = false;
  bool _carregando        = false;

  static const _cor      = TabuColors.errorDeep;
  static const _corFundo = TabuColors.errorPale;
  static const _corBorda = TabuColors.errorBorder;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _pen {
    final pens = widget.userData['penalidades'];
    if (pens is! Map) return {};
    return (pens as Map)
        .values
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .where((e) => e['tipo'] == 'banimento')
        .fold<Map<String, dynamic>?>(null, (prev, curr) {
          if (prev == null) return curr;
          return ((curr['aplicada_em'] ?? 0) as int) >=
                  ((prev['aplicada_em'] ?? 0) as int)
              ? curr
              : prev;
        }) ??
        {};
  }

  Future<void> _logout() async {
    if (_carregando) return;

    if (!_confirmandoLogout) {
      HapticFeedback.mediumImpact();
      setState(() => _confirmandoLogout = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _confirmandoLogout = false);
      });
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _carregando = true);

    try {
      await _service.fazerLogout(widget.uid);
    } catch (e) {
      debugPrint('[BanPage] Erro no logout: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pen       = _pen;
    final proto     = pen['protocolo']      as String? ?? '—';
    final artigo    = pen['artigo_violado'] as String? ?? '—';
    final motivo    = pen['motivo_admin']   as String?
        ?? pen['motivo']      as String? ?? '—';
    final banidoMs  = widget.userData['banido_em'] ?? pen['aplicada_em'];
    final banidoStr = _formatarData(banidoMs);
    final emailUser = widget.userData['email'] as String? ?? '';

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 36),
                child: Column(children: [

                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color:  _corFundo,
                      shape:  BoxShape.circle,
                      border: Border.all(color: _corBorda, width: 1.5),
                    ),
                    child: const Icon(Icons.gavel_rounded,
                        color: _cor, size: 34),
                  ),
                  const SizedBox(height: 18),

                  Text('CONTA BANIDA',
                      style: TextStyle(
                        fontFamily:    TabuTypography.displayFont,
                        fontSize:      26,
                        letterSpacing: 4,
                        color:         _cor,
                      )),
                  const SizedBox(height: 8),

                  const Text(
                    'Seu acesso ao Tabu foi encerrado permanentemente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize:   13,
                      color:      TabuColors.textoMuted,
                      height:     1.6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color:  _corFundo,
                      border: Border.all(color: _corBorda, width: 0.8),
                    ),
                    child: const Text(
                      'BANIMENTO PERMANENTE · SEM REVERSÃO AUTOMÁTICA',
                      style: TextStyle(
                        fontFamily:    TabuTypography.bodyFont,
                        fontSize:      9,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 1.5,
                        color:         _cor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:  TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: _Campo(
                              label: 'PROTOCOLO', valor: proto, corValor: _cor)),
                          const SizedBox(width: 16),
                          Expanded(child: _Campo(
                              label: 'DATA DO BANIMENTO', valor: banidoStr)),
                        ]),
                        const SizedBox(height: 16),
                        const Divider(
                            color: TabuColors.border, height: 1, thickness: 0.8),
                        const SizedBox(height: 16),
                        _Campo(label: 'ARTIGO VIOLADO', valor: artigo),
                        const SizedBox(height: 16),
                        _Campo(label: 'MOTIVO', valor: motivo, multiline: true),
                        const SizedBox(height: 16),
                        const Divider(
                            color: TabuColors.border, height: 1, thickness: 0.8),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:  _corFundo,
                            border: Border.all(color: _corBorda, width: 0.8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.info_outline, size: 15, color: _cor),
                              SizedBox(width: 10),
                              Expanded(child: Text(
                                'Este banimento foi aplicado pela equipe de '
                                'moderação após análise criteriosa e é definitivo.',
                                style: TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize:   12,
                                  color:      TabuColors.textoPrincipal,
                                  height:     1.6,
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Contestar — usa o widget compartilhado ────────────────
                  SizedBox(
                    width:  double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => ContestSheet.show(
                        context,
                        proto: proto,
                        email: emailUser,
                        tipo:  TipoContestacao.banimento,
                      ),
                      icon: const Icon(Icons.mail_outline, size: 17),
                      label: const Text('CONTESTAR BANIMENTO',
                          style: TextStyle(
                            fontFamily:    TabuTypography.bodyFont,
                            fontSize:      12,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 2,
                          )),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TabuColors.textoMuted,
                        side: const BorderSide(
                            color: TabuColors.border, width: 0.8),
                        shape: const RoundedRectangleBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve:    Curves.easeOut,
                    child: SizedBox(
                      width:  double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _carregando ? null : _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _confirmandoLogout
                              ? TabuColors.error : TabuColors.bgCard,
                          foregroundColor: _confirmandoLogout
                              ? TabuColors.textoSobreRosa : TabuColors.textoMuted,
                          disabledBackgroundColor:
                              TabuColors.error.withOpacity(0.5),
                          elevation:   0,
                          shadowColor: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            side: BorderSide(
                                color: TabuColors.border, width: 0.8),
                          ),
                        ),
                        child: _carregando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: TabuColors.textoSobreRosa,
                                    strokeWidth: 1.5))
                            : Text(
                                _confirmandoLogout
                                    ? 'CONFIRMAR — SAIR DA CONTA'
                                    : 'SAIR DA CONTA',
                                style: const TextStyle(
                                  fontFamily:    TabuTypography.bodyFont,
                                  fontSize:      13,
                                  fontWeight:    FontWeight.w800,
                                  letterSpacing: 2,
                                )),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text('Protocolo $proto · guarde para referência',
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize:   10,
                        color:      TabuColors.textoMuted,
                      )),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.label,
    required this.valor,
    this.corValor,
    this.multiline = false,
  });
  final String label;
  final String valor;
  final Color? corValor;
  final bool   multiline;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      9,
                fontWeight:    FontWeight.w700,
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