// lib/features/penalty/data/repositories/penalty_repository.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PenaltyRepository {
  final FirebaseDatabase _db;
  final FirebaseAuth     _auth;

  PenaltyRepository({
    FirebaseDatabase? db,
    FirebaseAuth?     auth,
  })  : _db   = db   ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── Marcar penalidade como vista ───────────────────────────────────────────
  Future<void> marcarComoVista({
    required String uid,
    required String penalidadeKey,
  }) async {
    try {
      await _db
          .ref('Users/$uid/penalidades/$penalidadeKey/vista')
          .set(true);
    } catch (e) {
      debugPrint('[PenaltyRepository] marcarComoVista ignorado: $e');
    }
  }

  // ── Verificar e liberar suspensão expirada ─────────────────────────────────
  /// Chamado no login quando o usuário está suspenso.
  /// Se [suspensao_fim] já passou, limpa os campos de suspensão no banco
  /// e retorna [true] (suspensão levantada — pode prosseguir).
  /// Se ainda está ativa, retorna [false].
  Future<bool> verificarELiberarSuspensaoSeExpirada(String uid) async {
    try {
      final snap = await _db.ref('Users/$uid').get();
      if (!snap.exists || snap.value == null) return false;

      final raw      = Map<String, dynamic>.from(snap.value as Map);
      final suspenso = raw['suspenso'];
      final suspFim  = raw['suspensao_fim'];

      final isSuspenso = suspenso == true || suspenso == 1;
      if (!isSuspenso) return true; // nunca esteve suspenso

      final fimMs = suspFim is int
          ? suspFim
          : suspFim is double
              ? suspFim.toInt()
              : int.tryParse(suspFim?.toString() ?? '') ?? 0;

      final expirou = fimMs > 0 &&
          DateTime.fromMillisecondsSinceEpoch(fimMs)
              .isBefore(DateTime.now());

      if (!expirou) return false; // ainda ativa

      // Suspensão expirada — limpa no banco
      debugPrint('[PenaltyRepository] Suspensão expirada para uid=$uid — liberando');
      await _db.ref('Users/$uid').update({
        'suspenso':       false,
        'suspensao_fim':  null,
        'penalidade_ativa': null,
      });
      return true;
    } catch (e) {
      debugPrint('[PenaltyRepository] verificarSuspensao erro: $e');
      return false;
    }
  }

  // ── Limpar FCM token ────────────────────────────────────────────────────────
  Future<void> removerFcmToken(String uid) async {
    try {
      await _db.ref('Users/$uid/fcmToken').remove();
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[PenaltyRepository] removerFcmToken ignorado: $e');
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }
}