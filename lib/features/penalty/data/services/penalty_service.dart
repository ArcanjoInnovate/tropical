// lib/features/penalty/domain/services/penalty_service.dart

import 'package:tabuapp/features/penalty/data/repositories/penalty_repository.dart';
import 'package:tabuapp/core/services/presence_service.dart';

class PenaltyService {
  final PenaltyRepository _repository;

  PenaltyService({PenaltyRepository? repository})
      : _repository = repository ?? PenaltyRepository();

  // ── Confirmar leitura de advertência / remoção de conteúdo ────────────────
  Future<void> confirmarLeitura({
    required String uid,
    required String penalidadeKey,
  }) async {
    await _repository.marcarComoVista(
      uid:           uid,
      penalidadeKey: penalidadeKey,
    );
  }

  // ── Verificar suspensão ao logar ───────────────────────────────────────────
  /// Verifica se a suspensão expirou e, se sim, limpa o banco.
  /// Retorna [true] se o usuário pode prosseguir (suspensão levantada ou
  /// nunca existiu), [false] se ainda está ativa.
  Future<bool> verificarELiberarSuspensao(String uid) async {
    return _repository.verificarELiberarSuspensaoSeExpirada(uid);
  }

  // ── Logout completo ────────────────────────────────────────────────────────
  Future<void> fazerLogout(String uid) async {
    await _repository.removerFcmToken(uid);
    await PresenceService.instance.setOffline();
    await _repository.signOut();
  }
}