// lib/core/services/user_relationship_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserRelationshipService {
  final _db = FirebaseDatabase.instance.ref();

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  Future<String?> _ensureValidAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return null;
      return user.uid;
    } catch (e) {
      print('❌ _ensureValidAuth erro: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VERIFICAÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> isUserBlocked(String myUserId, String targetUserId) async {
    try {
      final snap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();
      return snap.exists && _isTruthy(snap.value);
    } catch (e) {
      print('❌ isUserBlocked erro: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOQUEAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      print('\n═══════════════════════════════════════════════');
      print('🔄 INICIANDO BLOQUEIO');
      print('   De: $myUserId → Para: $targetUserId');
      print('═══════════════════════════════════════════════');

      final authUserId = await _ensureValidAuth();
      if (authUserId == null) {
        print('❌ FALHA: Auth inválido');
        return false;
      }
      if (authUserId != myUserId) {
        print('❌ FALHA: UID não confere');
        return false;
      }

      final ref = _db.child('Users/$myUserId/blocked_users/$targetUserId');

      // Verifica se já está bloqueado antes de escrever
      final alreadySnap = await ref.get();
      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        print('⚠️ Já bloqueado — abortando');
        return false;
      }

      print('📝 Executando set()...');
      try {
        await ref.set(true).timeout(const Duration(seconds: 10));
        print('✅ set() concluído');
      } on TimeoutException {
        print('⏱️ Timeout no set()');
        return false;
      } catch (e) {
        print('❌ Erro no set(): $e');
        return false;
      }

      // Confirmação via get() direto (evita problema de supressão de evento
      // pelo cache do iOS que impedia o onValue de disparar).
      print('⏳ Confirmando escrita via get()...');
      final confirmSnap = await ref.get().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏱️ Timeout na confirmação');
          throw TimeoutException('Confirmação expirou');
        },
      );

      if (!confirmSnap.exists || !_isTruthy(confirmSnap.value)) {
        print('❌ FALHA: Escrita não confirmada pelo servidor');
        return false;
      }

      print('✅ Servidor confirmou a escrita em Users/');

      // ── Escritas secundárias em background (não críticas para o resultado)

      // Índice inverso no nó Users
      unawaited(
        _db
            .child('blocked_by/$targetUserId/$myUserId')
            .set(true)
            .catchError((e) => print('⚠️ blocked_by (Users) falhou: $e')),
      );

      // Espelha o bloqueio no nó Matchs para que o sistema de match
      // filtre o perfil bloqueado sem viagem extra ao banco.
      //   Matchs/{myUserId}/blocked_users/{targetUserId} = true
      //   Matchs/{targetUserId}/blocked_by/{myUserId}    = true  ← índice inverso
      unawaited(
        _db.ref.update({
          'Matchs/$myUserId/blocked_users/$targetUserId': true,
          'Matchs/$targetUserId/blocked_by/$myUserId': true,
        }).catchError((e) => print('⚠️ blocked_users (Matchs) falhou: $e')),
      );

      print('✅ BLOQUEIO CONCLUÍDO COM SUCESSO');
      print('═══════════════════════════════════════════════\n');
      return true;
    } catch (e, st) {
      print('❌ EXCEÇÃO em blockUser: $e\n$st');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESBLOQUEAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      final authUserId = await _ensureValidAuth();
      if (authUserId == null || authUserId != myUserId) return false;

      // Remove do nó Users
      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .remove();

      // Remove índice inverso de Users e espelhos em Matchs (background)
      unawaited(
        Future.wait([
          _db.child('blocked_by/$targetUserId/$myUserId').remove(),
          _db.child('Matchs/$myUserId/blocked_users/$targetUserId').remove(),
          _db.child('Matchs/$targetUserId/blocked_by/$myUserId').remove(),
        ]).catchError((_) {}),
      );

      print('✅ Desbloqueado: $targetUserId');
      return true;
    } catch (e) {
      print('❌ unblockUser erro: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FETCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<Set<String>> fetchAllBlockedUsers(String myUserId) async {
    try {
      final results = await Future.wait([
        fetchUsersIBlocked(myUserId),
        fetchUsersWhoBlockedMe(myUserId),
      ]);
      return {...results[0], ...results[1]};
    } catch (e) {
      print('❌ fetchAllBlockedUsers: $e');
      return {};
    }
  }

  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final snap = await _db.child('Users/$myUserId/blocked_users').get();
      if (!snap.exists || snap.value == null) return {};
      final value = snap.value;
      if (value is! Map) return {};
      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      print('❌ fetchUsersIBlocked: $e');
      return {};
    }
  }

  Future<Set<String>> fetchUsersWhoBlockedMe(String myUserId) async {
    try {
      final snap = await _db.child('blocked_by/$myUserId').get();
      if (!snap.exists || snap.value == null) return {};
      final value = snap.value;
      if (value is! Map) return {};
      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      print('❌ fetchUsersWhoBlockedMe: $e');
      return {};
    }
  }

  Future<({bool iBlockedThem, bool theyBlockedMe})> checkRelationship(
    String myUserId,
    String otherUserId,
  ) async {
    try {
      final results = await Future.wait([
        _db.child('Users/$myUserId/blocked_users/$otherUserId').get(),
        _db.child('blocked_by/$myUserId/$otherUserId').get(),
      ]);
      return (
        iBlockedThem: results[0].exists && _isTruthy(results[0].value),
        theyBlockedMe: results[1].exists && _isTruthy(results[1].value),
      );
    } catch (e) {
      print('❌ checkRelationship: $e');
      return (iBlockedThem: false, theyBlockedMe: false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMS — para widgets reativos
  // ══════════════════════════════════════════════════════════════════════════

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}

