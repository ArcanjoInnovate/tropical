// features/profile/presentation/pages/profile/_profile_shared_widgets.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';

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
                colors: [Colors.transparent, TClubColors.border],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(
              Icons.location_on_outlined,
              color: TClubColors.redPrincipal,
              size: 9,
            ),
            const SizedBox(width: 5),
            Text(
              location.toUpperCase(),
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: TClubColors.redPrincipal,
              ),
            ),
          ]),
        ),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TClubColors.border, Colors.transparent],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

