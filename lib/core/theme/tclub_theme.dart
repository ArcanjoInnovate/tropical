import 'package:flutter/material.dart';


class TClubColors {
  TClubColors._();

  // Fundos — tema escuro, preto profundo
  static const Color bg         = Color(0xFF000000); // preto puro
  static const Color bgAlt      = Color(0xFF0A0A0A); // preto levemente suavizado
  static const Color bgCard     = Color(0xFF141414); // card escuro
  static const Color nav        = Color(0xFF0A0A0A); // nav quase preto

  // Vermelho da logo — escala
  static const Color redDeep       = Color(0xFF8B1A22); // vermelho escuro
  static const Color redPrincipal  = Color(0xFFC41E2A); // cor exata da logo ← PRIMARY
  static const Color redClaro      = Color(0xFFE63946); // vermelho vibrante
  static const Color redPale       = Color(0xFF2A0A0D); // vermelho muito escuro (para chips/bg)

  // Erro
  static const Color errorDeep     = Color(0xFF7A1515);
  static const Color error         = Color(0xFFE84040);
  static const Color errorLight    = Color(0xFFFF8080);
  static const Color errorPale     = Color(0xFF2A0F0F);
  static const Color errorBorder   = Color(0x2EE84040);
  static const Color errorGlow     = Color(0x33E84040);

  // Branco / texto — escala sobre fundo preto
  static const Color branco  = Color(0xFFFFFFFF);
  static const Color dim     = Color(0xCCFFFFFF); // branco 80%
  static const Color subtle  = Color(0x8AFFFFFF); // branco 54%

  // Bordas & Glow — branco/vermelho semitransparente
  static const Color border    = Color(0x33FFFFFF); // branco 20%
  static const Color borderMid = Color(0x4DFFFFFF); // branco 30%
  static const Color glow      = Color(0x33C41E2A); // vermelho 20%

  // Aliases semânticos
  static const Color primary    = redPrincipal;
  static const Color accent     = redClaro;
  static const Color background = bg;
  static const Color surface    = bgCard;

  // Texto — hierarquia com contraste sobre fundo preto
  static const Color textoPrincipal  = Color(0xFFFFFFFF); // branco puro
  static const Color textoSecundario = Color(0xFFB0B0B0); // cinza claro
  static const Color textoMuted      = Color(0xFF707070); // cinza médio
  static const Color textoSobreRed   = Color(0xFFFFFFFF); // branco sobre botão vermelho

  // Gradientes
  static const LinearGradient fundoApp = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bgAlt],
  );

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [redDeep, redPrincipal],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xCC000000), bg],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [errorDeep, error],
  );

  static const RadialGradient redGlowRadial = RadialGradient(
    colors: [Color(0x33C41E2A), Color(0x00000000)],
    radius: 0.8,
  );

  static const RadialGradient errorGlowRadial = RadialGradient(
    colors: [Color(0x33E84040), Color(0x00000000)],
    radius: 0.8,
  );

  // Paleta completa para referência
  static const List<MapEntry<String, Color>> palette = [
    MapEntry('#000000', bg),
    MapEntry('#0A0A0A', bgAlt),
    MapEntry('#141414', bgCard),
    MapEntry('#8B1A22', redDeep),
    MapEntry('#C41E2A', redPrincipal),
    MapEntry('#E63946', redClaro),
    MapEntry('#2A0A0D', redPale),
    MapEntry('#7A1515', errorDeep),
    MapEntry('#E84040', error),
    MapEntry('#FF8080', errorLight),
    MapEntry('#2A0F0F', errorPale),
    MapEntry('#FFFFFF', branco),
  ];
}

class TClubTypography {
  TClubTypography._();

  static const String displayFont = 'Anton';
  static const String bodyFont    = 'Barlow Condensed';

