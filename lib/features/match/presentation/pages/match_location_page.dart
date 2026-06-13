// lib/features/match/presentation/pages/match_location_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/match/data/models/match_filter_model.dart';

// ── paleta ────────────────────────────────────────────────────────────────
const _ink       = Color(0xFF080808);
const _surface   = Color(0xFF111111);
const _surfaceHi = Color(0xFF191919);
const _divider   = Color(0xFF1C1C1C);

// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════
class MatchLocationPage extends StatefulWidget {
  const MatchLocationPage({super.key, required this.filter});
  final MatchFilterModel filter;

  @override
  State<MatchLocationPage> createState() => _MatchLocationPageState();
}

class _MatchLocationPageState extends State<MatchLocationPage> {
  late TipoLocalizacao _tipo;
  late TextEditingController _searchCtrl;
  bool _showSearch    = false;
  bool _searchFocused = false;

  // ── FIX: mock agora inclui coordenadas reais de cada cidade ──────────────
  // Cada entrada é (cidade, estado, lat, lng).
  // Isso permite que filterHasCoords == true em match_profile_page,
  // habilitando o filtro de distância mesmo sem GPS do dispositivo.
  static const _cidadesMock = [
    ('São Paulo',            'SP', -23.5505, -46.6333),
    ('Rio de Janeiro',       'RJ', -22.9068, -43.1729),
    ('Belo Horizonte',       'MG', -19.9167, -43.9345),
    ('Brasília',             'DF', -15.7797, -47.9297),
    ('Goiânia',              'GO', -16.6864, -49.2643),
    ('Aparecida de Goiânia', 'GO', -16.8217, -49.2437),
    ('Salvador',             'BA', -12.9714, -38.5014),
    ('Fortaleza',            'CE',  -3.7172, -38.5433),
    ('Curitiba',             'PR', -25.4284, -49.2733),
    ('Manaus',               'AM',  -3.1190, -60.0217),
    ('Recife',               'PE',  -8.0476, -34.8770),
    ('Porto Alegre',         'RS', -30.0277, -51.2287),
    ('Belém',                'PA',  -1.4558, -48.5044),
    ('Florianópolis',        'SC', -27.5954, -48.5480),
    ('Campo Grande',         'MS', -20.4697, -54.6201),
  ];

  List<(String, String, double, double)> _resultados = [];

  // Cidade/estado/coords selecionados pelo usuário no campo de busca
  String? _cidadeSelecionada;
  String? _estadoSelecionado;
  double? _latSelecionada;
  double? _lngSelecionada;

