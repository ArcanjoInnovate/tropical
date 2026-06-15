// lib/screens/admin/presentation/widgets/admin_shared_widgets.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';


// ── Stat Chip ─────────────────────────────────────────────────────────────────
class AdminStatChip extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final bool     highlight;

  const AdminStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12,
        color: highlight ? TClubColors.redClaro : TClubColors.textoMuted),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
        fontFamily: TClubTypography.displayFont,
        fontSize: 16, letterSpacing: 1,
        color: highlight ? TClubColors.branco : TClubColors.redPrincipal)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
        fontFamily:    TClubTypography.bodyFont,
        fontSize:      7, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: TClubColors.textoMuted)),
    ]),
  );
}

// ── Divider vertical ──────────────────────────────────────────────────────────
class AdminStatDivider extends StatelessWidget {
  const AdminStatDivider({super.key});

  @override
  Widget build(BuildContext context) =>
    Container(width: 0.5, height: 30, color: TClubColors.border);
}

// ── Section Label ─────────────────────────────────────────────────────────────
class AdminSectionLabel extends StatelessWidget {
  final String label;

  const AdminSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Container(width: 2, height: 12, color: TClubColors.redPrincipal),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(
        fontFamily:    TClubTypography.bodyFont,
        fontSize:      9, fontWeight: FontWeight.w700,
        letterSpacing: 2.5, color: TClubColors.textoSecundario)),
    ]),
  );
}

// ── Sistema Card ──────────────────────────────────────────────────────────────
class SistemaCard extends StatelessWidget {
  final IconData icon;
  final String   titulo;
  final String   subtitulo;
  final String   descricao;

  const SistemaCard({
    super.key,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:  TClubColors.bgAlt,
      border: Border.all(color: TClubColors.border, width: 0.8)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: TClubColors.textoSecundario, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(
            fontFamily:    TClubTypography.bodyFont,
            fontSize:      12, fontWeight: FontWeight.w700,
            color:         TClubColors.branco, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(subtitulo, style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9, letterSpacing: 1.5,
            color: TClubColors.textoSecundario)),
          const SizedBox(height: 8),
          Text(descricao, style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 11, height: 1.6,
            color: TClubColors.textoSecundario,
            letterSpacing: 0.2)),
        ],
      )),
    ]),
  );
}

// ── Loading Widget ────────────────────────────────────────────────────────────
class AdminLoadingWidget extends StatelessWidget {
  const AdminLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(width: 22, height: 22,
      child: CircularProgressIndicator(strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation(TClubColors.redPrincipal))));
}

// ── Empty State ───────────────────────────────────────────────────────────────
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String   label;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: TClubColors.border, size: 36),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(
        fontFamily:    TClubTypography.bodyFont,
        fontSize:      9, fontWeight: FontWeight.w700,
        letterSpacing: 2.5, color: TClubColors.textoMuted)),
    ]));
}