  static TextTheme get textTheme => const TextTheme(
    displayLarge:   TextStyle(fontFamily: displayFont,  fontSize: 80,  fontWeight: FontWeight.w400, letterSpacing: 4,   color: TClubColors.textoPrincipal, height: 1.0),
    displayMedium:  TextStyle(fontFamily: displayFont,  fontSize: 56,  fontWeight: FontWeight.w400, letterSpacing: 3,   color: TClubColors.textoPrincipal),
    displaySmall:   TextStyle(fontFamily: displayFont,  fontSize: 40,  fontWeight: FontWeight.w400, letterSpacing: 2,   color: TClubColors.textoPrincipal),
    headlineLarge:  TextStyle(fontFamily: displayFont,  fontSize: 32,  fontWeight: FontWeight.w400, letterSpacing: 1.5, color: TClubColors.textoPrincipal),
    headlineMedium: TextStyle(fontFamily: bodyFont,     fontSize: 24,  fontWeight: FontWeight.w600, letterSpacing: 1.2, color: TClubColors.textoPrincipal),
    headlineSmall:  TextStyle(fontFamily: bodyFont,     fontSize: 18,  fontWeight: FontWeight.w600, letterSpacing: 1.0, color: TClubColors.textoPrincipal),
    titleLarge:     TextStyle(fontFamily: bodyFont,     fontSize: 16,  fontWeight: FontWeight.w600, letterSpacing: 1.5, color: TClubColors.textoPrincipal),
    titleMedium:    TextStyle(fontFamily: bodyFont,     fontSize: 14,  fontWeight: FontWeight.w500, letterSpacing: 1.2, color: TClubColors.textoPrincipal),
    titleSmall:     TextStyle(fontFamily: bodyFont,     fontSize: 12,  fontWeight: FontWeight.w500, letterSpacing: 1.2, color: TClubColors.textoSecundario),
    bodyLarge:      TextStyle(fontFamily: bodyFont,     fontSize: 16,  fontWeight: FontWeight.w400, letterSpacing: 0.3, color: TClubColors.textoPrincipal,  height: 1.6),
    bodyMedium:     TextStyle(fontFamily: bodyFont,     fontSize: 14,  fontWeight: FontWeight.w400, letterSpacing: 0.2, color: TClubColors.textoSecundario, height: 1.5),
    bodySmall:      TextStyle(fontFamily: bodyFont,     fontSize: 12,  fontWeight: FontWeight.w400, letterSpacing: 0.4, color: TClubColors.textoMuted,      height: 1.4),
    labelLarge:     TextStyle(fontFamily: bodyFont,     fontSize: 13,  fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TClubColors.textoPrincipal),
    labelMedium:    TextStyle(fontFamily: bodyFont,     fontSize: 11,  fontWeight: FontWeight.w600, letterSpacing: 2.0, color: TClubColors.textoSecundario),
    labelSmall:     TextStyle(fontFamily: bodyFont,     fontSize: 9,   fontWeight: FontWeight.w600, letterSpacing: 1.5, color: TClubColors.textoMuted),
  );
}

class TClubTheme {
  TClubTheme._();

  static const Color error      = TClubColors.error;
  static const Color errorLight = TClubColors.errorLight;
  static const Color errorDeep  = TClubColors.errorDeep;

