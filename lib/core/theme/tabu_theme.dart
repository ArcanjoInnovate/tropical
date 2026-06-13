import 'package:flutter/material.dart';


class TabuColors {
  TabuColors._();

  // Fundos — tema claro, fundo branco quente
  static const Color bg         = Color(0xFFFFFFFF); // branco puro
  static const Color bgAlt      = Color(0xFFF5E8EA); // branco vináceo com mais presença
  static const Color bgCard     = Color(0xFFF2E6E8); // card com calor visível
  static const Color nav        = Color(0xFFFFFFFF); // nav branco

  // Rosa → bordô/vinho da logo
  static const Color rosaDeep      = Color(0xFF34080B); // bordô muito escuro
  static const Color rosaPrincipal = Color(0xFF5A0F14); // cor exata da logo ← PRIMARY
  static const Color rosaClaro     = Color(0xFFA61B24); // vinho médio
  static const Color rosaPale      = Color(0xFFF9E0E2); // blush suave

  // Erro
  static const Color errorDeep     = Color(0xFF7A1515);
  static const Color error         = Color(0xFFE84040);
  static const Color errorLight    = Color(0xFFFF8080);
  static const Color errorPale     = Color(0xFFFFE4E4);
  static const Color errorBorder   = Color(0x2EE84040);
  static const Color errorGlow     = Color(0x33E84040);

  // Preto / texto — escala sobre fundo branco
  // dim e subtle usam preto semitransparente: funciona tanto sobre fundos
  // escuros (AtmospherePainter) quanto sobre bgCard/bg claro.
  static const Color branco  = Color(0xFFFFFFFF);
  static const Color dim     = Color(0xCC000000); // preto 80% — legível no claro e no escuro
  static const Color subtle  = Color(0x8A000000); // preto 54% — mínimo 4.5:1 sobre branco

  // Bordas & Glow — vinho semitransparente, opacidade aumentada para o tema claro
  static const Color border    = Color(0x4D5A0F14); // 30% — visível sobre bgCard branco
  static const Color borderMid = Color(0x6E5A0F14); // 43% — ênfase em botões/inputs
  static const Color glow      = Color(0x335A0F14); // 20%

  // Aliases semânticos
  static const Color primary    = rosaPrincipal;
  static const Color accent     = rosaClaro;
  static const Color background = bg;
  static const Color surface    = bgCard;

  // Texto — hierarquia com contraste garantido sobre fundo branco
  // textoPrincipal  : ratio ~18:1 no bg branco (AAA ✓)
  // textoSecundario : ratio ~9:1  no bg branco (AAA ✓)
  // textoMuted      : ratio ~4.7:1 no bg branco (AA ✓)
  // textoSobreRosa  : branco puro — usado SOMENTE sobre botões escuros
  static const Color textoPrincipal  = Color(0xFF1A0305); // quase-preto vináceo escuro
  static const Color textoSecundario = Color(0xFF5A0F14); // rosaPrincipal — AA no branco
  static const Color textoMuted      = Color(0xFF7A3A3E); // vinho médio — AA no branco
  static const Color textoSobreRosa  = Color(0xFFFFFFFF); // branco sobre botão escuro

  // Gradientes
  static const LinearGradient fundoApp = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bgAlt],
  );

  static const LinearGradient rosaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [rosaDeep, rosaPrincipal],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF), bg],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [errorDeep, error],
  );

  static const RadialGradient rosaGlowRadial = RadialGradient(
    colors: [Color(0x335A0F14), Color(0x00000000)],
    radius: 0.8,
  );

  static const RadialGradient errorGlowRadial = RadialGradient(
    colors: [Color(0x33E84040), Color(0x00000000)],
    radius: 0.8,
  );

  // Paleta completa para referência
  static const List<MapEntry<String, Color>> palette = [
    MapEntry('#FFFFFF', bg),
    MapEntry('#F5E8EA', bgAlt),
    MapEntry('#F2E6E8', bgCard),
    MapEntry('#34080B', rosaDeep),
    MapEntry('#5A0F14', rosaPrincipal),
    MapEntry('#A61B24', rosaClaro),
    MapEntry('#F9E0E2', rosaPale),
    MapEntry('#7A1515', errorDeep),
    MapEntry('#E84040', error),
    MapEntry('#FF8080', errorLight),
    MapEntry('#FFE4E4', errorPale),
    MapEntry('#FFFFFF', branco),
  ];
}

class TabuTypography {
  TabuTypography._();

  static const String displayFont = 'Anton';
  static const String bodyFont    = 'Barlow Condensed';