  @override
  void initState() {
    super.initState();
    _tipo       = widget.filter.tipoLocalizacao;
    _searchCtrl = TextEditingController(text: widget.filter.cidade ?? '');

    // Restaura coordenadas já salvas no filtro atual
    _cidadeSelecionada = widget.filter.cidade;
    _estadoSelecionado = widget.filter.estado;
    _latSelecionada    = widget.filter.lat;
    _lngSelecionada    = widget.filter.lng;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── lógica ────────────────────────────────────────────────────────────────
  void _selectAtual() {
    HapticFeedback.lightImpact();
    setState(() {
      _tipo       = TipoLocalizacao.atual;
      _showSearch = false;
    });
  }

  void _selectPersonalizada() {
    HapticFeedback.lightImpact();
    setState(() {
      _tipo       = TipoLocalizacao.personalizada;
      _showSearch = true;
    });
    Future.microtask(() => FocusScope.of(context).nextFocus());
  }

  void _onSearchChanged(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _resultados = query.isEmpty
          ? []
          : _cidadesMock
              .where((c) =>
                  c.$1.toLowerCase().contains(query) ||
                  c.$2.toLowerCase().contains(query))
              .toList();

      // Se o usuário editou o campo manualmente, limpa a seleção anterior
      // para evitar que coords de uma cidade velha fiquem associadas ao
      // novo texto digitado.
      _cidadeSelecionada = null;
      _estadoSelecionado = null;
      _latSelecionada    = null;
      _lngSelecionada    = null;
    });
  }

  // FIX: agora recebe e armazena lat/lng junto com cidade/estado
  void _selectCity(String cidade, String estado, double lat, double lng) {
    HapticFeedback.selectionClick();
    _searchCtrl.text = cidade;
    setState(() {
      _resultados        = [];
      _cidadeSelecionada = cidade;
      _estadoSelecionado = estado;
      _latSelecionada    = lat;
      _lngSelecionada    = lng;
    });
    FocusScope.of(context).unfocus();
  }

  void _confirm() {
    late MatchFilterModel result;

    if (_tipo == TipoLocalizacao.atual) {
      result = widget.filter.copyWith(
        tipoLocalizacao: TipoLocalizacao.atual,
        cidade: null, estado: null, lat: null, lng: null,
      );
    } else {
      // FIX: usa cidade/estado/lat/lng da cidade selecionada na lista.
      // Se o usuário digitou algo mas não selecionou da lista, usa apenas
      // o texto (sem coords) — o filtro de distância ficará desabilitado
      // nesse caso, como esperado.
      final cidade = _cidadeSelecionada ?? _searchCtrl.text.trim();
      final estado = _estadoSelecionado;
      final lat    = _latSelecionada;
      final lng    = _lngSelecionada;

      result = widget.filter.copyWith(
        tipoLocalizacao: TipoLocalizacao.personalizada,
        cidade:          cidade.isNotEmpty ? cidade : null,
        estado:          estado,
        lat:             lat,
        lng:             lng,
      );
    }

    Navigator.of(context).pop(result);
  }

  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: _ink,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroText(),
                        const SizedBox(height: 32),
                        _buildOptionCard(
                          icon:        Icons.my_location_rounded,
                          title:       'Localização atual (GPS)',
                          subtitle:    'Fallback: usado apenas quando cidade e estado não estão definidos no perfil.',
                          isSelected:  _tipo == TipoLocalizacao.atual,
                          onTap:       _selectAtual,
                        ),
                        const SizedBox(height: 14),
                        _buildOptionCard(
                          icon:        Icons.travel_explore_rounded,
                          title:       'Outra cidade',
                          subtitle:    'Conecte-se com pessoas de outra cidade, independente do seu perfil.',
                          isSelected:  _tipo == TipoLocalizacao.personalizada,
                          onTap:       _selectPersonalizada,
                        ),

                        // Nota sobre prioridade
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF8A).withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4CAF8A).withOpacity(0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 15,
                                  color: const Color(0xFF4CAF8A).withOpacity(0.80)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize:   12,
                                      height:     1.55,
                                      color: const Color(0xFF4CAF8A).withOpacity(0.75),
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: 'Prioridade: ',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      TextSpan(
                                        text: 'se o seu perfil tiver cidade e estado definidos, '
                                            'eles sempre terão preferência sobre o GPS. '
                                            'O GPS é usado apenas como fallback quando o perfil não tem localização.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── campo de busca ────────────────────────────────
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve:    Curves.easeOut,
                          child: _showSearch
                              ? Column(
                                  children: [
                                    const SizedBox(height: 24),
                                    _buildSearchField(),
                                    if (_resultados.isNotEmpty)
                                      _buildResultsList(),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── botão confirmar ───────────────────────────────────────
                _buildConfirmBtn(),
              ],
            ),
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
        color:  _ink,
        border: Border(bottom: BorderSide(color: TabuColors.rosaPrincipal.withOpacity(0.14), width: 0.8)),
      ),
      child: Row(
        children: [
          _HeaderBtn(
            icon:  Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LOCALIZAÇÃO',
                style: TextStyle(
                  fontFamily:    TabuTypography.displayFont,
                  fontSize:      14,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: 3.5,
                  color:         Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 1, width: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [TabuColors.rosaPrincipal.withOpacity(0), TabuColors.rosaPrincipal, TabuColors.rosaPrincipal.withOpacity(0)],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ── texto hero ────────────────────────────────────────────────────────────
  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Onde você\n',
                style: TextStyle(
                  fontFamily:    TabuTypography.displayFont,
                  fontSize:      30,
                  fontWeight:    FontWeight.w900,
                  color:         Colors.white,
                  height:        1.2,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'quer se conectar?',
                style: TextStyle(
                  fontFamily:    TabuTypography.displayFont,
                  fontSize:      30,
                  fontWeight:    FontWeight.w900,
                  color:         TabuColors.rosaPrincipal,
                  height:        1.2,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sua localização nunca é compartilhada\npublicamente com outros usuários.',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize:   13,
            height:     1.6,
            color:      Colors.white.withOpacity(0.35),
          ),
        ),
      ],
    );
  }

  // ── option card ───────────────────────────────────────────────────────────
  Widget _buildOptionCard({
    required IconData  icon,
    required String    title,
    required String    subtitle,
    required bool      isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        isSelected ? TabuColors.rosaPrincipal.withOpacity(0.08) : _surfaceHi,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? TabuColors.rosaPrincipal.withOpacity(0.60) : TabuColors.rosaPrincipal.withOpacity(0.12),
            width: isSelected ? 1.0 : 0.7,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? TabuColors.rosaPrincipal.withOpacity(0.18)
                    : TabuColors.rosaPrincipal.withOpacity(0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isSelected ? TabuColors.rosaPrincipal : TabuColors.rosaPrincipal.withOpacity(0.18),
                  width: 0.8,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? TabuColors.rosaPrincipal : TabuColors.rosaPrincipal.withOpacity(0.50),
                size:  22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize:   15,
                      fontWeight: FontWeight.w600,
                      color:      isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize:   12,
                      height:     1.4,
                      color:      Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color:  isSelected ? TabuColors.rosaPrincipal : Colors.transparent,
                shape:  BoxShape.circle,
                border: Border.all(
                  color: isSelected ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.20),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: _ink, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── campo de busca ────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return Focus(
      onFocusChange: (f) => setState(() => _searchFocused = f),
      child: Container(
        decoration: BoxDecoration(
          color:        _surfaceHi,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchFocused ? TabuColors.rosaPrincipal.withOpacity(0.55) : TabuColors.rosaPrincipal.withOpacity(0.18),
            width: _searchFocused ? 1.0 : 0.7,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: TabuColors.rosaPrincipal.withOpacity(0.60), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:   _searchCtrl,
                onChanged:    _onSearchChanged,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize:   14,
                  color:      Colors.white,
                ),
                decoration: InputDecoration(
                  border:      InputBorder.none,
                  hintText:    'Digite uma cidade…',
                  hintStyle:   TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize:   14,
                    color:      Colors.white.withOpacity(0.28),
                  ),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _onSearchChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white.withOpacity(0.30), size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── lista de resultados ───────────────────────────────────────────────────
  Widget _buildResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.18), width: 0.7),
      ),
      child: Column(
        children: _resultados.asMap().entries.map((entry) {
          final i      = entry.key;
          final cidade = entry.value.$1;
          final estado = entry.value.$2;
          final lat    = entry.value.$3;
          final lng    = entry.value.$4;
          final isLast = i == _resultados.length - 1;

          return GestureDetector(
            // FIX: passa lat/lng para _selectCity
            onTap: () => _selectCity(cidade, estado, lat, lng),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: _divider, width: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: TabuColors.rosaPrincipal.withOpacity(0.55), size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cidade,
                      style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize:   14,
                        color:      Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                  Text(
                    estado,
                    style: TextStyle(
                      fontFamily:    TabuTypography.bodyFont,
                      fontSize:      11,
                      fontWeight:    FontWeight.w600,
                      letterSpacing: 1.5,
                      color:         TabuColors.rosaPrincipal.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── confirmar ─────────────────────────────────────────────────────────────
  Widget _buildConfirmBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: GestureDetector(
        onTap: _confirm,
        child: Container(
          width:  double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TabuColors.rosaPrincipal.withOpacity(0.85),
                TabuColors.rosaPrincipal,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      TabuColors.rosaPrincipal.withOpacity(0.30),
                blurRadius: 20,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'CONFIRMAR',
              style: TextStyle(
                fontFamily:    TabuTypography.displayFont,
                fontSize:      13,
                fontWeight:    FontWeight.w800,
                letterSpacing: 3.0,
                color:         Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HEADER BUTTON
// ════════════════════════════════════════════════════════════════════════════
class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color:        TabuColors.bg,
        borderRadius: BorderRadius.circular(11),
        border:       Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.18), width: 0.7),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.60), size: 18),
    ),
  );
}