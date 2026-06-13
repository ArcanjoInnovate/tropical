// lib/features/user/moderation/presentation/widgets/report_shared_widgets.dart
//
//  Widgets reutilizáveis em todas as telas de denúncia.
//  Eliminam a duplicação de _StepLabel, _MotivoTile, _CheckConfirm,
//  _BotaoEnviar, _BotaoSecundario, _IconBox, _LegalBox, _PrivacyItem,
//  _ProcessoItem, etc., que antes existiam copiados em cada tela.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import '../../data/models/report_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  STEP LABEL  ·  "01 ── O QUE ACONTECEU? ──────"
// ══════════════════════════════════════════════════════════════════════════════
class ReportStepLabel extends StatelessWidget {
  final String step;
  final String label;
  const ReportStepLabel({super.key, required this.step, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.15),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 0.8)),
      child: Center(child: Text(step,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5, color: TabuColors.rosaPrincipal)))),
    const SizedBox(width: 10),
    Flexible(child: Text(label, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 3, color: TabuColors.rosaPrincipal))),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: TabuColors.border)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  MOTIVO TILE  ·  item da lista de motivos
// ══════════════════════════════════════════════════════════════════════════════
class ReportMotivoTile extends StatelessWidget {
  final ReportMotivoModel motivo;
  final bool              selecionado;
  final VoidCallback      onTap;

  const ReportMotivoTile({
    super.key,
    required this.motivo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFFE85D5D).withOpacity(0.07)
              : TabuColors.bgCard,
          border: Border.all(
            color: selecionado
                ? const Color(0xFFE85D5D).withOpacity(0.55)
                : TabuColors.border,
            width: selecionado ? 1.2 : 0.7)),
        child: Row(children: [
          // ── Radio ──────────────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selecionado
                  ? const Color(0xFFE85D5D)
                  : Colors.transparent,
              border: Border.all(
                color: selecionado
                    ? const Color(0xFFE85D5D)
                    : TabuColors.border,
                width: selecionado ? 0 : 1.5)),
            child: selecionado
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 11)
                : null),
          const SizedBox(width: 12),

          // ── Ícone (opcional — story) ────────────────────────────────────
          if (motivo.icone != null) ...[
            Icon(motivo.icone!,
                size: 18,
                color: selecionado
                    ? TabuColors.rosaPrincipal
                    : TabuColors.subtle),
            const SizedBox(width: 10),
          ],

          // ── Texto ──────────────────────────────────────────────────────────
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(motivo.label,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 12, fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: selecionado
                          ? TabuColors.textoPrincipal
                          : TabuColors.dim)),
              const SizedBox(height: 2),
              Text(motivo.artigo,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.8,
                      color: selecionado
                          ? const Color(0xFFE85D5D).withOpacity(0.75)
                          : TabuColors.border)),
            ])),

          if (selecionado)
            const Icon(Icons.report_gmailerrorred_rounded,
                color: Color(0xFFE85D5D), size: 14),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHECK CONFIRM  ·  checkbox de confirmação obrigatória
// ══════════════════════════════════════════════════════════════════════════════
class ReportCheckConfirm extends StatelessWidget {
  final bool               valor;
  final ValueChanged<bool> onChanged;
  final String             texto;

  const ReportCheckConfirm({
    super.key,
    required this.valor,
    required this.onChanged,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!valor);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: valor
              ? TabuColors.rosaPrincipal.withOpacity(0.06)
              : TabuColors.bgCard,
          border: Border.all(
            color: valor
                ? TabuColors.rosaPrincipal.withOpacity(0.4)
                : TabuColors.border,
            width: valor ? 1.0 : 0.7)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: valor ? TabuColors.rosaPrincipal : Colors.transparent,
              border: Border.all(
                color: valor ? TabuColors.rosaPrincipal : TabuColors.border,
                width: valor ? 0 : 1.5)),
            child: valor
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                : null),
          const SizedBox(width: 12),
          Expanded(child: Text(texto,
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, letterSpacing: 0.3,
                  color: valor ? TabuColors.dim : TabuColors.subtle,
                  height: 1.5))),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOTÃO ENVIAR
// ══════════════════════════════════════════════════════════════════════════════
class ReportBotaoEnviar extends StatelessWidget {
  final bool         ativo;
  final bool         enviando;
  final VoidCallback onTap;
  final String       label;