  static ThemeData get main => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TClubColors.bg,
    colorScheme: const ColorScheme.dark(
      primary:          TClubColors.redPrincipal,
      onPrimary:        TClubColors.branco,
      secondary:        TClubColors.redClaro,
      onSecondary:      TClubColors.branco,
      tertiary:         TClubColors.redDeep,
      onTertiary:       TClubColors.branco,
      surface:          TClubColors.bgCard,
      onSurface:        TClubColors.textoPrincipal,
      outline:          TClubColors.border,
      error:            TClubColors.error,
      onError:          TClubColors.branco,
      errorContainer:   TClubColors.errorPale,
      onErrorContainer: TClubColors.errorLight,
    ),
    textTheme: TClubTypography.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor:  TClubColors.bg,
      foregroundColor:  TClubColors.textoPrincipal,
      elevation:        0,
      scrolledUnderElevation: 0.5,
      shadowColor:      TClubColors.border,
      surfaceTintColor: Colors.transparent,
      centerTitle:      true,
      titleTextStyle: TextStyle(
        fontFamily: TClubTypography.displayFont,
        fontSize:   24,
        fontWeight: FontWeight.w400,
        letterSpacing: 6,
        color:      TClubColors.redPrincipal,
      ),
      iconTheme: IconThemeData(color: TClubColors.redPrincipal, size: 22),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      TClubColors.bg,
      selectedItemColor:    TClubColors.redPrincipal,
      unselectedItemColor:  TClubColors.textoMuted,
      selectedLabelStyle:   TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 10, letterSpacing: 2),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TClubColors.redPrincipal,
        foregroundColor: TClubColors.branco,
        elevation:       0,
        shadowColor:     Colors.transparent,
        padding:         const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle:       const TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TClubColors.redPrincipal,
        side:            const BorderSide(color: TClubColors.redPrincipal, width: 1.5),
        padding:         const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle:       const TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TClubColors.redPrincipal,
        textStyle:       const TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color:     TClubColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side:         const BorderSide(color: TClubColors.border, width: 0.8),
      ),
      margin: EdgeInsets.zero,
      shadowColor: TClubColors.glow,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: TClubColors.bgCard,
      border:             OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TClubColors.border)),
      enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TClubColors.border, width: 0.8)),
      focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TClubColors.redPrincipal, width: 1.5)),
      errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TClubColors.error, width: 1.0)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TClubColors.error, width: 1.5)),
      errorStyle: const TextStyle(fontFamily: TClubTypography.bodyFont, color: TClubColors.error,           fontSize: 11, letterSpacing: 1.2),
      labelStyle: const TextStyle(fontFamily: TClubTypography.bodyFont, color: TClubColors.textoSecundario, letterSpacing: 1.5, fontSize: 12),
      hintStyle:  const TextStyle(fontFamily: TClubTypography.bodyFont, color: TClubColors.textoMuted,      letterSpacing: 1.5, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TClubColors.bgCard,
      contentTextStyle: const TextStyle(
        fontFamily: TClubTypography.bodyFont,
        color:      TClubColors.textoPrincipal,
        fontSize:   13,
        letterSpacing: 1.2,
      ),
      shape:         const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      behavior:      SnackBarBehavior.floating,
      showCloseIcon: true,
      closeIconColor: TClubColors.textoMuted,
    ),
    dividerTheme: const DividerThemeData(color: TClubColors.border, thickness: 0.5),
    chipTheme: ChipThemeData(
      backgroundColor: TClubColors.redPale,
      selectedColor:   TClubColors.redPrincipal,
      labelStyle:      const TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 11, letterSpacing: 2, color: TClubColors.textoPrincipal),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side:         const BorderSide(color: TClubColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    iconTheme:        const IconThemeData(color: TClubColors.textoSecundario, size: 20),
    primaryIconTheme: const IconThemeData(color: TClubColors.redPrincipal,    size: 20),
    listTileTheme: const ListTileThemeData(
      iconColor:   TClubColors.redPrincipal,
      textColor:   TClubColors.textoPrincipal,
      tileColor:   TClubColors.bg,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TClubColors.redPrincipal : TClubColors.textoMuted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TClubColors.redPale : TClubColors.border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TClubColors.redPrincipal : Colors.transparent),
      checkColor: WidgetStateProperty.all(TClubColors.branco),
      side: const BorderSide(color: TClubColors.border, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TClubColors.redPrincipal : TClubColors.textoMuted),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color:            TClubColors.redPrincipal,
      linearTrackColor: TClubColors.redPale,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor:   TClubColors.redPrincipal,
      inactiveTrackColor: TClubColors.redPale,
      thumbColor:         TClubColors.redPrincipal,
      overlayColor:       TClubColors.glow,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:             TClubColors.redPrincipal,
      unselectedLabelColor:   TClubColors.textoMuted,
      indicatorColor:         TClubColors.redPrincipal,
      labelStyle:             TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2),
      unselectedLabelStyle:   TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 12, letterSpacing: 2),
      dividerColor:           TClubColors.border,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TClubColors.redPrincipal,
      foregroundColor: TClubColors.branco,
      elevation:       2,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color:        TClubColors.bgCard,
        borderRadius: BorderRadius.zero,
      ),
      textStyle: const TextStyle(fontFamily: TClubTypography.bodyFont, color: TClubColors.textoPrincipal, fontSize: 11, letterSpacing: 1.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TClubColors.bgCard,
      elevation:       0,
      shape:           const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side:         BorderSide(color: TClubColors.border, width: 0.8),
      ),
      titleTextStyle: const TextStyle(fontFamily: TClubTypography.displayFont, fontSize: 22, letterSpacing: 2, color: TClubColors.textoPrincipal),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:   TClubColors.bgCard,
      surfaceTintColor:  Colors.transparent,
      shape:             RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      dragHandleColor:   TClubColors.textoMuted,
    ),
  );
}

class TClubGlow {
  TClubGlow._();

  static List<BoxShadow> redPrincipal({double blur = 16, double spread = 0}) => [
    BoxShadow(color: TClubColors.glow,                            blurRadius: blur,      spreadRadius: spread, offset: const Offset(0, 4)),
    BoxShadow(color: TClubColors.redPrincipal.withOpacity(0.15),  blurRadius: blur * 2, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> redSubtle({double blur = 8}) => [
    BoxShadow(color: TClubColors.glow, blurRadius: blur, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> branco({double blur = 16}) => [
    BoxShadow(color: Colors.white.withOpacity(0.04), blurRadius: blur, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> error({double blur = 16, double spread = 0}) => [
    BoxShadow(color: TClubColors.errorGlow,               blurRadius: blur,      spreadRadius: spread, offset: const Offset(0, 4)),
    BoxShadow(color: TClubColors.error.withOpacity(0.12), blurRadius: blur * 2, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> errorSubtle({double blur = 8}) => [
    BoxShadow(color: TClubColors.errorBorder, blurRadius: blur, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> card({double blur = 12}) => [
    BoxShadow(color: Colors.black.withOpacity(0.3),  blurRadius: blur,     offset: const Offset(0, 2)),
    BoxShadow(color: TClubColors.border,              blurRadius: blur / 2, offset: const Offset(0, 1)),
  ];
}