  static TextTheme get textTheme => const TextTheme(
    displayLarge:   TextStyle(fontFamily: displayFont,  fontSize: 80,  fontWeight: FontWeight.w400, letterSpacing: 4,   color: TabuColors.textoPrincipal, height: 1.0),
    displayMedium:  TextStyle(fontFamily: displayFont,  fontSize: 56,  fontWeight: FontWeight.w400, letterSpacing: 3,   color: TabuColors.textoPrincipal),
    displaySmall:   TextStyle(fontFamily: displayFont,  fontSize: 40,  fontWeight: FontWeight.w400, letterSpacing: 2,   color: TabuColors.textoPrincipal),
    headlineLarge:  TextStyle(fontFamily: displayFont,  fontSize: 32,  fontWeight: FontWeight.w400, letterSpacing: 1.5, color: TabuColors.textoPrincipal),
    headlineMedium: TextStyle(fontFamily: bodyFont,     fontSize: 24,  fontWeight: FontWeight.w600, letterSpacing: 1.2, color: TabuColors.textoPrincipal),
    headlineSmall:  TextStyle(fontFamily: bodyFont,     fontSize: 18,  fontWeight: FontWeight.w600, letterSpacing: 1.0, color: TabuColors.textoPrincipal),
    titleLarge:     TextStyle(fontFamily: bodyFont,     fontSize: 16,  fontWeight: FontWeight.w600, letterSpacing: 1.5, color: TabuColors.textoPrincipal),
    titleMedium:    TextStyle(fontFamily: bodyFont,     fontSize: 14,  fontWeight: FontWeight.w500, letterSpacing: 1.2, color: TabuColors.textoPrincipal),
    titleSmall:     TextStyle(fontFamily: bodyFont,     fontSize: 12,  fontWeight: FontWeight.w500, letterSpacing: 1.2, color: TabuColors.textoSecundario),
    bodyLarge:      TextStyle(fontFamily: bodyFont,     fontSize: 16,  fontWeight: FontWeight.w400, letterSpacing: 0.3, color: TabuColors.textoPrincipal,  height: 1.6),
    bodyMedium:     TextStyle(fontFamily: bodyFont,     fontSize: 14,  fontWeight: FontWeight.w400, letterSpacing: 0.2, color: TabuColors.textoSecundario, height: 1.5),
    bodySmall:      TextStyle(fontFamily: bodyFont,     fontSize: 12,  fontWeight: FontWeight.w400, letterSpacing: 0.4, color: TabuColors.textoMuted,      height: 1.4),
    labelLarge:     TextStyle(fontFamily: bodyFont,     fontSize: 13,  fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.textoPrincipal),
    labelMedium:    TextStyle(fontFamily: bodyFont,     fontSize: 11,  fontWeight: FontWeight.w600, letterSpacing: 2.0, color: TabuColors.textoSecundario),
    labelSmall:     TextStyle(fontFamily: bodyFont,     fontSize: 9,   fontWeight: FontWeight.w600, letterSpacing: 1.5, color: TabuColors.textoMuted),
  );
}

class TabuTheme {
  TabuTheme._();

  static const Color error      = TabuColors.error;
  static const Color errorLight = TabuColors.errorLight;
  static const Color errorDeep  = TabuColors.errorDeep;

