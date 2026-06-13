// lib/core/theme/admin_theme.dart
import 'package:flutter/material.dart';
import 'tabu_theme.dart';

class AdminColors {
  AdminColors._();

  // ── Chumbo/Grafite — escala principal ────────────────────────────────────
  static const Color inkDeep       = Color(0xFF0F1114); // quase-preto frio
  static const Color inkPrincipal  = Color(0xFF1E2229); // PRIMARY — grafite escuro
  static const Color inkMid        = Color(0xFF3A4149); // grafite médio
  static const Color inkSubtle     = Color(0xFF6B737D); // grafite claro / texto muted
  static const Color inkGhost      = Color(0xFF9BA3AC); // placeholder / hint

  // ── Fundos — brancos frios levemente acinzentados ─────────────────────────
  static const Color bg            = Color(0xFFF9FAFB); // fundo principal (quase branco frio)
  static const Color bgAlt         = Color(0xFFF1F3F5); // alternância sutil
  static const Color bgCard        = Color(0xFFFFFFFF); // card puro com borda

  // ── Bordas e fills ────────────────────────────────────────────────────────
  static const Color border        = Color(0x281E2229); // 16% inkPrincipal
  static const Color borderStrong  = Color(0x4D1E2229); // 30% inkPrincipal
  static const Color fill          = Color(0x0C1E2229); // 5%  — fill sutil
  static const Color fillStrong    = Color(0x171E2229); // 9%  — fill médio
  static const Color glow          = Color(0x141E2229); // 8%  — sombra suave

  // ── Acento único: cinza-azulado frio ─────────────────────────────────────
  // Usado apenas em destaques pontuais (section bar, selected border, botão ativo)
  // Mantém o minimalismo mas dá um toque "institucional" sem ser azul puro.
  static const Color accent        = Color(0xFF4A5568); // slate-700
  static const Color accentLight   = Color(0xFF718096); // slate-500

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color pending       = Color(0xFFB7791F); // âmbar escuro — só p/ status
  static const Color actioned      = Color(0xFF276749); // verde escuro
  static const Color dismissed     = Color(0xFF9BA3AC); // inkGhost
  static const Color danger        = Color(0xFFE53E3E); // vermelho
  static const Color dangerSubtle  = Color(0xFFFC8181); // vermelho claro
  static const Color warning       = Color(0xFFBF7B0A); // laranja escuro
}

class AdminTheme {
  AdminTheme._();

  static ThemeData get main => ThemeData(
    useMaterial3:            true,
    brightness:              Brightness.light,
    scaffoldBackgroundColor: AdminColors.bg,
    colorScheme: const ColorScheme.light(
      primary:   AdminColors.inkPrincipal,
      onPrimary: Colors.white,
      secondary: AdminColors.inkMid,
      surface:   AdminColors.bgCard,
      onSurface: AdminColors.inkDeep,
      outline:   AdminColors.border,
      error:     AdminColors.danger,
      onError:   Colors.white,
    ),
    textTheme: TabuTypography.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor:        AdminColors.bgCard,
      foregroundColor:        AdminColors.inkDeep,
      elevation:              0,
      scrolledUnderElevation: 0.5,
      shadowColor:            AdminColors.border,
      surfaceTintColor:       Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:           AdminColors.inkDeep,
      unselectedLabelColor: AdminColors.inkSubtle,
      indicatorColor:       AdminColors.inkPrincipal,
      dividerColor:         AdminColors.border,
      labelStyle: TextStyle(
        fontFamily:    TabuTypography.bodyFont,
        fontSize:      9,
        fontWeight:    FontWeight.w700,
        letterSpacing: 2,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily:    TabuTypography.bodyFont,
        fontSize:      9,
        fontWeight:    FontWeight.w700,
        letterSpacing: 2,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AdminColors.inkPrincipal,
    ),
    dividerTheme: const DividerThemeData(
      color: AdminColors.border, thickness: 0.5,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: AdminColors.fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide:   const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide:   const BorderSide(color: AdminColors.border, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide:   const BorderSide(color: AdminColors.inkPrincipal, width: 1.2),
      ),
      hintStyle: const TextStyle(
        fontFamily:    TabuTypography.bodyFont,
        color:         AdminColors.inkGhost,
        fontSize:      12,
        letterSpacing: 0.5,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AdminColors.inkDeep,
      contentTextStyle: TextStyle(
        fontFamily:    TabuTypography.bodyFont,
        color:         Colors.white,
        fontSize:      11,
        letterSpacing: 0.5,
      ),
      behavior: SnackBarBehavior.floating,
      shape:    RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    cardTheme: CardThemeData(
      color:     AdminColors.bgCard,
      elevation: 0,
      shape:     RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side:         const BorderSide(color: AdminColors.border, width: 0.8),
      ),
    ),
  );
}