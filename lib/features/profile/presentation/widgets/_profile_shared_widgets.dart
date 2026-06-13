// features/profile/presentation/pages/profile/_profile_shared_widgets.dart

import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LOCATION ROW — separador visual com linhas laterais em gradiente
//  Usado tanto no OwnProfileScreen quanto no PublicProfileScreen.
// ══════════════════════════════════════════════════════════════════════════════
class ProfileLocationRow extends StatelessWidget {
  const ProfileLocationRow({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, TabuColors.border],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(
              Icons.location_on_outlined,
              color: TabuColors.rosaPrincipal,
              size: 9,
            ),
            const SizedBox(width: 5),
            Text(
              location.toUpperCase(),
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: TabuColors.rosaPrincipal,
              ),
            ),
          ]),
        ),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TabuColors.border, Colors.transparent],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}