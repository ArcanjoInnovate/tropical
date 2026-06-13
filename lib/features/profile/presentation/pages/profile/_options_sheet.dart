// features/profile/presentation/pages/profile/_options_sheet.dart

import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

class ProfileOptionsSheet extends StatelessWidget {
  const ProfileOptionsSheet({
    super.key,
    required this.userName,
    required this.onReport,
    required this.onBlock,
  });

  final String userName;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: TabuColors.bgAlt),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          _accentLine(),
          _header(userName),
          _divider(),
          _actionTile(
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFFE85D5D),
            title: 'DENUNCIAR USUÁRIO',
            subtitle: 'Reportar comportamento inadequado',
            onTap: onReport,
          ),
          _actionTile(
            icon: Icons.block_rounded,
            iconColor: const Color(0xFFE85D5D),
            title: 'BLOQUEAR USUÁRIO',
            subtitle: 'Este usuário não poderá interagir com você',
            onTap: onBlock,
          ),
          const SizedBox(height: 10),
          _cancelButton(context),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _handle() => Container(
        width: 32,
        height: 2,
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          color: TabuColors.border,
          borderRadius: BorderRadius.circular(1),
        ),
      );

  Widget _accentLine() => Container(
        height: 1.5,
        margin: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            TabuColors.rosaDeep,
            TabuColors.rosaPrincipal,
            TabuColors.rosaClaro,
            TabuColors.rosaPrincipal,
            TabuColors.rosaDeep,
            Colors.transparent,
          ]),
        ),
      );

  Widget _header(String name) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(children: [
          const Icon(Icons.more_horiz, color: TabuColors.subtle, size: 14),
          const SizedBox(width: 10),
          Text(
            name.toUpperCase(),
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: TabuColors.subtle,
            ),
          ),
        ]),
      );

  Widget _divider() => Container(
        height: 0.5,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            TabuColors.border,
            Colors.transparent,
          ]),
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TabuColors.bgCard.withOpacity(0.50),
          border: Border.all(
            color: const Color(0xFFE85D5D).withOpacity(0.25),
            width: 0.7,
          ),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF3D0A0A),
              border: Border.all(
                  color: iconColor.withOpacity(0.40), width: 0.7),
            ),
            child: Icon(icon, color: iconColor, size: 13),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    color: TabuColors.subtle,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: iconColor, size: 16),
        ]),
      ),
    );
  }

  Widget _cancelButton(BuildContext context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          height: 46,
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border:
                Border.all(color: TabuColors.border, width: 0.8),
          ),
          child: const Center(
            child: Text(
              'CANCELAR',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: TabuColors.subtle,
              ),
            ),
          ),
        ),
      );
}
