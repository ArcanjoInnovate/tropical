// lib/features/profile/controller/edit_location_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/profile/data/models/location_model.dart';
import 'package:tclub/features/profile/data/repositories/location_repository.dart';
import 'package:tclub/features/profile/data/services/ibge_service.dart';
import 'package:tclub/features/profile/data/services/location_service.dart';


enum SaveStatus { idle, loading, success, error }

class EditLocationController extends ChangeNotifier {
  EditLocationController({
    required LocationService service,
    required IbgeService ibgeService,
    required Map<String, dynamic> userData,
  })  : _service = service,
        _ibgeService = ibgeService {
    _initFromUserData(userData);
  }

  final LocationService _service;
  final IbgeService _ibgeService;

  // ── Estado dos campos ──────────────────────────────────────────────────

  String? _state;
  int?    _stateIbgeId;
  String  _city   = '';
  String  _bairro = '';
  double? _lat;
  double? _lng;

  LocationFieldStatus _cityStatus   = LocationFieldStatus.idle;
  LocationFieldStatus _bairroStatus = LocationFieldStatus.idle;

  String? _cityError;
  String? _bairroError;
  String? _saveError;

  List<CidadeIBGE>       _cidades            = [];
  bool                   _loadingCidades     = false;
  SaveStatus             _saveStatus         = SaveStatus.idle;
  List<BairroSuggestion> _bairroSuggestions  = [];
  bool                   _loadingSuggestions = false;

  // ── Getters públicos ───────────────────────────────────────────────────

  String?                get state              => _state;
  String                 get city               => _city;
  String                 get bairro             => _bairro;
  double?                get lat                => _lat;
  double?                get lng                => _lng;
  LocationFieldStatus    get cityStatus         => _cityStatus;
  LocationFieldStatus    get bairroStatus       => _bairroStatus;
  String?                get cityError          => _cityError;
  String?                get bairroError        => _bairroError;
  String?                get saveError          => _saveError;
  List<CidadeIBGE>       get cidades            => _cidades;
  bool                   get loadingCidades     => _loadingCidades;
  SaveStatus             get saveStatus         => _saveStatus;
  List<BairroSuggestion> get bairroSuggestions  => _bairroSuggestions;
  bool                   get loadingSuggestions => _loadingSuggestions;

  bool get stateOk  => (_state ?? '').isNotEmpty;
  bool get cityOk   => _city.isNotEmpty && _lat != null && _cityStatus == LocationFieldStatus.ok;
  bool get bairroOk => _bairroStatus == LocationFieldStatus.ok;
  bool get allValid => stateOk && cityOk && bairroOk;
  bool get isSaving => _saveStatus == SaveStatus.loading;

  // ── Init ───────────────────────────────────────────────────────────────

  void _initFromUserData(Map<String, dynamic> data) {
    _state  = data['state']  as String? ?? '';
    _city   = data['city']   as String? ?? '';
    _bairro = data['bairro'] as String? ?? '';
    _lat    = (data['latitude']  as num?)?.toDouble();
    _lng    = (data['longitude'] as num?)?.toDouble();

    if (_state!.isEmpty) _state = null;
    if (_city.isNotEmpty && _state != null && _lat != null) _cityStatus   = LocationFieldStatus.ok;
    if (_bairro.isNotEmpty && cityOk)                       _bairroStatus = LocationFieldStatus.ok;

    if (_state != null) _loadCidadesForState(_state!);
  }

  // ── Estado ─────────────────────────────────────────────────────────────

  Future<void> selectState(String stateCode) async {
    _state        = stateCode;
    _city         = '';
    _bairro       = '';
    _lat          = null;
    _lng          = null;
    _cityStatus   = LocationFieldStatus.idle;
    _cityError    = null;
    _bairroStatus = LocationFieldStatus.idle;
    _bairroError  = null;
    _cidades      = [];
    _bairroSuggestions = [];
    notifyListeners();

    await _loadCidadesForState(stateCode);
  }

  Future<void> _loadCidadesForState(String stateCode) async {
    _loadingCidades = true;
    notifyListeners();
    try {
      final estados = await _ibgeService.buscarEstados();
      final estado  = estados.firstWhere(
        (e) => e.sigla.toUpperCase() == stateCode.toUpperCase(),
        orElse: () => throw Exception('Estado não encontrado: $stateCode'),
      );
      _stateIbgeId = estado.id;
      _cidades = await _ibgeService.buscarCidades(estado.id);
    } catch (_) {
      _cidades = [];
    } finally {
      _loadingCidades = false;
      notifyListeners();
    }
  }

  // ── Cidade ─────────────────────────────────────────────────────────────