  const ReportBotaoEnviar({
    super.key,
    required this.ativo,
    required this.enviando,
    required this.onTap,
    this.label = 'ENVIAR DENÚNCIA',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ativo && !enviando ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: ativo ? const Color(0xFFE85D5D) : TabuColors.bgCard,
          border: Border.all(
            color: ativo ? const Color(0xFFE85D5D) : TabuColors.border,
            width: 0.8),
          boxShadow: ativo ? [BoxShadow(
              color: const Color(0xFFE85D5D).withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 4))] : null),
        child: Center(child: enviando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 1.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.report_gmailerrorred_rounded,
                    color: ativo ? Colors.white : TabuColors.subtle, size: 16),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: ativo ? Colors.white : TabuColors.subtle)),
              ])),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOTÃO SECUNDÁRIO  ·  cancelar / voltar
// ══════════════════════════════════════════════════════════════════════════════
class ReportBotaoSecundario extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const ReportBotaoSecundario({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.border, width: 0.8)),
      child: Center(child: Text(label,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 3, color: TabuColors.subtle)))));
}

// ══════════════════════════════════════════════════════════════════════════════
//  ICON BOX  ·  ícone centralizado com borda
// ══════════════════════════════════════════════════════════════════════════════
class ReportIconBox extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final bool     filled;
  const ReportIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
      color: filled
          ? color.withOpacity(0.15)
          : color.withOpacity(0.10),
      border: Border.all(
          color: filled ? color : color.withOpacity(0.4),
          width: filled ? 1.0 : 0.8)),
    child: Icon(icon, color: color, size: 26));
}

// ══════════════════════════════════════════════════════════════════════════════
//  LEGAL BOX  ·  lista de pontos legais com ícone de check
// ══════════════════════════════════════════════════════════════════════════════
class ReportLegalBox extends StatelessWidget {
  final List<String> items;
  const ReportLegalBox({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TabuColors.bgCard,
      border: Border.all(color: TabuColors.border, width: 0.6)),
    child: Column(children: items.map((t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: TabuColors.rosaPrincipal, size: 11),
        const SizedBox(width: 8),
        Expanded(child: Text(t,
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.3,
                color: TabuColors.dim, height: 1.5))),
      ]))).toList()),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRIVACY ITEM  ·  linha de privacidade com ícone
// ══════════════════════════════════════════════════════════════════════════════
class ReportPrivacyItem extends StatelessWidget {
  final IconData icon;
  final String   texto;
  const ReportPrivacyItem({super.key, required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: TabuColors.rosaPrincipal, size: 12),
    const SizedBox(width: 8),
    Expanded(child: Text(texto,
        style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10, letterSpacing: 0.3,
            color: TabuColors.dim, height: 1.5))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  PROCESSO ITEM  ·  passo numerado do "o que acontece depois"
// ══════════════════════════════════════════════════════════════════════════════
class ReportProcessoItem extends StatelessWidget {
  final String numero;
  final String texto;
  const ReportProcessoItem({
    super.key,
    required this.numero,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 18, height: 18,
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.1),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.35), width: 0.7)),
      child: Center(child: Text(numero,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w800,
              color: TabuColors.rosaPrincipal)))),
    const SizedBox(width: 10),
    Expanded(child: Text(texto,
        style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10, letterSpacing: 0.3,
            color: TabuColors.dim, height: 1.5))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  LINHA DECORATIVA ROSA  ·  separador gradiente
// ══════════════════════════════════════════════════════════════════════════════
class ReportLinhaRosa extends StatelessWidget {
  const ReportLinhaRosa({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1.5,
    margin: const EdgeInsets.only(top: 6),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [
      Colors.transparent, TabuColors.rosaDeep,
      TabuColors.rosaPrincipal, TabuColors.rosaClaro,
      TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
    ])));
}

// ══════════════════════════════════════════════════════════════════════════════
//  DIVIDER  ·  linha sutil entre seções
// ══════════════════════════════════════════════════════════════════════════════
class ReportDivider extends StatelessWidget {
  const ReportDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [
      Colors.transparent, TabuColors.border, Colors.transparent,
    ])));
}

