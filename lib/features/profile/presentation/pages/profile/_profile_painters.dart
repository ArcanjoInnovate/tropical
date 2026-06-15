// features/profile/presentation/pages/profile/_profile_painters.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';

class AtmospherePainter extends CustomPainter {
  const AtmospherePainter({required this.gradient});
  final List<Color> gradient;

  @override
  void paint(Canvas canvas, Size size) {
    // background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = TClubColors.bg,
    );

    // radial blob top centre
    canvas.drawCircle(
      Offset(size.width * 0.5, -size.height * 0.06),
      size.width * 1.05,
      Paint()
        ..shader = RadialGradient(colors: [
          gradient[1].withOpacity(0.20),
          gradient[1].withOpacity(0.07),
          Colors.transparent,
        ], stops: const [
          0.0,
          0.35,
          1.0
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.5, -size.height * 0.06),
            radius: size.width * 1.05)),
    );

    // secondary blob top-right
    canvas.drawCircle(
      Offset(size.width * 0.90, size.height * 0.07),
      size.width * 0.42,
      Paint()
        ..shader = RadialGradient(colors: [
          TClubColors.redPrincipal.withOpacity(0.07),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.90, size.height * 0.07),
            radius: size.width * 0.42)),
    );

    // edge vignette
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.black.withOpacity(0.22),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(0.22),
        ], stops: const [
          0.0,
          0.18,
          0.82,
          1.0
        ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(AtmospherePainter old) => false;
}

