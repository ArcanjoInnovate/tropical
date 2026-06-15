// lib/features/penalty/presentation/widgets/contest_sheet.dart
//
// Widget reutilizável de contestação — usado por BanPage e SuspensionPage.
// Abre como BottomSheet com 3 passos + botão mailto pré-preenchido.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tclub/core/theme/tclub_theme.dart';

enum TipoContestacao { banimento, suspensao }

class ContestSheet extends StatelessWidget {
  final String           proto;
  final String           email;
  final TipoContestacao  tipo;

  const ContestSheet({
    super.key,
    required this.proto,
    required this.email,
    required this.tipo,
  });

  static const _suporte = 'tclubadministrative@gmail.com';

  // ── Paleta vermelha para ban, âmbar para suspensão ────────────────────────
  Color get _cor      => tipo == TipoContestacao.banimento
      ? TClubColors.errorDeep
      : const Color(0xFF92400E);
  Color get _corFundo => tipo == TipoContestacao.banimento
      ? TClubColors.errorPale
      : const Color(0xFFFFFBEB);
  Color get _corBorda => tipo == TipoContestacao.banimento
      ? TClubColors.errorBorder
      : const Color(0xFFFDE68A);

  String get _tituloSheet => tipo == TipoContestacao.banimento
      ? 'Como contestar o banimento'
      : 'Como contestar a suspensão';
  String get _labelBotao  => tipo == TipoContestacao.banimento
      ? 'ABRIR E-MAIL E CONTESTAR'
      : 'ABRIR E-MAIL E CONTESTAR';
  String get _assuntoEmail => tipo == TipoContestacao.banimento
      ? 'Contestação de banimento – $proto'
      : 'Contestação de suspensão – $proto';
  String get _tipoLabel => tipo == TipoContestacao.banimento
      ? 'banimento' : 'suspensão';

  Future<void> _abrirEmail(BuildContext context) async {
    final assunto = Uri.encodeComponent(_assuntoEmail);
    final corpo   = Uri.encodeComponent(
        'Olá,\n\nGostaria de contestar o(a) $_tipoLabel aplicado(a) '
        'à minha conta.\n\n'
        'Protocolo: $proto\n'
        'E-mail da conta: $email\n\n'
        'Motivo da contestação:\n[Descreva aqui]\n\n'
        'Atenciosamente,');

    final uri = Uri.parse('mailto:$_suporte?subject=$assunto&body=$corpo');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível abrir o aplicativo de e-mail.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Abre o sheet. Use este método no lugar de showModalBottomSheet direto.
  static void show(
    BuildContext context, {
    required String          proto,
    required String          email,
    required TipoContestacao tipo,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => ContestSheet(proto: proto, email: email, tipo: tipo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        TClubColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border:       Border.all(color: TClubColors.border, width: 0.5),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24,
          24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize:      MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        TClubColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 20),

          // Título
          Text(_tituloSheet,
              style: const TextStyle(
                fontFamily:    TClubTypography.displayFont,
                fontSize:      16,
                letterSpacing: 1,
                color:         TClubColors.textoPrincipal,
              )),
          const SizedBox(height: 4),
          const Text('Siga os passos abaixo para enviar sua contestação.',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize:   12,
                color:      TClubColors.textoMuted,
              )),
          const SizedBox(height: 20),

          // Passo 1
          _Passo(
            numero:  '1',
            titulo:  'Abra seu e-mail',
            corpo:   'Acesse a caixa de entrada do e-mail cadastrado na sua '
                     'conta Tclub e localize o e-mail com o assunto '
                     '"Notificação de penalidade".',
            cor:     _cor,
            corFundo: _corFundo,
            corBorda: _corBorda,
          ),
          const SizedBox(height: 12),

          // Passo 2
          _Passo(
            numero:  '2',
            titulo:  'Localize o protocolo',
            corpo:   'O e-mail contém o número de protocolo. O seu é:',
            cor:     _cor,
            corFundo: _corFundo,
            corBorda: _corBorda,
            extra: proto != '—'
                ? _ProtoBox(
                    proto:    proto,
                    cor:      _cor,
                    corFundo: _corFundo,
                    corBorda: _corBorda,
                    context:  context,
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // Passo 3
          _Passo(
            numero:  '3',
            titulo:  'Envie a contestação',
            corpo:   'Escreva para $_suporte com o protocolo, seu nome '
                     'e o motivo da contestação. Responderemos em até '
                     '5 dias úteis.',
            cor:     _cor,
            corFundo: _corFundo,
            corBorda: _corBorda,
          ),
          const SizedBox(height: 24),

          // Botão
          SizedBox(
            width:  double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _abrirEmail(context),
              icon:  const Icon(Icons.open_in_new, size: 17),
              label: Text(_labelBotao,
                  style: const TextStyle(
                    fontFamily:    TClubTypography.bodyFont,
                    fontSize:      12,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cor,
                foregroundColor: Colors.white,
                elevation:       0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text('Para $_suporte',
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize:   11,
                color:      TClubColors.textoMuted,
              ))),
        ],
      ),
    );
  }
}

// ── Widgets internos do sheet ─────────────────────────────────────────────────

class _Passo extends StatelessWidget {
  const _Passo({
    required this.numero,
    required this.titulo,
    required this.corpo,
    required this.cor,
    required this.corFundo,
    required this.corBorda,
    this.extra,
  });

  final String  numero;
  final String  titulo;
  final String  corpo;
  final Color   cor;
  final Color   corFundo;
  final Color   corBorda;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color:  corFundo,
              border: Border.all(color: corBorda, width: 0.8),
              shape:  BoxShape.circle,
            ),
            child: Center(child: Text(numero,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      cor,
                ))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      TClubColors.textoPrincipal,
                  )),
              const SizedBox(height: 3),
              Text(corpo,
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize:   12,
                    color:      TClubColors.textoMuted,
                    height:     1.5,
                  )),
              if (extra != null) extra!,
            ],
          )),
        ],
      );
}

class _ProtoBox extends StatelessWidget {
  const _ProtoBox({
    required this.proto,
    required this.cor,
    required this.corFundo,
    required this.corBorda,
    required this.context,
  });

  final String  proto;
  final Color   cor;
  final Color   corFundo;
  final Color   corBorda;
  final BuildContext context;

  @override
  Widget build(BuildContext _) => Container(
        margin:  const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        corFundo,
          border:       Border.all(color: corBorda, width: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.tag, size: 15, color: cor),
          const SizedBox(width: 8),
          Expanded(child: Text(proto,
              style: TextStyle(
                fontFamily:    TClubTypography.bodyFont,
                fontSize:      13,
                fontWeight:    FontWeight.w700,
                color:         cor,
                letterSpacing: 1,
              ))),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: proto));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:  Text('Protocolo copiado'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ));
            },
            child: Icon(Icons.copy_outlined, size: 15, color: cor),
          ),
        ]),
      );
}

