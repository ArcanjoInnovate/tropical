// lib/core/app_constants.dart

import 'package:flutter/material.dart';

/// Constantes centralizadas do app.
abstract class AppConstants {
  AppConstants._();

  // ── Nome do app ──────────────────────────────────────────────────────────
  static const String appName = 'TABU';

  // ── Logo (asset) ─────────────────────────────────────────────────────────
  static const String logoAssetPath = 'assets/tabu_logo.png';

  /// Retorna o logo do app como widget de imagem.
  /// [height] controla a altura; largura proporcional.
  /// [color] aplica um tint (útil para versões branca/preta).
  static Widget logo({
    double height = 28,
    Color? color,
  }) {
    return Image.asset(
      logoAssetPath,
      height: height,
      fit: BoxFit.contain,
      color: color,
    );
  }

  /// Logo para usar em AppBars (tamanho padrão menor).
  static Widget appBarLogo({Color? color}) => logo(height: 22, color: color);
}