  static ThemeData get main => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: TabuColors.bg,
    colorScheme: const ColorScheme.light(
      primary:          TabuColors.rosaPrincipal,
      onPrimary:        TabuColors.textoPrincipal,
      secondary:        TabuColors.rosaClaro,
      onSecondary:      TabuColors.textoPrincipal,
      tertiary:         TabuColors.rosaDeep,
      onTertiary:       TabuColors.textoPrincipal,
      surface:          TabuColors.bgCard,
      onSurface:        TabuColors.textoPrincipal,
      outline:          TabuColors.border,
      error:            TabuColors.error,
      onError:          TabuColors.textoPrincipal,
      errorContainer:   TabuColors.errorPale,
      onErrorContainer: TabuColors.errorDeep,
    ),
    textTheme: TabuTypography.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor:  TabuColors.bg,
      foregroundColor:  TabuColors.textoPrincipal,
      elevation:        0,
      scrolledUnderElevation: 0.5,
      shadowColor:      TabuColors.border,
      surfaceTintColor: Colors.transparent,
      centerTitle:      true,
      titleTextStyle: TextStyle(
        fontFamily: TabuTypography.displayFont,
        fontSize:   24,
        fontWeight: FontWeight.w400,
        letterSpacing: 6,
        color:      TabuColors.rosaPrincipal,
      ),
      iconTheme: IconThemeData(color: TabuColors.rosaPrincipal, size: 22),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      TabuColors.bg,
      selectedItemColor:    TabuColors.rosaPrincipal,
      unselectedItemColor:  TabuColors.textoMuted,
      selectedLabelStyle:   TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 2),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TabuColors.rosaPrincipal,
        foregroundColor: TabuColors.textoPrincipal,
        elevation:       0,
        shadowColor:     Colors.transparent,
        padding:         const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle:       const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TabuColors.rosaPrincipal,
        side:            const BorderSide(color: TabuColors.rosaPrincipal, width: 1.5),
        padding:         const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle:       const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TabuColors.rosaPrincipal,
        textStyle:       const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color:     TabuColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side:         const BorderSide(color: TabuColors.border, width: 0.8),
      ),
      margin: EdgeInsets.zero,
      shadowColor: TabuColors.glow,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: TabuColors.bgCard,
      border:             OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.border)),
      enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.border, width: 0.8)),
      focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.error, width: 1.0)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.error, width: 1.5)),
      errorStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.error,           fontSize: 11, letterSpacing: 1.2),
      labelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoSecundario, letterSpacing: 1.5, fontSize: 12),
      hintStyle:  const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoMuted,      letterSpacing: 1.5, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TabuColors.errorDeep,
      contentTextStyle: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        color:      TabuColors.errorLight,
        fontSize:   13,
        letterSpacing: 1.2,
      ),
      shape:         const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      behavior:      SnackBarBehavior.floating,
      showCloseIcon: true,
      closeIconColor: TabuColors.errorLight,
    ),
    dividerTheme: const DividerThemeData(color: TabuColors.border, thickness: 0.5),
    chipTheme: ChipThemeData(
      backgroundColor: TabuColors.rosaPale,
      selectedColor:   TabuColors.rosaPrincipal,
      labelStyle:      const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, letterSpacing: 2, color: TabuColors.textoPrincipal),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side:         const BorderSide(color: TabuColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    iconTheme:        const IconThemeData(color: TabuColors.textoSecundario, size: 20),
    primaryIconTheme: const IconThemeData(color: TabuColors.rosaPrincipal,   size: 20),
    listTileTheme: const ListTileThemeData(
      iconColor:   TabuColors.rosaPrincipal,
      textColor:   TabuColors.textoPrincipal,
      tileColor:   TabuColors.bg,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TabuColors.rosaPrincipal : TabuColors.textoMuted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TabuColors.rosaPale : TabuColors.border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TabuColors.rosaPrincipal : Colors.transparent),
      checkColor: WidgetStateProperty.all(TabuColors.textoPrincipal),
      side: const BorderSide(color: TabuColors.border, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? TabuColors.rosaPrincipal : TabuColors.textoMuted),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color:            TabuColors.rosaPrincipal,
      linearTrackColor: TabuColors.rosaPale,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor:   TabuColors.rosaPrincipal,
      inactiveTrackColor: TabuColors.rosaPale,
      thumbColor:         TabuColors.rosaPrincipal,
      overlayColor:       TabuColors.glow,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:             TabuColors.rosaPrincipal,
      unselectedLabelColor:   TabuColors.textoMuted,
      indicatorColor:         TabuColors.rosaPrincipal,
      labelStyle:             TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2),
      unselectedLabelStyle:   TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 12, letterSpacing: 2),
      dividerColor:           TabuColors.border,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TabuColors.rosaPrincipal,
      foregroundColor: TabuColors.textoPrincipal,
      elevation:       2,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color:        TabuColors.rosaDeep,
        borderRadius: BorderRadius.zero,
      ),
      textStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoPrincipal, fontSize: 11, letterSpacing: 1.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TabuColors.bg,
      elevation:       0,
      shape:           const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side:         BorderSide(color: TabuColors.border, width: 0.8),
      ),
      titleTextStyle: const TextStyle(fontFamily: TabuTypography.displayFont, fontSize: 22, letterSpacing: 2, color: TabuColors.textoPrincipal),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:   TabuColors.bg,
      surfaceTintColor:  Colors.transparent,
      shape:             RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      dragHandleColor:   TabuColors.border,
    ),
  );
}

class TabuGlow {
  TabuGlow._();

  static List<BoxShadow> rosaPrincipal({double blur = 16, double spread = 0}) => [
    BoxShadow(color: TabuColors.glow,                            blurRadius: blur,      spreadRadius: spread, offset: const Offset(0, 4)),
    BoxShadow(color: TabuColors.rosaPrincipal.withOpacity(0.08), blurRadius: blur * 2, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> rosaSubtle({double blur = 8}) => [
    BoxShadow(color: TabuColors.border, blurRadius: blur, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> branco({double blur = 16}) => [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: blur, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> error({double blur = 16, double spread = 0}) => [
    BoxShadow(color: TabuColors.errorGlow,               blurRadius: blur,      spreadRadius: spread, offset: const Offset(0, 4)),
    BoxShadow(color: TabuColors.error.withOpacity(0.12), blurRadius: blur * 2, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> errorSubtle({double blur = 8}) => [
    BoxShadow(color: TabuColors.errorBorder, blurRadius: blur, offset: const Offset(0, 2)),
  ];

  // Card elevation no tema claro
  static List<BoxShadow> card({double blur = 12}) => [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: blur,     offset: const Offset(0, 2)),
    BoxShadow(color: TabuColors.border,              blurRadius: blur / 2, offset: const Offset(0, 1)),
  ];
}