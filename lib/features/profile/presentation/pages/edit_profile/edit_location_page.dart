// lib/screens/screens_home/perfil_screen/edit_perfil/edit_localizacao_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/profile/controller/edit_location_controller.dart';
import 'package:tclub/features/profile/data/services/ibge_service.dart';
import 'package:tclub/features/profile/data/models/location_model.dart';
import 'package:tclub/features/profile/data/repositories/location_repository.dart';
import 'package:tclub/features/profile/data/services/location_service.dart';
import 'package:tclub/features/profile/presentation/widgets/edit_profile_shareds.dart';

const _kEstados = [
  {'sigla': 'AC', 'nome': 'Acre'},
  {'sigla': 'AL', 'nome': 'Alagoas'},
  {'sigla': 'AP', 'nome': 'Amapá'},
  {'sigla': 'AM', 'nome': 'Amazonas'},
  {'sigla': 'BA', 'nome': 'Bahia'},
  {'sigla': 'CE', 'nome': 'Ceará'},
  {'sigla': 'DF', 'nome': 'Distrito Federal'},
  {'sigla': 'ES', 'nome': 'Espírito Santo'},
  {'sigla': 'GO', 'nome': 'Goiás'},
  {'sigla': 'MA', 'nome': 'Maranhão'},
  {'sigla': 'MT', 'nome': 'Mato Grosso'},
  {'sigla': 'MS', 'nome': 'Mato Grosso do Sul'},
  {'sigla': 'MG', 'nome': 'Minas Gerais'},
  {'sigla': 'PA', 'nome': 'Pará'},
  {'sigla': 'PB', 'nome': 'Paraíba'},
  {'sigla': 'PR', 'nome': 'Paraná'},
  {'sigla': 'PE', 'nome': 'Pernambuco'},
  {'sigla': 'PI', 'nome': 'Piauí'},
  {'sigla': 'RJ', 'nome': 'Rio de Janeiro'},
  {'sigla': 'RN', 'nome': 'Rio Grande do Norte'},
  {'sigla': 'RS', 'nome': 'Rio Grande do Sul'},
  {'sigla': 'RO', 'nome': 'Rondônia'},
  {'sigla': 'RR', 'nome': 'Roraima'},
  {'sigla': 'SC', 'nome': 'Santa Catarina'},
  {'sigla': 'SP', 'nome': 'São Paulo'},
  {'sigla': 'SE', 'nome': 'Sergipe'},
  {'sigla': 'TO', 'nome': 'Tocantins'},
];

// ════════════════════════════════════════════════════════════════════════════
class EditLocationPage extends StatefulWidget {
  const EditLocationPage({super.key, required this.userData});
  final Map<String, dynamic> userData;

  @override
  State<EditLocationPage> createState() => _EditLocationPageState();
}

class _EditLocationPageState extends State<EditLocationPage> {
  final _bairroFocus = FocusNode();
  final _bairroCtrl  = TextEditingController();

  late final EditLocationController _controller;

  CidadeIBGE? _selectedCidade;

  @override
  void initState() {
    super.initState();

    _bairroCtrl.text = widget.userData['bairro'] as String? ?? '';

    _controller = EditLocationController(
      service: LocationService(
        repository: LocationRepository(
          db:         FirebaseDatabase.instance,
          httpClient: http.Client(),
        ),
      ),
      ibgeService: IbgeService(),
      userData:    widget.userData,
    );

    _controller.addListener(_onControllerChange);
    _bairroFocus.addListener(_onBairroFocus);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _bairroFocus.removeListener(_onBairroFocus);
    _bairroCtrl.dispose();
    _bairroFocus.dispose();
    super.dispose();
  }

  // ── Listeners ──────────────────────────────────────────────────────────

  void _onControllerChange() {
    if (!mounted) return;

    if (_controller.saveStatus == SaveStatus.success) {
      Navigator.pop(context, {
        'state':     _controller.state,
        'city':      _controller.city,
        'bairro':    _bairroCtrl.text.trim(),
        'latitude':  _controller.lat,
        'longitude': _controller.lng,
      });
      return;
    }
    if (_controller.saveStatus == SaveStatus.error) {
      _snack(_controller.saveError ?? 'Erro ao salvar');
      _controller.resetSaveStatus();
    }

    // Quando cidades são carregadas, tenta restaurar a cidade salva anteriormente
    if (_selectedCidade == null &&
        _controller.city.isNotEmpty &&
        _controller.cidades.isNotEmpty) {
      final match = _controller.cidades.where(
        (c) => c.nome.toLowerCase() == _controller.city.toLowerCase(),
      );
      if (match.isNotEmpty) _selectedCidade = match.first;
    }

    setState(() {});
  }