// ══════════════════════════════════════════════════════════════════════════════
//  CAMPO DESCRIÇÃO  ·  textarea com barra de progresso
// ══════════════════════════════════════════════════════════════════════════════
class ReportCampoDescricao extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  descValida;
  final int                   minChars;
  final String                hintText;

  const ReportCampoDescricao({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.descValida,
    required this.minChars,
    this.hintText = 'Descreva o que aconteceu. Quanto mais detalhes, mais fácil para nossa equipe analisar...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(
          color: focusNode.hasFocus
              ? (descValida
                  ? TabuColors.rosaPrincipal
                  : const Color(0xFFE85D5D))
              : TabuColors.border,
          width: focusNode.hasFocus ? 1.5 : 0.8)),
      child: Column(children: [
        TextField(
          controller: controller,
          focusNode:  focusNode,
          maxLines:   6,
          maxLength:  600,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 13, color: TabuColors.textoPrincipal, height: 1.5),
          cursorColor: TabuColors.rosaPrincipal,
          decoration: InputDecoration(
            border: InputBorder.none, isDense: true,
            hintText: hintText,
            hintStyle: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, color: TabuColors.subtle, height: 1.5),
            contentPadding: const EdgeInsets.all(14),
            counterText: ''),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (controller.text.trim().length / minChars)
                .clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: descValida
                    ? [TabuColors.rosaDeep, TabuColors.rosaPrincipal]
                    : [const Color(0xFF5D0A0A), const Color(0xFFE85D5D)])),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVISO DE PRIVACIDADE  ·  bloco rosa com escudo
// ══════════════════════════════════════════════════════════════════════════════
class ReportAvisoPrivacidade extends StatelessWidget {
  final List<ReportPrivacyItem> itens;
  const ReportAvisoPrivacidade({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.04),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.2), width: 0.7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.shield_outlined,
              color: TabuColors.rosaPrincipal, size: 13),
          SizedBox(width: 8),
          Text('SUA PRIVACIDADE É PROTEGIDA', style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: TabuColors.rosaPrincipal)),
        ]),
        const SizedBox(height: 10),
        ...itens.map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: i,
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ESTADO: JÁ DENUNCIOU  ·  tela/bloco genérico
// ══════════════════════════════════════════════════════════════════════════════
class ReportJaReportouView extends StatelessWidget {
  final String       titulo;
  final String       mensagem;
  final String       nota;
  final VoidCallback onVoltar;

  const ReportJaReportouView({
    super.key,
    required this.titulo,
    required this.mensagem,
    required this.nota,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ReportIconBox(
          icon:  Icons.flag_rounded,
          color: TabuColors.rosaPrincipal),
      const SizedBox(height: 20),
      Text(titulo, style: const TextStyle(
          fontFamily: TabuTypography.displayFont,
          fontSize: 18, letterSpacing: 3,
          color: TabuColors.textoPrincipal)),
      const SizedBox(height: 12),
      Text(mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, letterSpacing: 0.3,
              color: TabuColors.subtle, height: 1.7)),
      const SizedBox(height: 8),
      Text(nota,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, letterSpacing: 1,
              color: TabuColors.border)),
      const SizedBox(height: 32),
      ReportBotaoSecundario(label: 'VOLTAR', onTap: onVoltar),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  ESTADO: SUCESSO  ·  tela/bloco genérico de confirmação
// ══════════════════════════════════════════════════════════════════════════════
class ReportSucessoView extends StatelessWidget {
  final String           titulo;
  final String           mensagem;
  final String           nota;
  final List<String>?    legalBoxItems;

  const ReportSucessoView({
    super.key,
    required this.titulo,
    required this.mensagem,
    required this.nota,
    this.legalBoxItems,
  });

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ReportIconBox(
          icon:   Icons.check_rounded,
          color:  TabuColors.rosaPrincipal,
          filled: true),
      const SizedBox(height: 20),
      Text(titulo, style: const TextStyle(
          fontFamily: TabuTypography.displayFont,
          fontSize: 20, letterSpacing: 4,
          color: TabuColors.textoPrincipal)),
      const SizedBox(height: 12),
      Text(mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, letterSpacing: 0.3,
              color: TabuColors.subtle, height: 1.7)),
      if (legalBoxItems != null) ...[
        const SizedBox(height: 12),
        ReportLegalBox(items: legalBoxItems!),
      ],
      const SizedBox(height: 8),
      Text(nota,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, letterSpacing: 0.8,
              color: TabuColors.border)),
    ]),
  ));
}