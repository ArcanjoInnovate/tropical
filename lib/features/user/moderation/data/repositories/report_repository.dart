// lib/features/user/moderation/data/repositories/report_repository.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_models.dart';

class ReportRepository {
  ReportRepository._();
  static final instance = ReportRepository._();

  final _db = FirebaseDatabase.instance;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Paths no RTDB ─────────────────────────────────────────────────────────

  String _collectionPath(ReportTargetType type) {
    switch (type) {
      case ReportTargetType.post:  return 'Reports/posts';
      case ReportTargetType.story: return 'Reports/stories';
      case ReportTargetType.chat:  return 'Reports/chats';
      case ReportTargetType.user:  return 'Reports/users';
    }
  }

  /// Chave única que garante 1 denúncia por par (reporter, alvo):
  /// `{reporterUid}_{targetId}`
  String _reportKey(String targetId) => '${_myUid}_$targetId';

  // ── Verificar duplicidade ─────────────────────────────────────────────────

  Future<bool> jaReportou({
    required ReportTargetType type,
    required String           targetId,
  }) async {
    if (_myUid.isEmpty) return false;
    try {
      final path = '${_collectionPath(type)}/${_reportKey(targetId)}';
      final snap = await _db.ref(path).get();
      return snap.exists;
    } catch (_) {
      // Permissão negada ou nó inexistente — assume não reportado.
      // A rule ".write": "!data.exists()" no servidor garante unicidade.
      return false;
    }
  }

  // ── Submeter denúncia ─────────────────────────────────────────────────────

  Future<void> submit({
    required ReportTargetType type,
    required ReportPayload    payload,
  }) async {
    if (_myUid.isEmpty) throw Exception('Usuário não autenticado.');

    final key = _reportKey(payload.targetId);
    final ref = _db.ref('${_collectionPath(type)}/$key');

    // Previne duplicatas no cliente (a rule ".write": "!data.exists()" já
    // garante no servidor, mas evitar a round-trip é mais rápido).
    // Envolto em try/catch pelo mesmo motivo do jaReportou.
    try {
      if ((await ref.get()).exists) {
        throw Exception('Você já enviou uma denúncia para este conteúdo.');
      }
    } on Exception {
      rethrow; // relança só o "já reportou" — deixa passar erros de permissão
    } catch (_) {
      // Permissão de leitura negada — segue em frente, o servidor rejeita
      // duplicata via rule se necessário.
    }

    final data = <String, dynamic>{
      ...payload.toMap(type),
      'reporter_uid': _myUid,
      'created_at':   ServerValue.timestamp,
    };

    await ref.set(data);
    await _incrementCounters(type, payload);
  }

  // ── Contadores auxiliares ─────────────────────────────────────────────────

  Future<void> _incrementCounters(
    ReportTargetType type,
    ReportPayload    payload,
  ) async {
    try {
      await _db
          .ref('Users/${payload.targetOwnerId}/report_count')
          .set(ServerValue.increment(1));

      switch (type) {
        case ReportTargetType.post:
          await _db
              .ref('Posts/post/${payload.targetId}/report_count')
              .set(ServerValue.increment(1));
          break;
        case ReportTargetType.story:
          await _db
              .ref('Posts/story/${payload.targetId}/report_count')
              .set(ServerValue.increment(1));
          break;
        case ReportTargetType.chat:
          break;
        case ReportTargetType.user:
          break;
      }
    } catch (_) {
      // Best-effort — falha silenciosa não bloqueia a denúncia gravada.
    }
  }
}

