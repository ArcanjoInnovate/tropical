// lib/features/match/controllers/match_controller.dart

import 'package:flutter/foundation.dart';
import '../data/models/match_profile_model.dart';
import '../data/models/match_filter_model.dart';
import '../data/services/match_service.dart';

enum MatchLoadState { idle, loading, loaded, error }

class MatchController extends ChangeNotifier {
  MatchController({required MatchService service}) : _service = service;

  final MatchService _service;

  // ── Estado ────────────────────────────────────────────────────────────────
  List<MatchProfileModel> _profiles  = [];
  int                     _index     = 0;
  MatchLoadState          _loadState = MatchLoadState.idle;
  String?                 _error;
  MatchFilterModel        _filter    = const MatchFilterModel();
  String                  _myUid    = '';

  // Indica que um dislike está sendo gravado no Firebase
  bool _isSavingDislike = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<MatchProfileModel> get profiles       => _profiles;
  int                     get index          => _index;
  MatchLoadState          get loadState      => _loadState;
  String?                 get error          => _error;
  MatchFilterModel        get filter         => _filter;
  bool                    get isSavingDislike => _isSavingDislike;

  bool get isLoading => _loadState == MatchLoadState.loading;
  bool get hasMore   => _index < _profiles.length;
  bool get isEmpty   => _loadState == MatchLoadState.loaded && _profiles.isEmpty;

  MatchProfileModel? get current => hasMore ? _profiles[_index] : null;

  /// True quando o card atual é o próprio usuário logado.
  bool get isCurrentMyProfile =>
      current != null && current!.uid == _myUid;

  // ── Carregamento ──────────────────────────────────────────────────────────

  Future<void> load({
    required String myUid,
    required double myLat,
    required double myLng,
    MatchFilterModel? filter,
  }) async {
    _myUid = myUid;
    // NÃO sobrescreve _filter aqui — o filtro real do usuário é mantido
    // via applyFilter(), chamado pela página antes de chamar load().
    // O parâmetro filter (safeFilter) é usado apenas para a consulta.
    final queryFilter = filter ?? _filter;

    _loadState = MatchLoadState.loading;
    _error     = null;
    _index     = 0;
    _profiles  = [];
    notifyListeners();

    try {
      _profiles = await _service.loadProfiles(
        myUid:  myUid,
        filter: queryFilter,
        myLat:  myLat,
        myLng:  myLng,
      );
      _loadState = MatchLoadState.loaded;
    } catch (e) {
      _loadState = MatchLoadState.error;
      _error     = e.toString();
    }

    notifyListeners();
  }

  // ── Ações de swipe ────────────────────────────────────────────────────────

  /// Avança para o próximo perfil (like ou qualquer ação diferente de dislike).
  /// Não faz nada se o card atual for o próprio usuário.
  void advance() {
    if (!hasMore) return;
    if (isCurrentMyProfile) return;
    _index++;
    notifyListeners();
  }

  /// Grava o like no Firebase e avança para o próximo perfil.
  ///
  /// Fluxo:
  ///   1. Avança imediatamente na UI.
  ///   2. Grava no Firebase em background (Matchs/{targetUid}/like_me/{myUid}: true).
  ///   3. Qualquer erro de rede é silenciado.
  Future<void> like() async {
    if (!hasMore || isCurrentMyProfile) return;

    final targetUid = current!.uid;

    _index++;
    notifyListeners();

    try {
      await _service.recordLike(
        myUid:     _myUid,
        targetUid: targetUid,
      );
    } catch (e) {
      debugPrint('[MatchController] ⚠️ Falha ao gravar like: $e');
    }
  }

  /// Grava o dislike no Firebase e avança para o próximo perfil.
  ///
  /// Fluxo:
  ///   1. Avança imediatamente na UI (sem travar a animação).
  ///   2. Grava no Firebase em background (Users/{myUid}/dislikes/{targetUid}
  ///      e Users/{targetUid}/dislikes_received/{myUid}).
  ///   3. Qualquer erro de rede é silenciado — o usuário não é bloqueado.
  Future<void> dislike() async {
    if (!hasMore || isCurrentMyProfile) return;

    final targetUid = current!.uid;

    // Avança na UI imediatamente
    _index++;
    notifyListeners();

    // Grava no Firebase em background
    _isSavingDislike = true;
    notifyListeners();

    try {
      await _service.recordDislike(
        myUid:     _myUid,
        targetUid: targetUid,
      );
    } catch (e) {
      // Erro silenciado: a UI já avançou, o dislike será gravado na
      // próxima oportunidade ou simplesmente ignorado.
      debugPrint('[MatchController] ⚠️ Falha ao gravar dislike: $e');
    } finally {
      _isSavingDislike = false;
      notifyListeners();
    }
  }

  /// Pula o card atual sem registrar like/dislike (usado quando
  /// isCurrentMyProfile == true).
  void skip() {
    if (!hasMore) return;
    _index++;
    notifyListeners();
  }

  // ── Filtro ────────────────────────────────────────────────────────────────

  void applyFilter(MatchFilterModel newFilter) {
    _filter = newFilter;
    notifyListeners();
  }
}