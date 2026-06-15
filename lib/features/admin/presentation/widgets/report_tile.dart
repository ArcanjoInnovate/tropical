// lib/screens/admin/presentation/widgets/report_tile.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';

import '../../data/models/report_model.dart';

class ReportTile extends StatelessWidget {
  final ReportModel   report;
  final VoidCallback  onTap;
  final VoidCallback? onDismiss; // null → botão oculto (denúncias arquivadas)
  final VoidCallback  onDelete;

  const ReportTile({
    super.key,
    required this.report,
    required this.onTap,
    this.onDismiss,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (report.status) {
      case 'pending':   return TClubColors.redClaro;
      case 'actioned':  return Color(0xFF4CAF50);
      default:          return TClubColors.textoMuted;
    }
  }

  String get _statusLabel {
    switch (report.status) {
      case 'pending':   return 'PENDENTE';
      case 'actioned':  return 'RESOLVIDO';
      case 'dismissed': return 'IGNORADO';
      default:          return '—';
    }
  }

  String get _tipoDisplay {
    switch (report.tipo) {
      case 'posts':   return 'POST';
      case 'stories': return 'STORY';
      case 'users':   return 'USUÁRIO';
      case 'chats':   return 'CHAT';
      default:        return report.tipo.toUpperCase();
    }
  }

  Color get _tipoColor {
    switch (report.tipo) {
      case 'posts':   return TClubColors.redPrincipal;
      case 'stories': return TClubColors.textoSecundario;
      case 'users':   return TClubColors.redClaro;
      case 'chats':   return TClubColors.redClaro;
      default:        return TClubColors.textoSecundario;
    }
  }

  String _formatTs(int? ms) {
    if (ms == null) return '—';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours   < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:          onTap,
        splashColor:    TClubColors.redPrincipal.withOpacity(0.05),
        highlightColor: TClubColors.redPrincipal.withOpacity(0.03),
        child: Container(
          color:   report.isPending ? TClubColors.bgAlt : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildMotivo(),
              if (report.descricao.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDescricao(),
              ],
              const SizedBox(height: 8),
              _buildFooter(),
              if (report.protocolo != null) ...[
                const SizedBox(height: 6),
                _buildProtocolo(),
              ],
              // Mostra ações apenas para pendentes E quando onDismiss foi fornecido
              if (report.isPending && onDismiss != null) ...[
                const SizedBox(height: 12),
                _buildActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      _tipoBadge(),
      const SizedBox(width: 8),
      _statusBadge(),
      const Spacer(),
      const Icon(Icons.chevron_right_rounded,
        color: TClubColors.border, size: 14),
      const SizedBox(width: 4),
      Text(_formatTs(report.createdAt),
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9, color: TClubColors.textoMuted,
          letterSpacing: 0.3)),
    ]);
  }

  Widget _tipoBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    color: _tipoColor.withOpacity(0.10),
    child: Text(_tipoDisplay,
      style: TextStyle(
        fontFamily:    TClubTypography.bodyFont,
        fontSize:      8, fontWeight: FontWeight.w700,
        letterSpacing: 2, color: _tipoColor)));

  Widget _statusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(
        color: _statusColor.withOpacity(0.5), width: 0.7)),
    child: Text(_statusLabel,
      style: TextStyle(
        fontFamily:    TClubTypography.bodyFont,
        fontSize:      8, fontWeight: FontWeight.w700,
        letterSpacing: 2, color: _statusColor)));

  Widget _buildMotivo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(report.motivo,
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 13, fontWeight: FontWeight.w600,
          color: TClubColors.branco, letterSpacing: 0.3)),
      const SizedBox(height: 3),
      Text(report.artigo,
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9, letterSpacing: 1.5,
          color: TClubColors.textoSecundario)),
    ],
  );

  Widget _buildDescricao() => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(10),
    color:   TClubColors.bgAlt,
    child: Text(report.descricao,
      maxLines:        2,
      overflow:        TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: TClubTypography.bodyFont,
        fontSize: 11, height: 1.5,
        color: TClubColors.textoSecundario,
        letterSpacing: 0.2)));

  Widget _buildFooter() => Text(
    'Denunciado por: ${report.reporterUid}',
    style: const TextStyle(
      fontFamily: TClubTypography.bodyFont,
      fontSize: 9, color: TClubColors.textoMuted,
      letterSpacing: 0.3));

  Widget _buildProtocolo() => Row(children: [
    const Icon(Icons.tag_rounded, color: TClubColors.border, size: 10),
    const SizedBox(width: 4),
    Text(report.protocolo!,
      style: const TextStyle(
        fontFamily: TClubTypography.bodyFont,
        fontSize: 8, color: TClubColors.textoMuted,
        letterSpacing: 1)),
  ]);

  Widget _buildActions() => Row(children: [
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color:  TClubColors.bgCard,
          border: Border.all(
            color: TClubColors.borderMid, width: 0.8)),
        child: const Center(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded,
              color: TClubColors.textoSecundario, size: 11),
            SizedBox(width: 6),
            Text('VER DETALHES',
              style: TextStyle(
                fontFamily:    TClubTypography.bodyFont,
                fontSize:      9, fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color:         TClubColors.redPrincipal)),
          ]))))),
    const SizedBox(width: 6),
    GestureDetector(
      onTap: onDismiss, // seguro: só renderizado quando onDismiss != null
      child: Container(
        width: 70, height: 36,
        decoration: BoxDecoration(
          color:  TClubColors.bgAlt,
          border: Border.all(color: TClubColors.border, width: 0.8)),
        child: const Center(child: Text('IGNORAR',
          style: TextStyle(
            fontFamily:    TClubTypography.bodyFont,
            fontSize:      8, fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color:         TClubColors.textoSecundario))))),
  ]);
}