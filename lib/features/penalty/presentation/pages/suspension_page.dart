// lib/features/penalty/presentation/pages/suspension_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/presentation/pages/login_screen.dart';
import 'package:tabuapp/features/penalty/data/services/penalty_service.dart';
import 'package:tabuapp/features/penalty/presentation/widgets/contest_sheet.dart';


class SuspensionPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String               uid;

  const SuspensionPage({
    super.key,
    required this.userData,
    required this.uid,
  });

  @override
  State<SuspensionPage> createState() => _SuspensionPageState();
}

class _SuspensionPageState extends State<SuspensionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;

  final _service = PenaltyService();

  Timer?    _timer;
  Duration  _restante = Duration.zero;
  bool      _verificando = false;

  static const _cor      = Color(0xFF92400E);
  static const _corFundo = Color(0xFFFFFBEB);
  static const _corBorda = Color(0xFFFDE68A);
  static const _corSep   = Color(0xFFFCD34D);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _atualizar();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _atualizar();
    });
  }

  // ── Atualiza o contador regressivo ─────────────────────────────────────────
  void _atualizar() {
    final fim = widget.userData['suspensao_fim'];
    if (fim == null) {
      setState(() => _restante = Duration.zero);
      return;
    }
    final fimMs = fim is int ? fim : int.tryParse(fim.toString()) ?? 0;
    final diff  = DateTime.fromMillisecondsSinceEpoch(fimMs)
        .difference(DateTime.now());
    setState(() => _restante = diff.isNegative ? Duration.zero : diff);
  }

  // ── Verificar e liberar suspensão ──────────────────────────────────────────
  /// Chamado quando o usuário toca em "Já passou o prazo? Verificar agora".
  /// Consulta o banco — se o prazo expirou, limpa os campos e vai para login
  /// (o AuthGuard detecta o novo estado e libera o acesso normalmente).
  Future<void> _verificarSuspensao() async {
    if (_verificando) return;
    setState(() => _verificando = true);
    HapticFeedback.mediumImpact();

    try {
      final liberado =
          await _service.verificarELiberarSuspensao(widget.uid);

      if (!mounted) return;

      if (liberado) {
        // Suspensão levantada — desloga para que o AuthGuard reavalie
        // com os dados limpos e libere o acesso normalmente.
        await _service.fazerLogout(widget.uid);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        // Ainda suspenso
        setState(() => _verificando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Sua suspensão ainda está ativa. '
              'Aguarde o prazo encerrar.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        .where((e) => e['tipo'] == 'suspensao')
        .fold<Map<String, dynamic>?>(null, (prev, curr) {
          if (prev == null) return curr;
          return ((curr['aplicada_em'] ?? 0) as int) >=
                  ((prev['aplicada_em'] ?? 0) as int)
              ? curr
              : prev;
        }) ??
        {};
  }

  @override
  Widget build(BuildContext context) {
    final pen       = _pen;
    final proto     = pen['protocolo']      as String? ?? '—';
    final artigo    = pen['artigo_violado'] as String? ?? '—';
    final motivo    = pen['motivo_admin']   as String?
        ?? pen['motivo']      as String? ?? '—';
    final fimMs     = widget.userData['suspensao_fim'];
    final fimStr    = _formatarData(fimMs);
    final inicioMs  = pen['suspensao_inicio'] ?? pen['aplicada_em'];
    final inicioStr = _formatarData(inicioMs);
    final emailUser = widget.userData['email'] as String? ?? '';

    final dias    = _restante.inDays;
    final horas   = _restante.inHours.remainder(24);
    final minutos = _restante.inMinutes.remainder(60);
    final segs    = _restante.inSeconds.remainder(60);
    final expirou = _restante == Duration.zero;

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 36),
              child: Column(children: [

                // ── Ícone ──────────────────────────────────────────────────
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color:  _corFundo,
                    shape:  BoxShape.circle,
                    border: Border.all(color: _corBorda, width: 1.5),
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: _cor, size: 32),
                ),
                const SizedBox(height: 18),

                // ── Título ─────────────────────────────────────────────────
                Text('CONTA SUSPENSA',
                    style: TextStyle(
                      fontFamily:    TabuTypography.displayFont,
                      fontSize:      24,
                      letterSpacing: 3,
                      color:         _cor,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Seu acesso foi temporariamente suspenso\n'
                  'por violação dos Termos de Uso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize:   13,
                    color:      TabuColors.textoMuted,
                    height:     1.6,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Contador ───────────────────────────────────────────────
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color:  _corFundo,
                    border: Border.all(color: _corBorda, width: 0.8),
                  ),
                  child: Column(children: [
                    Text(
                      expirou ? 'PRAZO ENCERRADO' : 'TEMPO RESTANTE',
                      style: const TextStyle(
                        fontFamily:    TabuTypography.bodyFont,
                        fontSize:      9,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 3,
                        color:         _cor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!expirou)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Unit(valor: dias,    label: 'DIAS', cor: _cor),
                          _Sep(cor: _corSep),
                          _Unit(valor: horas,   label: 'HRS',  cor: _cor),
                          _Sep(cor: _corSep),
                          _Unit(valor: minutos, label: 'MIN',  cor: _cor),
                          _Sep(cor: _corSep),
                          _Unit(valor: segs,    label: 'SEG',  cor: _cor),
                        ],
                      )
                    else
                      // Prazo zerado — mostra mensagem de verificação
                      Column(children: [
                        const Icon(Icons.check_circle_outline,
                            color: _cor, size: 36),
                        const SizedBox(height: 8),
                        const Text(
                          'O prazo da suspensão chegou ao fim.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize:   13,
                            color:      _cor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),

                    const SizedBox(height: 12),
                    Text(
                      expirou
                          ? 'Faça login novamente para retomar o acesso.'
                          : 'Suspensão encerra em $fimStr',
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize:   11,
                        color:      TabuColors.textoMuted,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Aviso: acesso restaurado ao logar ─────────────────────
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
                      Expanded(
                        child: Text(
                          'Seu acesso não é restaurado automaticamente. '
                          'Após o prazo encerrar, faça login novamente '
                          'para retomar o acesso à plataforma.',
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize:   12,
                            color:      _cor,
                            height:     1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Detalhes ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:  TabuColors.bgCard,
                    border: Border.all(
                        color: TabuColors.border, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: _Campo(
                            label:    'PROTOCOLO',
                            valor:    proto,
                            corValor: _cor)),
                        const SizedBox(width: 16),
                        Expanded(child: _Campo(
                            label: 'INÍCIO',
                            valor: inicioStr)),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(
                          color: TabuColors.border,
                          height: 1, thickness: 0.8),
                      const SizedBox(height: 16),
                      _Campo(label: 'ARTIGO VIOLADO', valor: artigo),
                      const SizedBox(height: 16),
                      _Campo(
                          label:     'MOTIVO DA SUSPENSÃO',
                          valor:     motivo,
                          multiline: true),
                      const SizedBox(height: 16),
                      const Divider(
                          color: TabuColors.border,
                          height: 1, thickness: 0.8),
                      const SizedBox(height: 16),
                      const _InfoRow(
                        icone: Icons.gavel_outlined,
                        corpo: 'Novas infrações após o retorno podem resultar '
                            'em banimento permanente da plataforma.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Verificar agora (se prazo zerou) ──────────────────────
                if (expirou) ...[
                  SizedBox(
                    width:  double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _verificando ? null : _verificarSuspensao,
                      icon: _verificando
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 1.5))
                          : const Icon(Icons.login_outlined, size: 17),
                      label: Text(
                          _verificando
                              ? 'VERIFICANDO...'
                              : 'VERIFICAR E FAZER LOGIN',
                          style: const TextStyle(
                            fontFamily:    TabuTypography.bodyFont,
                            fontSize:      12,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 2,
                          )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _cor.withOpacity(0.5),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Contestar ──────────────────────────────────────────────
                SizedBox(
                  width:  double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => ContestSheet.show(
                      context,
                      proto: proto,
                      email: emailUser,
                      tipo:  TipoContestacao.suspensao,
                    ),
                    icon: const Icon(Icons.mail_outline, size: 17),
                    label: const Text('CONTESTAR SUSPENSÃO',
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
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _Unit extends StatelessWidget {
  const _Unit({required this.valor, required this.label, required this.cor});
  final int    valor;
  final String label;
  final Color  cor;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(valor.toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize:   36,
              color:      cor,
              height:     1,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      8,
              fontWeight:    FontWeight.w700,
              letterSpacing: 2,
              color:         TabuColors.textoMuted,
            )),
      ]);
}

class _Sep extends StatelessWidget {
  const _Sep({required this.cor});
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
        child: Text(':',
            style: TextStyle(
              fontSize:   28,
              fontWeight: FontWeight.w300,
              color:      cor,
              height:     1.2,
            )),
      );
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icone, required this.corpo});
  final IconData icone;
  final String   corpo;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 15, color: TabuColors.textoMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(corpo,
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize:   12,
                color:      TabuColors.textoMuted,
                height:     1.6,
              ))),
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