  void _onBairroFocus() {
    // apenas reconstrói para atualizar a borda de foco
    if (mounted) setState(() {});
  }

  // ── Save ───────────────────────────────────────────────────────────────

  void _save() {
    if (!_controller.stateOk)  { _snack('Selecione seu estado');   return; }
    if (!_controller.cityOk)   { _snack('Selecione sua cidade');   return; }
    if (!_controller.bairroOk) {
      _snack(_controller.bairroError ?? 'Selecione seu bairro nas sugestões');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { _snack('Usuário não autenticado'); return; }
    _controller.save(uid);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TClubColors.errorDeep,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      content: Text(
        msg.toUpperCase(),
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: TClubColors.errorLight,
        ),
      ),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return EditPageScaffold(
      title:  'LOCALIZAÇÃO',
      onSave: _controller.isSaving ? null : _save,
      busy:   _controller.isSaving,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InfoBox(
                text:
                    'Selecione o estado, escolha a cidade no menu e confirme seu bairro nas sugestões.',
              ),
              const SizedBox(height: 24),
              const SectionLabel(label: 'ESTADO'),
              const SizedBox(height: 12),
              _buildEstadoDropdown(),
              const SizedBox(height: 24),
              const SectionLabel(label: 'CIDADE'),
              const SizedBox(height: 12),
              _buildCidadeDropdown(),
              const SizedBox(height: 24),
              const SectionLabel(label: 'BAIRRO'),
              const SizedBox(height: 12),
              _buildBairroField(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets de campo ───────────────────────────────────────────────────

  Widget _buildEstadoDropdown() {
    final ok = _controller.stateOk;
    return Container(
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(
          color: ok ? TClubColors.redPrincipal : TClubColors.border,
          width: ok ? 1.5 : 0.8,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _controller.state,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: TClubColors.subtle,
          size: 20,
        ),
        dropdownColor: TClubColors.bgAlt,
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: TClubColors.textoPrincipal,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
        hint: const Text(
          'Selecione seu estado',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 13,
            color: TClubColors.subtle,
          ),
        ),
        onChanged: (val) {
          if (val == null) return;
          setState(() {
            _selectedCidade = null;
            _bairroCtrl.clear();
          });
          _controller.selectState(val);
        },
        items: _kEstados
            .map((e) => DropdownMenuItem<String>(
                  value: e['sigla'],
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TClubColors.redPrincipal.withOpacity(0.15),
                        border: Border.all(color: TClubColors.border, width: 0.5),
                      ),
                      child: Text(
                        e['sigla']!,
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: TClubColors.redPrincipal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      e['nome']!,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 13,
                        color: TClubColors.textoPrincipal,
                      ),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCidadeDropdown() {
    final status  = _controller.cityStatus;
    final enabled = _controller.stateOk && !_controller.loadingCidades;
    final borda   = status == LocationFieldStatus.ok
        ? TClubColors.redPrincipal
        : status == LocationFieldStatus.error
            ? TClubColors.error
            : status == LocationFieldStatus.loading
                ? TClubColors.redPrincipal.withOpacity(0.5)
                : TClubColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: TClubColors.bgCard,
            border: Border.all(color: borda, width: 1),
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            if (_controller.loadingCidades ||
                status == LocationFieldStatus.loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: TClubColors.redPrincipal,
                  strokeWidth: 1.5,
                ),
              )
            else
              Icon(
                Icons.location_city_outlined,
                color: enabled ? TClubColors.subtle : TClubColors.border,
                size: 18,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CidadeIBGE>(
                  value: _selectedCidade,
                  isExpanded: true,
                  icon: _controller.loadingCidades
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: TClubColors.subtle,
                          size: 20,
                        ),
                  dropdownColor: TClubColors.bgAlt,
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: enabled ? TClubColors.textoPrincipal : TClubColors.subtle,
                  ),
                  hint: Text(
                    _controller.loadingCidades
                        ? 'Carregando cidades...'
                        : _controller.stateOk
                            ? 'Selecione sua cidade'
                            : 'Selecione o estado primeiro',
                    style: const TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 13,
                      color: TClubColors.subtle,
                    ),
                  ),
                  onChanged: enabled
                      ? (cidade) {
                          if (cidade == null) return;
                          setState(() {
                            _selectedCidade = cidade;
                            _bairroCtrl.clear(); // limpa texto do bairro ao trocar cidade
                          });
                          _controller.selectCity(cidade);
                        }
                      : null,
                  items: _controller.cidades
                      .map((c) => DropdownMenuItem<CidadeIBGE>(
                            value: c,
                            child: Text(
                              c.nome,
                              style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 13,
                                color: TClubColors.textoPrincipal,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            if (!_controller.loadingCidades &&
                status != LocationFieldStatus.loading)
              _fieldSuffix(status, false),
          ]),
        ),
        _feedback(
          status,
          _controller.cityError,
          okText: 'Cidade confirmada em ${_controller.state}',
        ),
      ],
    );
  }

  Widget _buildBairroField() {
    final status  = _controller.bairroStatus;
    final focused = _bairroFocus.hasFocus;
    final borda   = status == LocationFieldStatus.ok
        ? TClubColors.redPrincipal
        : status == LocationFieldStatus.error
            ? TClubColors.error
            : status == LocationFieldStatus.loading
                ? TClubColors.redPrincipal.withOpacity(0.5)
                : focused
                    ? TClubColors.redPrincipal
                    : TClubColors.border;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: borda, width: 1),
        ),
        child: Row(children: [
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _bairroCtrl,
              focusNode:  _bairroFocus,
              enabled:    _controller.cityOk,
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _controller.cityOk
                    ? TClubColors.textoPrincipal
                    : TClubColors.subtle,
              ),
              cursorColor: TClubColors.redPrincipal,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: _controller.cityOk
                    ? 'Digite e selecione nas sugestões abaixo'
                    : 'Confirme a cidade primeiro',
                hintStyle: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 13,
                  color: TClubColors.subtle,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: _controller.onBairroChanged,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
            ),
          ),
          _fieldSuffix(status, false),
        ]),
      ),
      _feedback(
        status,
        _controller.bairroError,
        okText: 'Bairro confirmado em ${_controller.city}',
      ),
      // Instrução visível enquanto o bairro ainda não foi selecionado via card
      if (_controller.cityOk &&
          status != LocationFieldStatus.ok &&
          _bairroCtrl.text.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.touch_app_outlined, color: TClubColors.subtle, size: 11),
            const SizedBox(width: 4),
            const Text(
              'Selecione um bairro nas sugestões abaixo',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10,
                letterSpacing: 0.6,
                color: TClubColors.subtle,
              ),
            ),
          ]),
        ),
      _buildBairroSuggestions(),
      if (status == LocationFieldStatus.ok &&
          _controller.lat != null &&
          _controller.lng != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Row(children: [
            const Icon(Icons.my_location, color: TClubColors.subtle, size: 11),
            const SizedBox(width: 4),
            Text(
              '${_controller.lat!.toStringAsFixed(6)}, ${_controller.lng!.toStringAsFixed(6)}',
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10,
                letterSpacing: 0.6,
                color: TClubColors.subtle,
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _buildBairroSuggestions() {
    final suggestions = _controller.bairroSuggestions;
    final loading     = _controller.loadingSuggestions;

    if (suggestions.isEmpty && !loading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                'Buscando bairros...',
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 10,
                  color: TClubColors.subtle,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return GestureDetector(
                onTap: () {
                  _bairroCtrl.text = s.nome;
                  _bairroCtrl.selection = TextSelection.collapsed(
                    offset: s.nome.length,
                  );
                  _controller.selectBairroSuggestion(s);
                  FocusScope.of(context).unfocus();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: TClubColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TClubColors.redPrincipal.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: TClubColors.redPrincipal,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.nome,
                          style: const TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TClubColors.textoPrincipal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────

  Widget _fieldSuffix(LocationFieldStatus status, bool loading) {
    if (loading || status == LocationFieldStatus.loading) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            color: TClubColors.redPrincipal,
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    if (status == LocationFieldStatus.ok) {
      return const Padding(
        padding: EdgeInsets.only(right: 10),
        child: Icon(
          Icons.check_circle_rounded,
          color: TClubColors.redPrincipal,
          size: 18,
        ),
      );
    }
    if (status == LocationFieldStatus.error) {
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Icon(Icons.cancel_rounded, color: TClubColors.error, size: 18),
      );
    }
    return const SizedBox(width: 10);
  }

  Widget _feedback(
    LocationFieldStatus status,
    String? err, {
    required String okText,
  }) {
    if (status == LocationFieldStatus.error && err != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 5, left: 2),
        child: Row(children: [
          Icon(Icons.info_outline, color: TClubColors.error, size: 11),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              err,
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10,
                letterSpacing: 0.8,
                color: TClubColors.error,
              ),
            ),
          ),
        ]),
      );
    }
    if (status == LocationFieldStatus.ok) {
      return Padding(
        padding: const EdgeInsets.only(top: 5, left: 2),
        child: Row(children: [
          const Icon(
            Icons.check_circle_outline,
            color: TClubColors.redPrincipal,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            okText,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10,
              letterSpacing: 0.8,
              color: TClubColors.redPrincipal,
            ),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}

