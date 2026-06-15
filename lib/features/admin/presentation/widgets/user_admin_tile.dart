// lib/screens/admin/presentation/widgets/user_admin_tile.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';

import '../../data/models/user_model.dart';

class UserAdminTile extends StatelessWidget {
  final UserModel    user;
  final VoidCallback? onTap;

  const UserAdminTile({super.key, required this.user, this.onTap});

  Color get _dotColor {
    if (user.banido)   return TClubColors.error;
    if (user.suspenso) return Color(0xFFFFA726);
    if (user.online)   return Color(0xFF4CAF50);
    return TClubColors.border;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:          onTap,
        splashColor:    TClubColors.redPrincipal.withOpacity(0.05),
        highlightColor: TClubColors.redPrincipal.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            _dot(),
            const SizedBox(width: 10),
            Expanded(child: _info()),
            _badges(),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                color: TClubColors.border, size: 16),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _dot() => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: _dotColor));

  Widget _info() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(user.name.toUpperCase(),
        style: const TextStyle(
          fontFamily:    TClubTypography.bodyFont,
          fontSize:      12, fontWeight: FontWeight.w700,
          letterSpacing: 1.5, color: TClubColors.branco)),
      if (user.email.isNotEmpty)
        Text(user.email,
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9, color: TClubColors.textoSecundario,
            letterSpacing: 0.3)),
      if (user.city.isNotEmpty)
        Text('${user.city}, ${user.state}',
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9, color: TClubColors.textoMuted,
            letterSpacing: 0.3)),
    ],
  );

  Widget _badges() => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (user.banido)
        _badge('BANIDO', TClubColors.error)
      else if (user.suspenso)
        _badge('SUSPENSO', Color(0xFFFFA726)),
      if (user.reportCount > 0)
        _badge('${user.reportCount} reports', TClubColors.textoSecundario),
      if (user.vipLists > 0)
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded,
            color: TClubColors.textoSecundario, size: 10),
          const SizedBox(width: 3),
          Text('${user.vipLists} VIP',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 9, color: TClubColors.textoSecundario,
              letterSpacing: 1)),
        ]),
      Text('${user.partys} festas',
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9, color: TClubColors.textoMuted,
          letterSpacing: 0.5)),
    ],
  );

  Widget _badge(String label, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 3),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(0.5), width: 0.6)),
    child: Text(label,
      style: TextStyle(
        fontFamily:    TClubTypography.bodyFont,
        fontSize:      7, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: color)));
}