  Future<void> selectCity(CidadeIBGE cidade) async {
    _city         = cidade.nome;
    _lat          = null;
    _lng          = null;
    _bairro       = '';
    _cityStatus   = LocationFieldStatus.loading;
    _cityError    = null;
    _bairroStatus = LocationFieldStatus.idle;
    _bairroError  = null;
    _bairroSuggestions = [];
    _suggestionDebounce?.cancel();
    notifyListeners();

    try {
      final coords = await _service.geocodeCity(
        city:      cidade.nome,
        stateCode: _state!,
      );
      _lat        = coords.lat;
      _lng        = coords.lng;
      _cityStatus = LocationFieldStatus.ok;
    } on LocationServiceException catch (e) {
      _cityStatus = LocationFieldStatus.error;
      _cityError  = e.message;
    } catch (_) {
      _cityStatus = LocationFieldStatus.error;
      _cityError  = 'Não foi possível obter coordenadas da cidade';
    }
    notifyListeners();
  }

  void confirmCityFromSeed(CidadeIBGE cidade) {
    if (_cityStatus == LocationFieldStatus.ok && _city == cidade.nome) {
      notifyListeners();
    }
  }

  // ── Endereço / Bairro ──────────────────────────────────────────────────

  Timer? _suggestionDebounce;

  void onBairroChanged(String value) {
    _bairro       = value;
    _bairroStatus = LocationFieldStatus.idle;
    _bairroError  = null;
    _bairroSuggestions = [];
    notifyListeners();

    _suggestionDebounce?.cancel();

    if (value.trim().isEmpty || !cityOk) {
      notifyListeners();
      return;
    }

    // Debounce de 400 ms — menos delay deixa o autocomplete mais responsivo
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _fetchSuggestions(value.trim()),
    );
  }

  // Ao perder foco não valida — usuário deve clicar no card
  void onBairroUnfocused() {}

  Future<void> _fetchSuggestions(String query) async {
    if (!cityOk || query.isEmpty) return;
    _loadingSuggestions = true;
    notifyListeners();
    try {
      _bairroSuggestions = await _service.searchBairros(
        query:     query,
        city:      _city,
        stateCode: _state!,
        cityLat:   _lat!,
        cityLng:   _lng!,
      );
    } catch (_) {
      _bairroSuggestions = [];
    }
    _loadingSuggestions = false;
    notifyListeners();
  }

  /// Clique numa sugestão:
  ///   1. Seta o nome imediatamente (UI responsiva)
  ///   2. Chama Places Details para obter lat/lng exatos do place_id
  ///   3. Confirma o status como ok após resolver coords
  Future<void> selectBairroSuggestion(BairroSuggestion suggestion) async {
    _bairro            = suggestion.nome;
    _bairroSuggestions = [];
    _bairroError       = null;
    _suggestionDebounce?.cancel();

    final placeId = suggestion.placeId;

    // Se não tem placeId (seed de edição), confirma direto com coords do seed
    if (placeId == null || placeId.isEmpty) {
      _lat          = suggestion.lat;
      _lng          = suggestion.lng;
      _bairroStatus = LocationFieldStatus.ok;
      notifyListeners();
      return;
    }

    // Tem placeId — resolve coords precisas via Places Details
    _bairroStatus = LocationFieldStatus.loading;
    notifyListeners();

    try {
      final coords = await _service.resolvePlaceCoords(placeId);
      _lat          = coords.lat;
      _lng          = coords.lng;
      _bairroStatus = LocationFieldStatus.ok;
    } catch (_) {
      // Fallback: usa coords do centro da cidade (melhor do que nada)
      _lat          = suggestion.lat;
      _lng          = suggestion.lng;
      _bairroStatus = LocationFieldStatus.ok;
    }
    notifyListeners();
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> save(String uid) async {
    if (!allValid) return;
    _saveStatus = SaveStatus.loading;
    _saveError  = null;
    notifyListeners();
    try {
      await _service.saveLocation(
        uid: uid,
        data: LocationModel(
          state:     _state!,
          city:      _city,
          bairro:    _bairro.trim(),
          latitude:  _lat!,
          longitude: _lng!,
        ),
      );
      _saveStatus = SaveStatus.success;
    } on LocationServiceException catch (e) {
      _saveStatus = SaveStatus.error;
      _saveError  = e.message;
    } catch (_) {
      _saveStatus = SaveStatus.error;
      _saveError  = 'Erro inesperado. Tente novamente.';
    }
    notifyListeners();
  }

  void resetSaveStatus() {
    _saveStatus = SaveStatus.idle;
    _saveError  = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    super.dispose();
  }
}

