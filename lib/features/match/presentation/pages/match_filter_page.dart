// lib/features/match/presentation/pages/match_filter_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/match/data/models/match_filter_model.dart';
import 'package:tclub/features/match/presentation/pages/match_location_page.dart';

enum MatchLocationSource { profile, profileCoords, gps, none }

// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════
class MatchFilterPage extends StatefulWidget {
  const MatchFilterPage({
    super.key,
    this.initialFilter,
    this.locationSource = MatchLocationSource.none,
  });
  final MatchFilterModel?   initialFilter;
  final MatchLocationSource locationSource;

  @override
  State<MatchFilterPage> createState() => _MatchFilterPageState();
}

class _MatchFilterPageState extends State<MatchFilterPage> {
  late MatchFilterModel _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? const MatchFilterModel();
  }

  void _update(MatchFilterModel f) => setState(() => _filter = f);

  void _toggleGenero(FiltroGenero v) {
    final next = Set<FiltroGenero>.from(_filter.generos);
    next.contains(v) ? next.remove(v) : next.add(v);
    _update(_filter.copyWith(generos: next));
  }

  void _toggleOrientacao(FiltroOrientacao v) {
    final next = Set<FiltroOrientacao>.from(_filter.orientacoes);
    next.contains(v) ? next.remove(v) : next.add(v);
    _update(_filter.copyWith(orientacoes: next));
  }

  void _toggleRelacionamento(FiltroRelacionamento v) {
    final next = Set<FiltroRelacionamento>.from(_filter.relacionamentos);
    next.contains(v) ? next.remove(v) : next.add(v);
    _update(_filter.copyWith(relacionamentos: next));
  }

  void _setDistancia(double v)    => _update(_filter.copyWith(distanciaKm: v));
  void _setOnlyInDistance(bool v) => _update(_filter.copyWith(onlyInDistance: v));

  void _setIdadeMin(int v) {
    final max = v > _filter.idadeMax ? v : _filter.idadeMax;
    _update(_filter.copyWith(idadeMin: v, idadeMax: max));
  }

  void _setIdadeMax(int v) {
    final min = v < _filter.idadeMin ? v : _filter.idadeMin;
    _update(_filter.copyWith(idadeMax: v, idadeMin: min));
  }

  void _setOnlyInAge(bool v) => _update(_filter.copyWith(onlyInAge: v));

  void _save() => Navigator.of(context).pop(_filter);

  Future<void> _openLocationPage() async {
    final result = await Navigator.of(context).push<MatchFilterModel>(
      MaterialPageRoute(builder: (_) => MatchLocationPage(filter: _filter)),
    );
    if (result != null) _update(result);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // ← tema claro = ícones escuros na status bar
      child: Scaffold(
        backgroundColor: TClubColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    children: [
                      _buildProcurandoPorSection(),
                      _buildDistanciaSection(),
                      _buildIdadeSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color:  TClubColors.bg,
        border: Border(
          bottom: BorderSide(color: TClubColors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          _HeaderBtn(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PREFERÊNCIAS',
                style: TextStyle(
                  fontFamily:    TClubTypography.displayFont,
                  fontSize:      14,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: 3.5,
                  color:         TClubColors.textoPrincipal, // ← era Colors.white
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 1, width: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TClubColors.redPrincipal.withOpacity(0.0),
                      TClubColors.redPrincipal,
                      TClubColors.redPrincipal.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _HeaderBtn(
            icon:  Icons.check_rounded,
            color: TClubColors.redPrincipal,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  // ── procurando por ────────────────────────────────────────────────────────
  Widget _buildProcurandoPorSection() {
    return _Section(
      children: [
        const _SectionLabel(text: 'PROCURANDO POR'),
        const SizedBox(height: 20),
        const _ChipGroupLabel(text: 'Gênero'),
        const SizedBox(height: 10),
        _ChipGroup<FiltroGenero>(
          options:  FiltroGenero.values,
          selected: _filter.generos,
          label:    (v) => v.label,
          onToggle: _toggleGenero,
        ),
        const SizedBox(height: 20),
        const _ChipGroupLabel(text: 'Orientação Sexual'),
        const SizedBox(height: 10),
        _ChipGroup<FiltroOrientacao>(
          options:  FiltroOrientacao.values,
          selected: _filter.orientacoes,
          label:    (v) => v.label,
          onToggle: _toggleOrientacao,
        ),
        const SizedBox(height: 20),
        const _ChipGroupLabel(text: 'Tipo de Relacionamento'),
        const SizedBox(height: 10),
        _ChipGroup<FiltroRelacionamento>(
          options:  FiltroRelacionamento.values,
          selected: _filter.relacionamentos,
          label:    (v) => v.label,
          onToggle: _toggleRelacionamento,
        ),
        const SizedBox(height: 8),
        Text(
          'Vazio = sem filtro (mostra todos)',
          style: TextStyle(
            fontFamily:    TClubTypography.bodyFont,
            fontSize:      11,
            letterSpacing: 0.3,
            color:         TClubColors.textoMuted,
          ),
        ),
      ],
    );
  }

  // ── distância ─────────────────────────────────────────────────────────────
  Widget _buildDistanciaSection() {
    final km  = _filter.distanciaKm.round();
    final src = widget.locationSource;
    final bool hasLocation = src == MatchLocationSource.profile ||
                             src == MatchLocationSource.profileCoords ||
                             src == MatchLocationSource.gps;

    final String locationStatusText;
    final IconData locationStatusIcon;
    final Color locationStatusColor;

    if (src == MatchLocationSource.profile) {
      locationStatusText  = 'Usando localização do perfil (cidade/estado) — prioridade máxima.';
      locationStatusIcon  = Icons.person_pin_circle_rounded;
      locationStatusColor = const Color(0xFF2E7D5A);
    } else if (src == MatchLocationSource.profileCoords) {
      locationStatusText  = 'Usando coordenadas do perfil. Complete cidade e estado para melhor precisão.';
      locationStatusIcon  = Icons.location_on_rounded;
      locationStatusColor = const Color(0xFFB26A00);
    } else if (src == MatchLocationSource.gps) {
      locationStatusText  = 'Usando GPS do dispositivo. Complete seu perfil com cidade/estado para não depender do GPS.';
      locationStatusIcon  = Icons.my_location_rounded;
      locationStatusColor = const Color(0xFFB26A00);
    } else {
      locationStatusText  = 'Sem localização definida. O filtro de distância não funcionará até que você defina cidade/estado no perfil ou permita o GPS.';
      locationStatusIcon  = Icons.location_off_rounded;
      locationStatusColor = TClubColors.error;
    }

    return _Section(
      children: [
        const _SectionLabel(text: 'DISTÂNCIA'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color:        locationStatusColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
              color: locationStatusColor.withOpacity(0.30), width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(locationStatusIcon, color: locationStatusColor, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locationStatusText,
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize:   12,
                    height:     1.5,
                    color:      locationStatusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!hasLocation) ...[
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.35,
            child: _buildDistanciaControls(km),
          ),
          const SizedBox(height: 10),
          Text(
            'Defina sua localização para habilitar o filtro de distância.',
            style: TextStyle(
              fontFamily:    TClubTypography.bodyFont,
              fontSize:      11,
              letterSpacing: 0.2,
              color:         TClubColors.error,
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          _buildDistanciaControls(km),
        ],
      ],
    );
  }

  Widget _buildDistanciaControls(int km) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$km',
                    style: TextStyle(
                      fontFamily: TClubTypography.displayFont,
                      fontSize:   32,
                      fontWeight: FontWeight.w800,
                      color:      TClubColors.textoPrincipal, // ← era Colors.white
                    ),
                  ),
                  TextSpan(
                    text: ' km',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize:   14,
                      color:      TClubColors.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'máx 320 km',
              style: TextStyle(
                fontFamily:    TClubTypography.bodyFont,
                fontSize:      10,
                letterSpacing: 1.5,
                color:         TClubColors.textoMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LuxSlider(
          value:     _filter.distanciaKm,
          min:       1,
          max:       320,
          onChanged: _setDistancia,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _MinLabel(text: '1 km'),
            _MinLabel(text: '320 km'),
          ],
        ),
        const SizedBox(height: 20),
        _ToggleRow(
          label:     'Mostrar apenas nesta distância',
          value:     _filter.onlyInDistance,
          onChanged: _setOnlyInDistance,
        ),
      ],
    );
  }

  // ── faixa etária ──────────────────────────────────────────────────────────
  Widget _buildIdadeSection() {
    return _Section(
      children: [
        const _SectionLabel(text: 'FAIXA ETÁRIA'),
        const SizedBox(height: 20),
        _AgePickerRow(
          minAge:       _filter.idadeMin,
          maxAge:       _filter.idadeMax,
          onMinChanged: _setIdadeMin,
          onMaxChanged: _setIdadeMax,
        ),
        const SizedBox(height: 20),
        _ToggleRow(
          label:     'Mostrar apenas nesta faixa etária',
          value:     _filter.onlyInAge,
          onChanged: _setOnlyInAge,
        ),
      ],
    );
  }

  // ── localização (mantido para uso futuro) ─────────────────────────────────
  Widget _buildLocalizacaoSection() {
    return _Section(
      children: [
        const _SectionLabel(text: 'LOCALIZAÇÃO'),
        const SizedBox(height: 10),
        Text(
          'Mude sua localização para se conectar com\npessoas em outros locais.',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize:   13,
            height:     1.65,
            color:      TClubColors.textoMuted,
          ),
        ),
        const SizedBox(height: 20),
        _LocationTile(
          label:  _filter.localizacaoLabel,
          isGps:  _filter.isLocalizacaoAtual,
          onTap:  _openLocationPage,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CHIP GROUP
// ════════════════════════════════════════════════════════════════════════════

class _ChipGroupLabel extends StatelessWidget {
  const _ChipGroupLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily:    TClubTypography.bodyFont,
      fontSize:      11,
      fontWeight:    FontWeight.w600,
      letterSpacing: 1.2,
      color:         TClubColors.textoMuted,
    ),
  );
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.label,
    required this.onToggle,
  });

  final List<T>            options;
  final Set<T>             selected;
  final String Function(T) label;
  final void Function(T)   onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final active = selected.contains(opt);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(opt);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve:    Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? TClubColors.redPrincipal.withOpacity(0.10)
                  : TClubColors.bgCard,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: active
                    ? TClubColors.redPrincipal
                    : TClubColors.border,
                width: active ? 1.4 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) ...[
                  Icon(Icons.check_rounded,
                      size: 13, color: TClubColors.redPrincipal),
                  const SizedBox(width: 5),
                ],
                Text(
                  label(opt),
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize:   13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active
                        ? TClubColors.redPrincipal
                        : TClubColors.textoSecundario, // ← era Colors.white.withOpacity(0.65)
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AGE PICKER
// ════════════════════════════════════════════════════════════════════════════
class _AgePickerRow extends StatelessWidget {
  const _AgePickerRow({
    required this.minAge,
    required this.maxAge,
    required this.onMinChanged,
    required this.onMaxChanged,
  });

  final int               minAge;
  final int               maxAge;
  final ValueChanged<int> onMinChanged;
  final ValueChanged<int> onMaxChanged;

  static const int _kMin = 18;
  static const int _kMax = 70;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color:        TClubColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(
          color: TClubColors.redPrincipal.withOpacity(0.35), width: 0.7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(
                    'DE',
                    style: TextStyle(
                      fontFamily:    TClubTypography.bodyFont,
                      fontSize:      9,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 2.5,
                      color:         TClubColors.redPrincipal.withOpacity(0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: _AgeWheel(
                    initialValue: minAge,
                    min:          _kMin,
                    max:          _kMax,
                    onChanged:    onMinChanged,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 1, height: 40,
                    color: TClubColors.redPrincipal.withOpacity(0.22)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '–',
                    style: TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.w200,
                      color:      TClubColors.redPrincipal.withOpacity(0.55),
                    ),
                  ),
                ),
                Container(
                    width: 1, height: 40,
                    color: TClubColors.redPrincipal.withOpacity(0.22)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(
                    'ATÉ',
                    style: TextStyle(
                      fontFamily:    TClubTypography.bodyFont,
                      fontSize:      9,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 2.5,
                      color:         TClubColors.redPrincipal.withOpacity(0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: _AgeWheel(
                    initialValue: maxAge,
                    min:          _kMin,
                    max:          _kMax,
                    onChanged:    onMaxChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeWheel extends StatefulWidget {
  const _AgeWheel({
    required this.initialValue,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int               initialValue;
  final int               min;
  final int               max;
  final ValueChanged<int> onChanged;

  @override
  State<_AgeWheel> createState() => _AgeWheelState();
}

class _AgeWheelState extends State<_AgeWheel> {
  late final FixedExtentScrollController _ctrl;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _ctrl = FixedExtentScrollController(
        initialItem: widget.initialValue - widget.min);
  }

  @override
  void didUpdateWidget(_AgeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _currentValue = widget.initialValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) {
          _ctrl.animateToItem(
            widget.initialValue - widget.min,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller:    _ctrl,
      itemExtent:    38,
      physics:       const FixedExtentScrollPhysics(),
      perspective:   0.003,
      diameterRatio: 1.4,
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        _currentValue = widget.min + i;
        widget.onChanged(_currentValue);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.max - widget.min + 1,
        builder: (_, i) {
          final age      = widget.min + i;
          final isCenter = age == _currentValue;
          return Center(
            child: Text(
              '$age',
              style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize:   isCenter ? 26 : 18,
                fontWeight: isCenter ? FontWeight.w800 : FontWeight.w300,
                color: isCenter
                    ? TClubColors.textoPrincipal          // ← era Colors.white
                    : TClubColors.textoMuted,             // ← era Colors.white.withOpacity(0.28)
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 2, height: 13,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              TClubColors.redPrincipal,
              TClubColors.redPrincipal.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        text,
        style: const TextStyle(
          fontSize:      10,
          fontWeight:    FontWeight.w800,
          letterSpacing: 3.0,
          color:         TClubColors.redPrincipal,
        ),
      ),
    ],
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String             label;
  final bool               value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize:   13,
            color:      TClubColors.textoSecundario, // ← era Colors.white.withOpacity(0.50)
          ),
        ),
      ),
      const SizedBox(width: 16),
      Switch(
        value:              value,
        onChanged:          onChanged,
        activeColor:        TClubColors.bg,
        activeTrackColor:   TClubColors.redPrincipal,
        inactiveThumbColor: TClubColors.textoMuted,
        inactiveTrackColor: TClubColors.border,
      ),
    ],
  );
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.label,
    required this.isGps,
    required this.onTap,
  });
  final String       label;
  final bool         isGps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        TClubColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: TClubColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        TClubColors.redPrincipal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.25), width: 0.8),
              ),
              child: Icon(
                isGps ? Icons.my_location_rounded : Icons.location_on_outlined,
                color: TClubColors.redPrincipal,
                size:  17,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                  color:      TClubColors.textoPrincipal, // ← era Colors.white
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: TClubColors.textoMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LuxSlider extends StatelessWidget {
  const _LuxSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double               value;
  final double               min;
  final double               max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      activeTrackColor:   TClubColors.redPrincipal,
      inactiveTrackColor: TClubColors.redPale,
      thumbColor:         TClubColors.redPrincipal,
      overlayColor:       TClubColors.redPrincipal.withOpacity(0.12),
      trackHeight:        3.0,
      thumbShape:         const _LuxThumb(),
      overlayShape:       const RoundSliderOverlayShape(overlayRadius: 22),
    ),
    child: Slider(
      value:     value.clamp(min, max),
      min:       min,
      max:       max,
      onChanged: onChanged,
    ),
  );
}

class _LuxThumb extends SliderComponentShape {
  const _LuxThumb();
  @override
  Size getPreferredSize(bool _, bool __) => const Size(22, 22);

  @override
  void paint(
    PaintingContext ctx,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = ctx.canvas;
    // sombra sutil
    c.drawCircle(
      center, 11,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // fundo branco
    c.drawCircle(center, 10, Paint()..color = TClubColors.bg);
    // borda rosa
    c.drawCircle(
      center, 10,
      Paint()
        ..color     = TClubColors.redPrincipal
        ..style     = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // ponto central
    c.drawCircle(center, 4, Paint()..color = TClubColors.redPrincipal);
  }
}

class _MinLabel extends StatelessWidget {
  const _MinLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily:    TClubTypography.bodyFont,
      fontSize:      10,
      letterSpacing: 0.5,
      color:         TClubColors.textoMuted,
    ),
  );
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap, this.color});
  final IconData     icon;
  final VoidCallback onTap;
  final Color?       color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color:        TClubColors.redPrincipal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        border:       Border.all(
          color: TClubColors.redPrincipal.withOpacity(0.35), width: 0.8),
      ),
      child: Icon(
        icon,
        color: color ?? TClubColors.textoSecundario, // ← era Colors.white.withOpacity(0.60)
        size: 18,
      ),
    ),
  );
}

