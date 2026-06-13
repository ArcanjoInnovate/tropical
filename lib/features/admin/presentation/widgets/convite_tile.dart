// lib/screens/admin/presentation/widgets/convite_tile.dart

import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/core/theme/admin_theme.dart';
import '../../data/models/invite_model.dart';

class ConviteTile extends StatelessWidget {
  final InviteModel   pedido;
  final VoidCallback? onAprovar;
  final VoidCallback? onRejeitar;

  const ConviteTile({
    super.key,
    required this.pedido,
    required this.onAprovar,
    required this.onRejeitar,
  });

  Color get _statusColor {
    switch (pedido.status) {
      case 'pending':  return AdminColors.pending;
      case 'approved': return AdminColors.actioned;
      case 'rejected': return AdminColors.danger;
      default:         return AdminColors.dismissed;
    }
  }

  String get _statusLabel {
    switch (pedido.status) {
      case 'pending':  return 'PENDENTE';
      case 'approved': return 'APROVADO';
      case 'rejected': return 'RECUSADO';
      default:         return '—';
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
    return Container(
      decoration: BoxDecoration(
        color: pedido.isPending ? AdminColors.fill : Colors.transparent,
        border: const Border(bottom: BorderSide(
          color: AdminColors.border, width: 0.5))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildName(),
          const SizedBox(height: 3),
          _buildEmail(),
          if (pedido.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMessage(),
          ],
          if (!pedido.isPending &&
              pedido.motivoRejeicao != null &&
              pedido.motivoRejeicao!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMotivoRejeicao(),
          ],
          if (pedido.protocolo != null) ...[
            const SizedBox(height: 8),
            _buildProtocolo(),
          ],
          if (pedido.isPending) ...[
            const SizedBox(height: 14),
            pedido.isProcessing
                ? _buildLoading()
                : _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: _statusColor.withOpacity(0.5), width: 0.7)),
      child: Text(_statusLabel, style: TextStyle(
        fontFamily:    TabuTypography.bodyFont,
        fontSize:      8, fontWeight: FontWeight.w700,
        letterSpacing: 2, color: _statusColor))),
    const Spacer(),
    Text(_formatTs(pedido.createdAt), style: const TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 9, color: AdminColors.inkGhost,
      letterSpacing: 0.3)),
  ]);

  Widget _buildName() => Text(pedido.name.toUpperCase(),
    style: const TextStyle(
      fontFamily:    TabuTypography.bodyFont,
      fontSize:      14, fontWeight: FontWeight.w700,
      color:         AdminColors.inkDeep, letterSpacing: 1));

  Widget _buildEmail() => Row(children: [
    const Icon(Icons.email_outlined,
      color: AdminColors.inkGhost, size: 11),
    const SizedBox(width: 5),
    Text(pedido.email, style: const TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 10, color: AdminColors.inkSubtle,
      letterSpacing: 0.3)),
  ]);

  Widget _buildMessage() => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(
      color: AdminColors.bgAlt,
      border: Border(left: BorderSide(
        color: AdminColors.borderStrong, width: 2))),
    child: Text(pedido.message, maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 11, height: 1.5,
        color: AdminColors.inkSubtle,
        letterSpacing: 0.2)));

  Widget _buildMotivoRejeicao() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.block_rounded,
        color: AdminColors.danger, size: 10),
      const SizedBox(width: 5),
      Expanded(child: Text(pedido.motivoRejeicao!, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 10, color: AdminColors.danger,
        height: 1.5, letterSpacing: 0.2))),
    ]);

  Widget _buildProtocolo() => Row(children: [
    const Icon(Icons.tag_rounded,
      color: AdminColors.border, size: 10),
    const SizedBox(width: 4),
    Text(pedido.protocolo!, style: const TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 8, color: AdminColors.inkGhost,
      letterSpacing: 1)),
  ]);

  Widget _buildLoading() => const Center(
    child: SizedBox(width: 18, height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation(AdminColors.inkPrincipal))));

  Widget _buildActions() => Row(children: [
    Expanded(child: GestureDetector(
      onTap: onAprovar,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AdminColors.actioned.withOpacity(0.08),
          border: Border.all(
            color: AdminColors.actioned.withOpacity(0.4), width: 0.8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_rounded,
              color: AdminColors.actioned, size: 13),
            SizedBox(width: 6),
            Text('APROVAR', style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      9, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: AdminColors.actioned)),
          ])))),
    const SizedBox(width: 8),
    Expanded(child: GestureDetector(
      onTap: onRejeitar,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AdminColors.danger.withOpacity(0.06),
          border: Border.all(
            color: AdminColors.danger.withOpacity(0.35), width: 0.8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.block_rounded,
              color: AdminColors.danger, size: 13),
            SizedBox(width: 6),
            Text('RECUSAR', style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      9, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: AdminColors.danger)),
          ])))),
  ]);
}